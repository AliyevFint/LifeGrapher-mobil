import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

class LocalDocument {
  LocalDocument(this.id, this._data);
  final String id;
  final Map<String, dynamic> _data;
  Map<String, dynamic> data() => Map.of(_data);
}

class LocalSnapshot {
  LocalSnapshot(this.docs);
  final List<LocalDocument> docs;
}

class LocalProfileSnapshot {
  LocalProfileSnapshot(this._data);
  final Map<String, dynamic> _data;
  Map<String, dynamic> data() => Map.of(_data);
}

/// Disk writes are serialized and atomically replace the previous file.
/// Notifications and successful futures are emitted only after the write.
class LocalStore {
  LocalStore(this.directory);
  final Directory directory;
  static late LocalStore instance;
  final _changes = StreamController<String>.broadcast();
  Future<void> _pending = Future.value();

  static Future<void> initialize() async {
    final root = await getApplicationSupportDirectory();
    instance = LocalStore(Directory('${root.path}/records'));
  }

  File _file(String uid) =>
      File('${directory.path}/${base64Url.encode(utf8.encode(uid))}.json');

  Future<Map<String, dynamic>> read(String uid) async {
    final file = _file(uid);
    if (!await file.exists()) {
      return {
        'profile': <String, dynamic>{},
        'meals': <String, dynamic>{},
        'sleep': <String, dynamic>{},
        'water': <String, dynamic>{},
      };
    }
    return Map<String, dynamic>.from(
      jsonDecode(
        await file.readAsString(),
        reviver: (_, value) {
          if (value is Map &&
              value.length == 1 &&
              value['__timestamp'] is int) {
            return Timestamp.fromMillisecondsSinceEpoch(
              value['__timestamp'] as int,
            );
          }
          return value;
        },
      ) as Map,
    );
  }

  Future<void> update(String uid, void Function(Map<String, dynamic>) edit) {
    final result = _pending.then((_) async {
      final state = await read(uid);
      edit(state);
      await directory.create(recursive: true);
      final target = _file(uid);
      final temp = File('${target.path}.tmp');
      await temp.writeAsString(
        jsonEncode(
          state,
          toEncodable: (value) {
            if (value is Timestamp) {
              return {'__timestamp': value.millisecondsSinceEpoch};
            }
            if (value is DateTime) {
              return {'__timestamp': value.millisecondsSinceEpoch};
            }
            throw ArgumentError('Unsupported local value');
          },
        ),
        flush: true,
      );
      await temp.rename(target.path);
      _changes.add(uid);
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> saveProfile(String uid, Map<String, dynamic> data) =>
      update(uid, (state) {
        state['profile'] = {
          ...Map<String, dynamic>.from(state['profile'] as Map),
          ...data,
        };
      });

  String newId() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Future<void> saveEntry(
    String uid,
    String collection,
    String id,
    Map<String, dynamic> data,
  ) => update(uid, (state) {
    state.putIfAbsent(collection, () => <String, dynamic>{});
    (state[collection] as Map)[id] = data;
  });

  Future<void> deleteEntry(String uid, String collection, String id) =>
      update(uid, (state) {
        (state[collection] as Map?)?.remove(id);
      });

  Stream<Map<String, dynamic>> watch(String uid) => Stream.multi((sink) {
    Future<void> reads = Future.value();
    void emit() {
      reads = reads.then((_) async {
        try {
          sink.add(await read(uid));
        } catch (error, stack) {
          sink.addError(error, stack);
        }
      });
    }

    final subscription = _changes.stream
        .where((changed) => changed == uid)
        .listen((_) => emit());
    emit();
    sink.onCancel = subscription.cancel;
  });

  Stream<LocalProfileSnapshot> profile(String uid) => watch(uid).map(
    (state) => LocalProfileSnapshot(
      Map<String, dynamic>.from(state['profile'] as Map),
    ),
  );

  LocalCollection collection(String uid, String name) =>
      LocalCollection(this, uid, name);

  Future<String?> emailForId(String id) async {
    if (!await directory.exists()) return null;
    await for (final file in directory.list()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      final state = jsonDecode(await file.readAsString()) as Map;
      final profile = state['profile'] as Map;
      if (profile['loginId'] == id) return profile['email'] as String?;
    }
    return null;
  }
}

class LocalCollection {
  LocalCollection(this.store, this.uid, this.name);
  final LocalStore store;
  final String uid;
  final String name;
  String? _sort;
  bool _descending = false;
  final _filters = <bool Function(Map<String, dynamic>)>[];

  LocalCollection orderBy(String key, {bool descending = false}) {
    _sort = key;
    _descending = descending;
    return this;
  }

  LocalCollection where(
    String key, {
    Timestamp? isGreaterThanOrEqualTo,
    Timestamp? isLessThan,
  }) {
    _filters.add((data) {
      final value = data[key];
      if (value is! Timestamp) return false;
      return (isGreaterThanOrEqualTo == null ||
              value.compareTo(isGreaterThanOrEqualTo) >= 0) &&
          (isLessThan == null || value.compareTo(isLessThan) < 0);
    });
    return this;
  }

  Stream<LocalSnapshot> snapshots() => store.watch(uid).map((state) {
    final entries = (state[name] as Map).entries
        .map(
          (entry) => LocalDocument(
            entry.key as String,
            Map<String, dynamic>.from(entry.value as Map),
          ),
        )
        .where((doc) => _filters.every((filter) => filter(doc.data())))
        .toList();
    if (_sort != null) {
      entries.sort((a, b) {
        final av = a.data()[_sort] as Timestamp?;
        final bv = b.data()[_sort] as Timestamp?;
        final comparison = (av?.millisecondsSinceEpoch ?? 0).compareTo(
          bv?.millisecondsSinceEpoch ?? 0,
        );
        return _descending ? -comparison : comparison;
      });
    }
    return LocalSnapshot(entries);
  });
}
