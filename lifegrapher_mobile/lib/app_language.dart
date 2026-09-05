import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'translations.dart';

const languageNames = <String, String>{
  'az': 'Azərbaycan dili',
  'en': 'English',
  'tr': 'Türkçe',
  'de': 'Deutsch',
  'ru': 'Русский',
};

class LanguageController extends ValueNotifier<Locale> {
  LanguageController() : super(const Locale('az'));
  File? _file;
  Future<void>? _writes;

  Future<void> initialize(Directory directory) async {
    _file = File('${directory.path}/language.json');
    if (!await _file!.exists()) return;
    try {
      final code = (jsonDecode(await _file!.readAsString()) as Map)['language'];
      if (languageNames.containsKey(code)) value = Locale(code as String);
    } on FormatException {
      // An invalid preference must not prevent the app from opening.
    }
  }

  Future<void> select(String code) {
    if (!languageNames.containsKey(code)) {
      return Future.error(ArgumentError.value(code));
    }
    Future<void> persist() async {
      final file = _file;
      if (file != null) {
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(
          jsonEncode({'language': code}),
          flush: true,
        );
        await temporary.rename(file.path);
      }
      value = Locale(code);
    }

    final result = _writes?.then((_) => persist()) ?? persist();
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

final appLanguage = LanguageController();

String translate(
  String code,
  String key, [
  Map<String, String> values = const {},
]) {
  final entries = translations[key];
  if (entries == null) throw ArgumentError('Missing translation: $key');
  final index = languageNames.keys.toList().indexOf(code);
  var result = entries[index < 0 ? 0 : index];
  for (final entry in values.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value);
  }
  return result;
}

String tr(
  BuildContext context,
  String key, [
  Map<String, String> values = const {},
]) => translate(Localizations.localeOf(context).languageCode, key, values);

String formatNumber(BuildContext context, num value, [int decimals = 0]) =>
    NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).languageCode,
      decimalDigits: decimals,
    ).format(value);

String amount(
  BuildContext context,
  String key,
  num value, [
  int decimals = 0,
]) => tr(context, key, {'value': formatNumber(context, value, decimals)});

String mealTypeText(BuildContext context, String? stored) {
  const aliases = {
    'breakfast': 'Səhər yeməyi',
    'lunch': 'Nahar',
    'dinner': 'Şam yeməyi',
    'snack': 'Ara yemək',
  };
  final key = aliases[stored] ?? stored;
  return tr(context, translations.containsKey(key) ? key! : 'Yemək');
}

class LanguagePicker extends StatefulWidget {
  const LanguagePicker({super.key, this.compact = false});
  final bool compact;
  @override
  State<LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<LanguagePicker> {
  bool _saving = false;
  Future<void> _select(String code) async {
    setState(() => _saving = true);
    try {
      await appLanguage.select(code);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'languageSaveError'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(tr(dialogContext, 'Dil')),
        children: languageNames.entries
            .map(
              (entry) => SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(entry.key),
                child: Row(
                  children: [
                    Icon(
                      entry.key == appLanguage.value.languageCode
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null && mounted) await _select(selected);
  }

  @override
  Widget build(BuildContext context) => widget.compact
      ? TextButton.icon(
          onPressed: _saving ? null : _open,
          icon: const Icon(Icons.language),
          label: Text(
            languageNames[Localizations.localeOf(context).languageCode]!,
          ),
        )
      : ListTile(
          onTap: _saving ? null : _open,
          leading: const Icon(Icons.language_outlined),
          title: Text(tr(context, 'Dil')),
          subtitle: Text(
            languageNames[Localizations.localeOf(context).languageCode]!,
          ),
          trailing: const Icon(Icons.expand_more),
        );
}
