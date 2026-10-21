import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';

import 'support/connection_fakes.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  const connection = ConnectionKey('c-1');
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hermes-outbox-');
    path = '${directory.path}/hermes.sqlite';
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  Future<Database> open() =>
      openConnectionDatabase(factory: databaseFactoryFfi, path: path);

  test('relance : même DraftKey et texte relu après réouverture', () async {
    var database = await open();
    var outbox = OutboxRepository(database, gateway: Harness().repository);
    final draft = await outbox.openNewDraft(
      connection,
      const ProfileKey('Travail'),
    );
    expect(draft.body, isEmpty);
    await outbox.saveText(draft.key, 'abc');
    await outbox.dispose();
    await database.close();
    database = await open();
    outbox = OutboxRepository(database, gateway: Harness().repository);
    final again = await outbox.openNewDraft(
      connection,
      const ProfileKey('Travail'),
    );
    expect(again.key, draft.key);
    expect(again.body, 'abc');
    // Profil sensible à la casse : autre brouillon.
    final other = await outbox.openNewDraft(
      connection,
      const ProfileKey('travail'),
    );
    expect(other.key, isNot(draft.key));
    await database.close();
  });

  test("dispose attend l'écriture en cours avant fermeture", () async {
    var database = await open();
    final outbox = OutboxRepository(database, gateway: Harness().repository);
    final draft = await outbox.openNewDraft(connection, const ProfileKey('p'));
    unawaited(outbox.saveText(draft.key, 'en vol'));
    await outbox.dispose();
    await database.close();
    database = await open();
    expect(
      (await OutboxRepository(
        database,
        gateway: Harness().repository,
      ).draft(draft.key))!.body,
      'en vol',
    );
    await database.close();
  });

  test('long collage : 200 000 caractères, emojis et /cmd intacts', () async {
    final database = await open();
    final outbox = OutboxRepository(database, gateway: Harness().repository);
    final draft = await outbox.openNewDraft(connection, const ProfileKey('p'));
    final text = '/cmd 👩‍💻 é\n\t${'🚀a/' * 50000}';
    expect(text.length, greaterThan(200000));
    await outbox.saveText(draft.key, text);
    expect((await outbox.draft(draft.key))!.body, text);
    await database.close();
  });

  test('saisies rapides : la dernière écriture gagne', () async {
    final database = await open();
    final outbox = OutboxRepository(database, gateway: Harness().repository);
    final draft = await outbox.openNewDraft(connection, const ProfileKey('p'));
    final opens = await Future.wait([
      for (var i = 0; i < 5; i++)
        outbox.openNewDraft(connection, const ProfileKey('p')),
    ]);
    expect(opens.map((d) => d.key).toSet(), {draft.key});
    await Future.wait([
      for (var i = 0; i <= 50; i++) outbox.saveText(draft.key, 'v$i'),
    ]);
    expect((await outbox.draft(draft.key))!.body, 'v50');
    await database.close();
  });

  test('écriture échouée : storage.unavailable, la suivante passe', () async {
    final database = await open();
    final outbox = OutboxRepository(database, gateway: Harness().repository);
    await expectLater(
      outbox.saveText(const DraftKey('inconnu'), 'x'),
      throwsA(
        isA<AppError>().having((e) => e.code, 'code', 'storage.unavailable'),
      ),
    );
    final draft = await outbox.openNewDraft(connection, const ProfileKey('p'));
    await database.execute(
      'CREATE TRIGGER refuse BEFORE UPDATE ON outbox_drafts '
      "BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
    );
    await expectLater(
      outbox.saveText(draft.key, 'perdu'),
      throwsA(isA<AppError>()),
    );
    await database.execute('DROP TRIGGER refuse');
    await outbox.saveText(draft.key, 'gardé');
    expect((await outbox.draft(draft.key))!.body, 'gardé');
    await database.close();
  });

  test('migration réelle v2 vers v6 conserve la connexion', () async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE connection_entries ('
            'connection_key TEXT PRIMARY KEY, origin TEXT NOT NULL, '
            'selected_profile TEXT)',
          );
          await db.insert('connection_entries', {
            'connection_key': 'stable-v2',
            'origin': 'https://legacy.example',
            'selected_profile': 'Travail',
          });
        },
      ),
    );
    await old.close();
    final database = await open();
    expect(await database.getVersion(), 6);
    expect(
      (await database.query('connection_entries')).single['connection_key'],
      'stable-v2',
    );
    final columns = await database.rawQuery('PRAGMA table_info(outbox_drafts)');
    expect(columns.map((c) => c['name']), [
      'draft_key',
      'connection_key',
      'profile_key',
      'body',
      'updated_at',
      'revision',
      'stored_session_id',
      'idempotency_key',
    ]);
    final outbox = OutboxRepository(
      database,
      gateway: Harness().repository,
      now: () => DateTime.utc(2026, 10, 21, 8),
    );
    final draft = await outbox.openNewDraft(
      const ConnectionKey('stable-v2'),
      const ProfileKey('Travail'),
    );
    final row = (await database.query('outbox_drafts')).single;
    expect(row['draft_key'], draft.key.value);
    expect(row['updated_at'], '2026-10-21T08:00:00.000Z');
    await database.close();
  });
}
