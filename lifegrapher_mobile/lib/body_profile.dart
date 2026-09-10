import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'local_store.dart';

const _regions = ['Sinə', 'Qarın', 'Bel', 'Qollar', 'Ayaqlar'];

/// Illustrative proportions chosen by the user, never a body-fat estimate.
class BodyFigure extends StatelessWidget {
  const BodyFigure({
    super.key,
    required this.weight,
    required this.height,
    required this.shape,
  });
  final double weight, height;
  final List<double> shape;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Təxmini bədən görünüşü, $weight kq',
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: weight),
      duration: const Duration(milliseconds: 450),
      builder: (_, value, _) => SizedBox(
        height: 260,
        width: 150,
        child: CustomPaint(painter: _BodyPainter(value, height, shape)),
      ),
    ),
  );
}

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.weight, this.height, this.shape);
  final double weight, height;
  final List<double> shape;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, 8);
    final scale = (height / 175).clamp(.75, 1.08);
    canvas.scale(scale, scale);
    final bulk = (weight / 80).clamp(.55, 1.8);
    double width(int i, double base) => base * bulk * (.75 + shape[i] * .5);
    final chest = width(0, 26), belly = width(1, 27), waist = width(2, 22);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF77B9CA), Color(0xFF327C99)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(-60, 0, 120, 230));
    canvas.drawOval(const Rect.fromLTWH(-15, 0, 30, 35), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, 28, 14, 18),
        const Radius.circular(5),
      ),
      paint,
    );
    final torso = Path()
      ..moveTo(-20, 40)
      ..quadraticBezierTo(-chest - 7, 48, -chest, 73)
      ..quadraticBezierTo(-belly, 96, -waist, 116)
      ..quadraticBezierTo(-waist - 7, 137, -20 * bulk, 146)
      ..lineTo(20 * bulk, 146)
      ..quadraticBezierTo(waist + 7, 137, waist, 116)
      ..quadraticBezierTo(belly, 96, chest, 73)
      ..quadraticBezierTo(chest + 7, 48, 20, 40)
      ..close();
    canvas.drawPath(torso, paint);
    final limb = Paint()
      ..color = const Color(0xFF438DA5)
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      limb.strokeWidth = width(3, 12);
      canvas.drawLine(
        Offset(side * (chest + 3), 52),
        Offset(side * (chest + 17), 123),
        limb,
      );
      limb.strokeWidth = width(4, 21);
      canvas.drawLine(
        Offset(side * 13 * bulk, 141),
        Offset(side * 16 * bulk, 212),
        limb,
      );
      limb.strokeWidth = width(4, 12);
      canvas.drawLine(
        Offset(side * 16 * bulk, 215),
        Offset(side * (16 * bulk + 6), 222),
        limb,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) => true;
}

List<double> _shape(Map<String, dynamic> data) =>
    (data['shape'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
    List.filled(5, .5);

class BodyProfileGate extends StatefulWidget {
  const BodyProfileGate({super.key, required this.uid, required this.child});
  final String uid;
  final Widget child;
  @override
  State<BodyProfileGate> createState() => _BodyProfileGateState();
}

class _BodyProfileGateState extends State<BodyProfileGate> {
  late Stream<LocalProfileSnapshot> _stream;
  bool _skipped = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _stream = LocalStore.instance.profile(widget.uid);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<LocalProfileSnapshot>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => setState(_reload),
              child: const Text('Profil oxunmadı. Yenidən cəhd et'),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final profile = snapshot.data!.data();
      if (_skipped || profile['bodySetup'] == true) return widget.child;
      return BodySetupPage(
        uid: widget.uid,
        profile: profile,
        onSkip: () => setState(() => _skipped = true),
      );
    },
  );
}

