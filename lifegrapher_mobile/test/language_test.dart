import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifegrapher_mobile/app_language.dart';
import 'package:lifegrapher_mobile/main.dart';
import 'package:lifegrapher_mobile/entry_page.dart';
import 'package:lifegrapher_mobile/translations.dart';

void main() {
  setUp(() {
    appLanguage.value = const Locale('az');
  });
  tearDown(() {
    appLanguage.value = const Locale('az');
  });

  test('Every message has five translations with matching placeholders', () {
    final placeholders = RegExp(r'\{\w+\}');
    for (final entry in translations.entries) {
      expect(entry.value.length, 5, reason: entry.key);
      final expected = placeholders
          .allMatches(entry.value.first)
          .map((m) => m[0])
          .toSet();
      for (final value in entry.value) {
        expect(value.trim(), isNotEmpty, reason: entry.key);
        expect(
          placeholders.allMatches(value).map((m) => m[0]).toSet(),
          expected,
          reason: entry.key,
        );
      }
    }
  });

  test('Selected language persists after reopening and invalid choices are rejected', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lifegrapher-language-',
    );
    try {
      final first = LanguageController();
      await first.initialize(directory);
      await first.select('de');
      final reopened = LanguageController();
      await reopened.initialize(directory);
      expect(reopened.value.languageCode, 'de');
      await expectLater(reopened.select('xx'), throwsArgumentError);
      expect(reopened.value.languageCode, 'de');
      first.dispose();
      reopened.dispose();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  testWidgets('Language picker switches the existing login screen in place', (
    tester,
  ) async {
    await tester.pumpWidget(const LifeGrapherApp(home: LoginScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '34555');
    await tester.tap(find.byType(LanguagePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(appLanguage.value.languageCode, 'de');
    expect(
      Localizations.localeOf(tester.element(find.byType(LoginScreen)))
          .languageCode,
      'de',
    );
    expect(find.text('Anmelden'), findsOneWidget);
    expect(find.text('34555'), findsOneWidget);
    expect(find.text('Mit Apple anmelden'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final code in languageNames.keys) {
    testWidgets('$code: login and meal/sleep/goal forms fit a small phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      appLanguage.value = Locale(code);
      await tester.pumpWidget(const LifeGrapherApp(home: LoginScreen()));
      await tester.pumpAndSettle();
      expect(find.text(translate(code, 'Daxil ol')), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final kind in EntryKind.values) {
        await tester.pumpWidget(
          LifeGrapherApp(
            home: EntryPage(
              key: ValueKey(kind),
              kind: kind,
              onSave: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final save = translate(
          code,
          kind == EntryKind.goals ? 'Yadda saxla' : 'Əlavə et',
        );
        expect(
          find.widgetWithText(FilledButton, save).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (kind == EntryKind.meal) {
          expect(find.text(translate(code, 'Səhər yeməyi')), findsOneWidget);
          await tester.tap(find.text(save));
          await tester.pumpAndSettle();
          expect(
            find.text(translate(code, 'Yeməyin adını yazın.')),
            findsOneWidget,
          );
        }
        if (kind == EntryKind.sleep) {
          await tester.tap(find.text(translate(code, 'Yatış saatı')));
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(DatePickerDialog));
          expect(Localizations.localeOf(context).languageCode, code);
          expect(
            find.text(MaterialLocalizations.of(context).cancelButtonLabel),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.text(MaterialLocalizations.of(context).cancelButtonLabel),
          );
          await tester.pumpAndSettle();
        }
      }
    });
  }

  testWidgets('Legacy meal types translate without changing saved data', (
    tester,
  ) async {
    appLanguage.value = const Locale('ru');
    await tester.pumpWidget(
      LifeGrapherApp(
        home: Builder(
          builder: (context) =>
              Scaffold(body: Text(mealTypeText(context, 'Səhər yeməyi'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Завтрак'), findsOneWidget);
  });
}
