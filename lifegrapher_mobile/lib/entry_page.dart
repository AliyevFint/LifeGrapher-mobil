import 'dart:async';

import 'app_language.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum EntryKind { meal, sleep, water, goals }

/// The caller owns persistence; the form stays open until saving succeeds.
class EntryPage extends StatefulWidget {
  const EntryPage({
    super.key,
    required this.kind,
    required this.onSave,
    this.profile,
    this.initialData,
  });
  final EntryKind kind;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? initialData;

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  bool _saving = false;
  bool _slowSave = false;
  Timer? _saveNotice;
  String? _error;
  String _mealType = 'breakfast';
  int _quality = 3;
  late DateTime _wakeTime;
  late DateTime _bedtime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _wakeTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _bedtime = _wakeTime.subtract(Duration(hours: 8));
    for (final name in [
      'name',
      'calories',
      'protein',
      'carbs',
      'fat',
      'calorieGoal',
      'sleepHours',
      'waterMl',
    ]) {
      _fields[name] = TextEditingController(
        text: switch (name) {
          'protein' => '${widget.initialData?['protein'] ?? 0}',
          'carbs' => '${widget.initialData?['carbs'] ?? 0}',
          'fat' => '${widget.initialData?['fat'] ?? 0}',
          'calorieGoal' => '${widget.profile?['calorieGoal'] ?? 2000}',
          'sleepHours' =>
            '${((widget.profile?['sleepGoalMinutes'] as num?) ?? 480) / 60}',
          'waterMl' => '${widget.initialData?['milliliters'] ?? 250}',
          'name' => '${widget.initialData?['name'] ?? ''}',
          'calories' => '${widget.initialData?['calories'] ?? ''}',
          _ => '',
        },
      );
    }
    _mealType = widget.initialData?['mealType'] as String? ?? _mealType;
    final bed = widget.initialData?['bedtime'];
    final wake = widget.initialData?['wakeTime'];
    if (bed is Timestamp) _bedtime = bed.toDate();
    if (wake is Timestamp) _wakeTime = wake.toDate();
    _quality = (widget.initialData?['quality'] as num?)?.toInt() ?? _quality;
  }

  @override
  void dispose() {
    _saveNotice?.cancel();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String key) =>
      double.tryParse(_fields[key]!.text.trim().replaceAll(',', '.'));

  Widget _numberField(
    String key,
    String label, {
    bool positive = false,
    double? maximum,
  }) => Padding(
    padding: EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _fields[key],
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      validator: (_) {
        final value = _number(key);
        if (value == null ||
            !value.isFinite ||
            value < 0 ||
            (positive && value == 0)) {
          return positive
              ? tr(context, "Sıfırdan böyük düzgün rəqəm yazın.")
              : tr(context, "Sıfır və ya müsbət rəqəm yazın.");
        }
        if (maximum != null && value > maximum) {
          return amount(context, 'maximum', maximum);
        }
        return null;
      },
    ),
  );

  Future<void> _pickTime(bool bed) async {
    final current = bed ? _bedtime : _wakeTime;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (bed) {
        _bedtime = value;
      } else {
        _wakeTime = value;
      }
      _error = null;
    });
  }

  String _dateText(DateTime date) =>
      '${MaterialLocalizations.of(context).formatMediumDate(date)} • ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final minutes = _wakeTime.difference(_bedtime).inMinutes;
    if (widget.kind == EntryKind.sleep &&
        (minutes <= 0 || minutes > 1440 || _wakeTime.isAfter(DateTime.now()))) {
      setState(
        () => _error = tr(
          context,
          "Oyanış yatışdan sonra olmalıdır. Müddət 24 saatı, oyanış indiki vaxtı keçməməlidir.",
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _slowSave = false;
      _error = null;
    });
    final data = switch (widget.kind) {
      EntryKind.meal => <String, dynamic>{
        'name': _fields['name']!.text.trim(),
        'mealType': _mealType,
        for (final key in ['calories', 'protein', 'carbs', 'fat'])
          key: _number(key)!,
        'loggedAt': widget.initialData?['loggedAt'] ?? DateTime.now(),
      },
      EntryKind.sleep => <String, dynamic>{
        'bedtime': _bedtime,
        'wakeTime': _wakeTime,
        'durationMinutes': minutes,
        'quality': _quality,
      },
      EntryKind.water => <String, dynamic>{
        'milliliters': _number('waterMl')!,
        'loggedAt': widget.initialData?['loggedAt'] ?? DateTime.now(),
      },
      EntryKind.goals => <String, dynamic>{
        'calorieGoal': _number('calorieGoal')!,
        'sleepGoalMinutes': (_number('sleepHours')! * 60).round(),
      },
    };
    _saveNotice = Timer(Duration(seconds: 20), () {
      if (mounted && _saving) {
        setState(() => _slowSave = true);
      }
    });
    try {
      // Keep observing the disk write until it succeeds or fails.
      await widget.onSave(data);
      if (!mounted) return;
      // Re-enable popping before completing the route.
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _slowSave = false;
        _error = tr(
          context,
          "Telefonda saxlanmadı. Boş yaddaşı yoxlayıb yenidən cəhd edin. Yazdıqlarınız formadadır.",
        );
      });
    } finally {
      _saveNotice?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      EntryKind.meal => tr(context, "Yemək əlavə et"),
      EntryKind.sleep => tr(context, "Yuxu əlavə et"),
      EntryKind.water => tr(context, 'Su əlavə et'),
      EntryKind.goals => tr(context, "Gündəlik hədəflər"),
    };
    return PopScope(
      canPop: !_saving || _slowSave,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: AbsorbPointer(
                    absorbing: _saving,
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.kind == EntryKind.meal) ...[
                            TextFormField(
                              controller: _fields['name'],
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: tr(context, "Yeməyin adı"),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? tr(context, "Yeməyin adını yazın.")
                                  : null,
                            ),
                            SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _mealType,
                              decoration: InputDecoration(
                                labelText: tr(context, "Növ"),
                              ),
                              items: ['breakfast', 'lunch', 'dinner', 'snack']
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(mealTypeText(context, v)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _mealType = value!),
                            ),
                            SizedBox(height: 16),
                            _numberField(
                              'calories',
                              tr(context, "Kalori (kcal)"),
                            ),
                            _numberField('protein', tr(context, "Protein (g)")),
                            _numberField(
                              'carbs',
                              tr(context, "Karbohidrat (g)"),
                            ),
                            _numberField('fat', tr(context, "Yağ (g)")),
                          ],
                          if (widget.kind == EntryKind.sleep) ...[
                            ListTile(
                              title: Text(tr(context, "Yatış saatı")),
                              subtitle: Text(_dateText(_bedtime)),
                              trailing: Icon(Icons.edit),
                              onTap: () => _pickTime(true),
                            ),
                            ListTile(
                              title: Text(tr(context, "Oyanış saatı")),
                              subtitle: Text(_dateText(_wakeTime)),
                              trailing: Icon(Icons.edit),
                              onTap: () => _pickTime(false),
                            ),
                            SizedBox(height: 16),
                            Text(
                              amount(
                                context,
                                'durationValue',
                                _wakeTime.difference(_bedtime).inMinutes / 60,
                                1,
                              ),
                            ),
                            SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              initialValue: _quality,
                              decoration: InputDecoration(
                                labelText: tr(context, "Yuxu keyfiyyəti"),
                              ),
                              items: List.generate(
                                5,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text('${i + 1} / 5'),
                                ),
                              ),
                              onChanged: (value) =>
                                  setState(() => _quality = value!),
                            ),
                          ],
                          if (widget.kind == EntryKind.water) ...[
                            Text(
                              tr(
                                context,
                                'Gündə içdiyiniz su miqdarını yazın.',
                              ),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            SizedBox(height: 16),
                            _numberField(
                              'waterMl',
                              tr(context, 'Su miqdarı (ml)'),
                              positive: true,
                              maximum: 10000,
                            ),
                          ],
                          if (widget.kind == EntryKind.goals) ...[
                            _numberField(
                              'calorieGoal',
                              tr(context, "Kalori hədəfi (kcal)"),
                              positive: true,
                            ),
                            _numberField(
                              'sleepHours',
                              tr(context, "Yuxu hədəfi (saat)"),
                              positive: true,
                              maximum: 24,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_slowSave)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    tr(
                      context,
                      "Telefon yaddaşına yazılır. Təkrar əlavə etməyin. İstəsəniz geri qayıda bilərsiniz.",
                    ),
                    style: TextStyle(color: Color(0xFF526477)),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.check),
                    label: Text(
                      _saving
                          ? tr(context, "Saxlanılır…")
                          : widget.kind == EntryKind.goals
                          ? tr(context, "Yadda saxla")
                          : widget.initialData == null
                          ? tr(context, "Əlavə et")
                          : tr(context, 'Dəyişiklikləri saxla'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