class BodySetupPage extends StatefulWidget {
  const BodySetupPage({
    super.key,
    required this.uid,
    required this.profile,
    this.onSkip,
  });
  final String uid;
  final Map<String, dynamic> profile;
  final VoidCallback? onSkip;
  @override
  State<BodySetupPage> createState() => _BodySetupPageState();
}

class _BodySetupPageState extends State<BodySetupPage> {
  final _form = GlobalKey<FormState>();
  late final List<TextEditingController> _fields;
  late List<double> _proportions;
  late String _goal, _activity, _frequency;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _fields = [
      'name',
      'age',
      'height',
      'weight',
      'targetWeight',
    ].map((key) => TextEditingController(text: '${p[key] ?? ''}')).toList();
    _proportions = _shape(p);
    _goal = p['goal'] as String? ?? 'Çəkini qorumaq';
    _activity = p['activity'] as String? ?? 'Orta';
    _frequency = p['frequency'] as String? ?? 'Həftəlik';
  }

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  double? _number(int i) =>
      double.tryParse(_fields[i].text.replaceAll(',', '.'));
  Widget _choice(
    String label,
    String value,
    List<String> choices,
    ValueChanged<String> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: choices
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (s) => setState(() => change(s!)),
    ),
  );
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = LocalStore.instance;
      await store.update(widget.uid, (state) {
        final profile = state['profile'] as Map;
        final first = profile['bodySetup'] != true;
        profile.addAll(<String, dynamic>{
          'bodySetup': true,
          'name': _fields[0].text.trim(),
          'age': _number(1)!.toInt(),
          'height': _number(2),
          'weight': first ? _number(3) : profile['weight'],
          'targetWeight': _number(4),
          'goal': _goal,
          'activity': _activity,
          'frequency': _frequency,
          'shape': List.of(_proportions),
        });
        if (first) {
          state['weights'] = {
            store.newId(): {
              'weight': _number(3),
              'height': _number(2),
              'shape': List.of(_proportions),
              'loggedAt': DateTime.now(),
              'baseline': true,
            },
          };
        }
      });
      if (mounted && widget.onSkip == null) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Saxlanmadı. Yaddaşı yoxlayıb yenidən cəhd edin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.onSkip == null ? 'Bədən profilim' : 'Xoş gəlmisiniz!'),
    ),
    body: Form(
      key: _form,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Özünüz haqqında məlumat verin',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            Center(
              child: BodyFigure(
                weight: (_number(3) ?? 80).clamp(20, 400),
                height: (_number(2) ?? 175).clamp(80, 250),
                shape: _proportions,
              ),
            ),
            const Text(
              'Təxmini vizualdır. Yağ faizini və dərinin sallanmasını hesablamır.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < _fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  key: ValueKey('body-field-$i'),
                  controller: _fields[i],
                  enabled:
                      !_busy &&
                      !(i == 3 && widget.profile['bodySetup'] == true),
                  decoration: InputDecoration(
                    labelText: [
                      'Ad və ya ləqəb',
                      'Yaş',
                      'Boy (sm)',
                      'Hazırkı çəki (kq)',
                      'Hədəf çəki (kq)',
                    ][i],
                  ),
                  keyboardType: i == 0
                      ? TextInputType.name
                      : const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (i == 0) {
                      return value == null || value.trim().isEmpty
                          ? 'Adınızı yazın.'
                          : null;
                    }
                    final n = _number(i);
                    final min = i == 1
                        ? 1
                        : i == 2
                        ? 80
                        : 20;
                    final max = i == 1
                        ? 120
                        : i == 2
                        ? 250
                        : 400;
                    return n == null ||
                            !n.isFinite ||
                            n < min ||
                            n > max ||
                            (i == 1 && n != n.roundToDouble())
                        ? '$min–$max arasında düzgün rəqəm yazın.'
                        : null;
                  },
                ),
              ),
            _choice('Məqsəd', _goal, [
              'Arıqlamaq',
              'Çəkini qorumaq',
              'Çəki artırmaq',
            ], (v) => _goal = v),
            _choice('Aktivlik səviyyəsi', _activity, [
              'Az hərəkətli',
              'Orta',
              'Çox hərəkətli',
            ], (v) => _activity = v),
            _choice('Çəki qeydinin tezliyi', _frequency, [
              'Gündəlik',
              'Həftəlik',
              'Aylıq',
            ], (v) => _frequency = v),
            if (_frequency == 'Aylıq')
              const Text(
                'Aylıq qeyd dəyişiklikləri izləmək üçün daha az məlumat verir.',
              ),
            const Text(
              'Bədən formasını özünüzə uyğunlaşdırın',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Bu seçimlər yalnız görünüşü dəyişir, ölçü və ya yağ faizi deyil.',
            ),
            for (var i = 0; i < 5; i++)
              Column(
                children: [
                  Text(_regions[i]),
                  Slider(
                    value: _proportions[i],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _proportions[i] = v),
                  ),
                ],
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saxlanılır…' : 'Təsdiqlə'),
            ),
            if (widget.onSkip != null)
              TextButton(
                onPressed: _busy ? null : widget.onSkip,
                child: const Text('İndi keç'),
              ),
          ],
        ),
      ),
    ),
  );
}

