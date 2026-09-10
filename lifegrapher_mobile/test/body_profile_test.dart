import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifegrapher_mobile/body_profile.dart';
import 'package:lifegrapher_mobile/local_store.dart';

Future<void> settleDisk(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }
  await tester.pumpAndSettle();
}

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('body-profile-test');
    LocalStore.instance = LocalStore(root);
  });
  tearDown(() async => root.delete(recursive: true));

  testWidgets('Welcome can be skipped and is shown again next session', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BodyProfileGate(uid: 'a', child: Text('Home')),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleDisk(tester);
    expect(find.text('Xoş gəlmisiniz!'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('İndi keç'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('İndi keç'));
    await settleDisk(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(
      (await tester.runAsync(() => LocalStore.instance.read('a')))!['profile'],
      isEmpty,
    );
  });

  testWidgets(
    'Setup saves profile and baseline atomically and gate opens home',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BodyProfileGate(uid: 'a', child: Text('Home')),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await settleDisk(tester);
      final values = ['Ali', '25', '180', '100', '90'];
      for (var i = 0; i < values.length; i++) {
        final field = find.byType(TextFormField).at(i);
        await tester.ensureVisible(field);
        await tester.enterText(field, values[i]);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await settleDisk(tester);
      await tester.scrollUntilVisible(
        find.text('Təsdiqlə'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await settleDisk(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Təsdiqlə'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settleDisk(tester);
      expect(find.text('Home'), findsOneWidget);
      final state = (await tester.runAsync(() => LocalStore(root).read('a')))!;
      expect(state['profile']['name'], 'Ali');
      expect(state['weights'].length, 1);
      expect(state['weights'].values.first['weight'], 100);
    },
  );

  testWidgets('Weight update preserves baseline and shows comparison', (
    tester,
  ) async {
    final profile = <String, dynamic>{
      'bodySetup': true,
      'name': 'Ali',
      'age': 25,
      'height': 180.0,
      'weight': 100.0,
      'targetWeight': 90.0,
      'goal': 'Arıqlamaq',
      'frequency': 'Həftəlik',
    };
    final first = <String, dynamic>{
      'weight': 100.0,
      'height': 180.0,
      'loggedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    };
    await tester.runAsync(
      () => LocalStore.instance.update('a', (s) {
        s['profile'] = profile;
        s['weights'] = {'first': first};
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => WeightEntryPage(
                    uid: 'a',
                    profile: profile,
                    latest: first,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settleDisk(tester);
    await tester.enterText(find.byType(TextFormField), '95,5');
    FocusManager.instance.primaryFocus?.unfocus();
    await settleDisk(tester);
    await tester.scrollUntilVisible(
      find.text('Görünüşü təsdiqlə və saxla'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await settleDisk(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Görünüşü təsdiqlə və saxla'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settleDisk(tester);
    final saved = (await tester.runAsync(() => LocalStore(root).read('a')))!;
    expect(saved['weights'].length, 2);
    expect(saved['weights']['first']['weight'], 100);
    expect(saved['profile']['weight'], 95.5);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BodyProgressPage(uid: 'a')),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleDisk(tester);
    expect(find.text('Dəyişiklik: -4.5 kq'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
