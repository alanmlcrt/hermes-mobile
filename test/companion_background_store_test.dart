import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/data/storage/migrations.dart';
import 'package:hermes_mobile/data/storage/companion_background_store.dart';
import 'package:hermes_mobile/models/companion_background.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/profile.dart';

void main() {
  sqfliteFfiInit();
  test(
    'migration v7, identité complète, casse et réouverture réelle',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'companion-background-',
      );
      final path = '${dir.path}/prefs.sqlite';
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (db, version) async {
            for (final migration in connectionMigrations.take(version)) {
              await migration(db);
            }
          },
        ),
      );
      await old.insert('connection_entries', {
        'connection_key': 'same',
        'origin': 'https://one.example',
      });
      await old.close();
      var db = await openConnectionDatabase(
        factory: databaseFactoryFfi,
        path: path,
      );
      var store = SqliteCompanionBackgroundStore(db);
      CompanionBackgroundIdentity id(
        String server,
        String profile, [
        String key = 'same',
      ]) => CompanionBackgroundIdentity(
        parseOrigin(server),
        ConnectionKey(key),
        ProfileKey(profile),
      );
      final ids = [
        id('https://ONE.example/', 'Work'),
        id('https://one.example', 'work'),
        id('https://two.example', 'Work'),
        id('https://two.example', 'work'),
        id('https://one.example', 'Work', 'Same'),
      ];
      expect(await db.query('connection_entries'), hasLength(1));
      expect(await store.read(ids.first), CompanionPalette.lavenderPeach);
      expect(await db.query('companion_backgrounds'), isEmpty);
      for (var i = 0; i < ids.length; i++) {
        await store.save(ids[i], CompanionPalette.values[i % 3]);
      }
      await db.close();
      db = await openConnectionDatabase(
        factory: databaseFactoryFfi,
        path: path,
      );
      store = SqliteCompanionBackgroundStore(db);
      for (var i = 0; i < ids.length; i++) {
        expect(await store.read(ids[i]), CompanionPalette.values[i % 3]);
      }
      expect(
        await store.read(id('https://one.example', 'Work')),
        CompanionPalette.lavenderPeach,
      );
      await db.update(
        'companion_backgrounds',
        {'palette_id': 'future'},
        where: 'origin = ? AND connection_key = ? AND profile_key = ?',
        whereArgs: [ids.first.origin, 'same', 'Work'],
      );
      expect(await store.read(ids.first), CompanionPalette.lavenderPeach);
      expect(
        (await db.query('companion_backgrounds')).first['palette_id'],
        'future',
      );
      await store.save(ids.first, CompanionPalette.roseLilac);
      expect(await db.query('companion_backgrounds'), hasLength(ids.length));
      await db.close();
      await expectLater(
        store.save(ids.first, CompanionPalette.mintSky),
        throwsA(anything),
      );
      await expectLater(store.read(ids.first), throwsA(anything));
      await dir.delete(recursive: true);
    },
  );
}