class BodyProgressPage extends StatefulWidget {
  const BodyProgressPage({super.key, required this.uid});
  final String uid;
  @override
  State<BodyProgressPage> createState() => _BodyProgressPageState();
}

class _BodyProgressPageState extends State<BodyProgressPage> {
  late Stream<Map<String, dynamic>> _stream;
  @override
  void initState() {
    super.initState();
    _stream = LocalStore.instance.watch(widget.uid);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: () =>
                setState(() => _stream = LocalStore.instance.watch(widget.uid)),
            child: const Text('Məlumat oxunmadı. Yenidən cəhd et'),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final p = Map<String, dynamic>.from(snapshot.data!['profile'] as Map);
      if (p['bodySetup'] != true) {
        return Center(
          child: FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => BodySetupPage(uid: widget.uid, profile: p),
              ),
            ),
            child: const Text('Bədən profilini yarat'),
          ),
        );
      }
      final records =
          (snapshot.data!['weights'] as Map? ?? {}).values
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
            ..sort(
              (a, b) => (a['loggedAt'] as Timestamp).compareTo(
                b['loggedAt'] as Timestamp,
              ),
            );
      if (records.isEmpty) {
        return const Center(child: Text('Çəki tarixçəsi tapılmadı.'));
      }
      final first = records.firstWhere(
        (r) => r['baseline'] == true,
        orElse: () => records.first,
      );
      final latest = records.last;
      final weight = (latest['weight'] as num).toDouble();
      final firstWeight = (first['weight'] as num).toDouble();
      final lastDate = (latest['loggedAt'] as Timestamp).toDate();
      final next = p['frequency'] == 'Aylıq'
          ? DateTime(lastDate.year, lastDate.month + 1, lastDate.day)
          : lastDate.add(Duration(days: p['frequency'] == 'Gündəlik' ? 1 : 7));
      final dates = MaterialLocalizations.of(context);
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${p['name']}, irəliləyişiniz',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text('Hədəf: ${p['targetWeight']} kq • ${p['goal']}'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Başlanğıc'),
                    BodyFigure(
                      weight: firstWeight,
                      height: (first['height'] as num).toDouble(),
                      shape: _shape(first),
                    ),
                    Text('$firstWeight kq'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text('İndi'),
                    BodyFigure(
                      weight: weight,
                      height: (p['height'] as num).toDouble(),
                      shape: _shape(p),
                    ),
                    Text('$weight kq'),
                  ],
                ),
              ),
            ],
          ),
          Text(
            'Dəyişiklik: ${(weight - firstWeight) >= 0 ? '+' : ''}${(weight - firstWeight).toStringAsFixed(1)} kq',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Təxmini vizual • Bədən formasını özünüz təsdiqləyirsiniz. Yağ faizi və dəri dəyişiklikləri hesablanmır.',
          ),
          const SizedBox(height: 16),
          Text(
            '${p['frequency']} qeyd • Növbəti qeyd: ${dates.formatMediumDate(next)}',
          ),
          if (p['frequency'] == 'Aylıq')
            const Text('Dəyişiklikləri izləmək üçün daha az məlumat verir.'),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => WeightEntryPage(
                  uid: widget.uid,
                  profile: p,
                  latest: latest,
                ),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Çəki qeyd et'),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => BodySetupPage(uid: widget.uid, profile: p),
              ),
            ),
            child: const Text('Profil və qeyd tezliyini dəyiş'),
          ),
          const Text(
            'Çəki tarixçəsi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          for (final r in records.reversed)
            ListTile(
              leading: const Icon(Icons.monitor_weight_outlined),
              title: Text('${r['weight']} kq'),
              subtitle: Text(
                dates.formatFullDate((r['loggedAt'] as Timestamp).toDate()),
              ),
            ),
        ],
      );
    },
  );
}

