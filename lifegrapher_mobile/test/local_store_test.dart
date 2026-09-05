import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifegrapher_mobile/local_store.dart';

void main() {
  late Directory directory;
  late LocalStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lifegrapher-test-');
    store = LocalStore(directory);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'Meals, sleep and goals persist after reopening, isolated by account',
    () async {
      final time = DateTime(2026, 9, 5, 12);
      await store.saveEntry('alice', 'meals', 'meal1', {
        'name': 'Yulaf',
        'calories': 250.5,
        'loggedAt': time,
      });
      await store.saveEntry('alice', 'sleep', 'sleep1', {
        'durationMinutes': 480,
        'wakeTime': time,
      });
      await store.saveProfile('alice', {
        'calorieGoal': 2100,
        'loginId': '123456789',
        'email': 'alice@example.com',
      });
      final reopened = LocalStore(directory);
      final state = await reopened.read('alice');
      expect(state['meals']['meal1']['calories'], 250.5);
      expect((state['meals']['meal1']['loggedAt'] as Timestamp).toDate(), time);
      expect(state['sleep']['sleep1']['durationMinutes'], 480);
      expect(state['profile']['calorieGoal'], 2100);
      expect((await reopened.read('bob'))['meals'], isEmpty);
      expect(await reopened.emailForId('123456789'), 'alice@example.com');
    },
  );

  test(
    'Concurrent saves keep every entry and retry replaces the same ID',
    () async {
      await Future.wait(
        List.generate(
          20,
          (i) => store.saveEntry('alice', 'meals', '$i', {'calories': i}),
        ),
      );
      await store.saveEntry('alice', 'meals', '0', {'calories': 99});
      final state = await store.read('alice');
      expect((state['meals'] as Map).length, 20);
      expect(state['meals']['0']['calories'], 99);
    },
  );

  test(
    'Date filters and newest-first sorting use persisted timestamps',
    () async {
      for (var day = 4; day <= 6; day++) {
        await store.saveEntry('alice', 'meals', '$day', {
          'loggedAt': DateTime(2026, 9, day),
        });
      }
      final snapshot = await store
          .collection('alice', 'meals')
          .where(
            'loggedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(2026, 9, 5)),
            isLessThan: Timestamp.fromDate(DateTime(2026, 9, 7)),
          )
          .orderBy('loggedAt', descending: true)
          .snapshots()
          .first;
      expect(snapshot.docs.map((doc) => doc.id), ['6', '5']);
    },
  );

  test('Unreadable data is not silently overwritten', () async {
    await store.saveProfile('alice', {'loginId': '123456789'});
    final file = (await directory.list().toList()).whereType<File>().single;
    await file.writeAsString('broken JSON');
    await expectLater(
      store.saveEntry('alice', 'meals', '1', {'calories': 20}),
      throwsFormatException,
    );
    expect(await file.readAsString(), 'broken JSON');
  });

  test('Water records persist, can be edited, and can be deleted', () async {
    await store.saveEntry('alice', 'water', 'glass', {
      'milliliters': 300,
      'loggedAt': DateTime(2026, 9, 5, 9),
    });
    await store.saveEntry('alice', 'water', 'glass', {
      'milliliters': 500,
      'loggedAt': DateTime(2026, 9, 5, 9),
    });
    expect((await store.read('alice'))['water']['glass']['milliliters'], 500);
    await store.deleteEntry('alice', 'water', 'glass');
    expect((await store.read('alice'))['water'], isEmpty);
  });
}
