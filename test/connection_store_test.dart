import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/data/storage/connection_store.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/profile.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hermes-storage-');
    path = '${directory.path}/hermes.sqlite';
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test(
    'création, réouverture, sélection sensible à la casse et clé stable',
    () async {
      var database = await openConnectionDatabase(
        factory: databaseFactoryFfi,
        path: path,
      );
      var store = SqliteConnectionStore(database);
      expect(await store.read(), isNull);
      final key = ConnectionKey.create();
      await store.save(
        Connection(
          key: key,
          origin: parseOrigin('https://one.example'),
          selectedProfile: const ProfileKey('Travail'),
        ),
      );
      await database.close();
      database = await openConnectionDatabase(
        factory: databaseFactoryFfi,
        path: path,
      );
      store = SqliteConnectionStore(database);
      final restored = (await store.read())!;
      expect(restored.key, key);
      expect(restored.selectedProfile, const ProfileKey('Travail'));
      expect(restored.selectedProfile, isNot(const ProfileKey('travail')));
      await store.save(
        Connection(
          key: restored.key,
          origin: parseOrigin('http://desktop.ts.net:9119'),
        ),
      );
      expect((await store.read())!.key, key);
      final columns = await database.rawQuery(
        'PRAGMA table_info(connection_entries)',
      );
      expect(columns.map((column) => column['name']), [
        'connection_key',
        'origin',
        'selected_profile',
      ]);
      expect(await database.getVersion(), 6);
      await database.close();
    },
  );
  test('migration réelle v1 vers v2 conserve les données existantes', () async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE connection_entries ('
          'connection_key TEXT PRIMARY KEY, origin TEXT NOT NULL)',
        ),
      ),
    );
    await old.insert('connection_entries', {
      'connection_key': 'stable-v1',
      'origin': 'https://legacy.example',
    });
    await old.close();
    final database = await openConnectionDatabase(
      factory: databaseFactoryFfi,
      path: path,
    );
    final value = (await SqliteConnectionStore(database).read())!;
    expect(value.key.value, 'stable-v1');
    expect(value.selectedProfile, isNull);
    expect(value.origin.toString(), 'https://legacy.example');
    await database.close();
  });
}