class WeightEntryPage extends StatefulWidget {
  const WeightEntryPage({
    super.key,
    required this.uid,
    required this.profile,
    required this.latest,
  });
  final String uid;
  final Map<String, dynamic> profile, latest;
  @override
  State<WeightEntryPage> createState() => _WeightEntryPageState();
}

class _WeightEntryPageState extends State<WeightEntryPage> {
  late final TextEditingController _weight;
  late List<double> _proportions;
  final _form = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;
  late final String _id;
  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(text: '${widget.latest['weight']}');
    _proportions = _shape(widget.profile);
    _id = LocalStore.instance.newId();
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  double? get _value => double.tryParse(_weight.text.replaceAll(',', '.'));
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await LocalStore.instance.update(widget.uid, (state) {
        final records =
            state.putIfAbsent('weights', () => <String, dynamic>{}) as Map;
        records[_id] = {
          'weight': _value,
          'height': widget.profile['height'],
          'shape': List.of(_proportions),
          'loggedAt': Timestamp.fromDate(_date),
        };
        final latest = records.values.cast<Map>().reduce(
          (a, b) =>
              (a['loggedAt'] as Timestamp).compareTo(
                    b['loggedAt'] as Timestamp,
                  ) >
                  0
              ? a
              : b,
        );
        (state['profile'] as Map).addAll(<String, dynamic>{
          'weight': latest['weight'],
          'shape': latest['shape'],
        });
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Saxlanmadı. Yenidən cəhd edin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Çəki qeyd et')),
    body: Form(
      key: _form,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: BodyFigure(
                weight: (_value ?? 80).clamp(20, 400),
                height: (widget.profile['height'] as num).toDouble(),
                shape: _proportions,
              ),
            ),
            const Text('Təxmini görünüşü özünüzə uyğunlaşdırıb təsdiqləyin.'),
            TextFormField(
              controller: _weight,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Çəki (kq)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              validator: (_) =>
                  _value == null ||
                      !_value!.isFinite ||
                      _value! < 20 ||
                      _value! > 400
                  ? '20–400 arasında düzgün çəki yazın.'
                  : null,
            ),
            ListTile(
              title: const Text('Qeyd tarixi'),
              subtitle: Text(
                MaterialLocalizations.of(context).formatFullDate(_date),
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: _busy
                  ? null
                  : () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null && mounted) setState(() => _date = date);
                    },
            ),
            for (var i = 0; i < 5; i++)
              Column(
                children: [
                  Text(_regions[i]),
                  Slider(
                    value: _proportions[i],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _proportions[i] = v),
                  ),
                ],
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saxlanılır…' : 'Görünüşü təsdiqlə və saxla'),
            ),
          ],
        ),
      ),
    ),
  );
}
