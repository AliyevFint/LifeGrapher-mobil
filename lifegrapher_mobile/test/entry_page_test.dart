import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifegrapher_mobile/entry_page.dart';
import 'package:lifegrapher_mobile/main.dart';

Future<void> openForm(
  WidgetTester tester,
  EntryKind kind,
  Future<void> Function(Map<String, dynamic>) save,
) async {
  await tester.pumpWidget(
    LifeGrapherApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EntryPage(kind: kind, onSave: save),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> fillMeal(WidgetTester tester, {String calories = '250,5'}) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Yulaf');
  await tester.enterText(find.byType(TextFormField).at(1), calories);
}

void main() {
  testWidgets('Slow save stays pending and late success completes the form', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await openForm(tester, EntryKind.sleep, (_) {
      calls++;
      return pending.future;
    });
    await tester.tap(find.text('Əlavə et'));
    await tester.pump(const Duration(seconds: 21));
    expect(find.textContaining('Telefon yaddaşına yazılır.'), findsOneWidget);
    expect(find.textContaining('saxlanmadı.'), findsNothing);
    await tester.tap(find.text('Saxlanılır…'));
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Slow save reports a real rejection and allows retry', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await openForm(tester, EntryKind.sleep, (_) {
      calls++;
      return calls == 1 ? pending.future : Future<void>.value();
    });
    await tester.tap(find.text('Əlavə et'));
    await tester.pump(const Duration(seconds: 21));
    pending.completeError(StateError('permission denied'));
    await tester.pumpAndSettle();
    expect(find.textContaining('saxlanmadı.'), findsOneWidget);
    expect(find.textContaining('Telefon yaddaşına yazılır.'), findsNothing);
    await tester.tap(find.text('Əlavə et'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('Leaving a slow save does not pop another page on late success', (
    tester,
  ) async {
    final pending = Completer<void>();
    await openForm(tester, EntryKind.sleep, (_) => pending.future);
    await tester.tap(find.text('Əlavə et'));
    await tester.pump(const Duration(seconds: 21));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Meal requires valid input and accepts decimal commas', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    await openForm(tester, EntryKind.meal, (data) async {
      saved = data;
    });
    await tester.tap(find.text('Əlavə et'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.text('Yeməyin adını yazın.'), findsOneWidget);
    await fillMeal(tester, calories: '-2');
    await tester.tap(find.text('Əlavə et'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    await fillMeal(tester);
    await tester.tap(find.text('Əlavə et'));
    await tester.pumpAndSettle();
    expect(saved?['calories'], 250.5);
    expect(saved?['protein'], 0);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Failed saves preserve input and allow retry without leaving form',
    (tester) async {
      var attempts = 0;
      await openForm(tester, EntryKind.meal, (_) async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
      });
      await fillMeal(tester);
      await tester.tap(find.text('Əlavə et'));
      await tester.pumpAndSettle();
      expect(find.textContaining('saxlanmadı.'), findsOneWidget);
      expect(find.text('Yulaf'), findsOneWidget);
      await tester.tap(find.text('Əlavə et'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pending save prevents duplicate submissions and back navigation',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await openForm(tester, EntryKind.sleep, (data) {
        calls++;
        expect(data['durationMinutes'], 480);
        expect(data['quality'], 3);
        return pending.future;
      });
      await tester.tap(find.text('Əlavə et'));
      await tester.pump();
      await tester.tap(find.text('Saxlanılır…'));
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(EntryPage), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Add button remains visible with keyboard on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await openForm(tester, EntryKind.meal, (_) async {});
    await tester.tap(find.byType(TextFormField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Əlavə et');
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(367));
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Goals reject nonfinite numbers and sleep over 24 hours', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    await openForm(tester, EntryKind.goals, (data) async {
      saved = data;
    });
    await tester.enterText(find.byType(TextFormField).first, 'NaN');
    await tester.enterText(find.byType(TextFormField).last, '25');
    await tester.tap(find.text('Yadda saxla'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    await tester.enterText(find.byType(TextFormField).first, '2100');
    await tester.enterText(find.byType(TextFormField).last, '7,5');
    await tester.tap(find.text('Yadda saxla'));
    await tester.pumpAndSettle();
    expect(saved?['sleepGoalMinutes'], 450);
  });

  testWidgets(
    'Water validates an amount and preserves the original time when edited',
    (tester) async {
      Map<String, dynamic>? saved;
      final time = DateTime(2026, 9, 5, 10);
      await tester.pumpWidget(
        LifeGrapherApp(
          home: EntryPage(
            kind: EntryKind.water,
            initialData: {'milliliters': 250, 'loggedAt': time},
            onSave: (data) async => saved = data,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Su əlavə et'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '500');
      await tester.tap(find.text('Dəyişiklikləri saxla'));
      await tester.pumpAndSettle();
      expect(saved?['milliliters'], 500);
      expect(saved?['loggedAt'], time);
      expect(tester.takeException(), isNull);
    },
  );
}
