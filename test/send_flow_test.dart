import 'dart:io';

import 'package:hermes_mobile/data/storage/migrations.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/connection_fakes.dart';

Map<String, dynamic> _result(String name) =>
    Map<String, dynamic>.from(fixture(name)['result'] as Map);

/// Script nominal : chaque méthode répond avec sa fixture.
Object? _happy(String method, Map<String, dynamic> params) => switch (method) {
  'session.create' => _result('session-create'),
  'session.resume' => _result('session-resume'),
  'prompt.submit' => _result('prompt-submit'),
  _ => null,
};

const _text = 'Bonjour 🚀\n/cmd';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database database;
  late Harness h;
  late OutboxRepository outbox;
  late Draft draft;
  late List<String> steps;
  const connection = ConnectionKey('c-1');
  const profile = ProfileKey('default');

  List<String> methods() => [
    for (final f in h.transport.frames)
      if (f['id'] != 'capabilities') f['method'] as String,
  ];
  Future<Map<String, Object?>> operation() async =>
      (await database.query('outbox_operations')).single;
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await settle();
    }
  }

  Future<void> openDatabase() async {
    directory = await Directory.systemTemp.createTemp('hermes-send-');
    database = await openConnectionDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/hermes.sqlite',
    );
    h = Harness();
  }

  Future<void> start({Map<String, dynamic>? ready, bool connect = true}) async {
    await openDatabase();
    if (ready != null) h.transport.ready = ready;
    if (connect) {
      await h.connect();
      await settle();
    }
    steps = [];
    outbox = OutboxRepository(
      database,
      gateway: h.repository,
      timeout: const Duration(milliseconds: 100),
      onStep: steps.add,
    );
    draft = await outbox.openNewDraft(connection, profile);
    await outbox.saveText(draft.key, _text);
  }

  tearDown(() async {
    await outbox.dispose();
    await h.repository.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  test('premier envoi : opération en base avant toute trame, pipeline nommé, '
      'accepté, brouillon vidé, nouvel accueil sans session', () async {
    await start();
    h.transport.rpc = (method, params) =>
        method == 'prompt.submit' ? _result('prompt-submit') : null;
    final sending = outbox.send(draft.key);
    await until(() => methods().isNotEmpty);
    // session.create est parti et reste sans réponse : l'état est déjà en base.
    expect(methods(), ['session.create']);
    final create = h.transport.frames.last;
    expect(create['params'], {
      'profile': 'default',
      'close_on_disconnect': false,
      'idempotency_key': 'default/${draft.key.value}',
    });
    var op = await operation();
    expect(op['state'], 'preparing');
    expect(op['body'], _text);
    expect(
      (await database.query('outbox_drafts')).single['idempotency_key'],
      'default/${draft.key.value}',
    );
    expect(outbox.status(draft.key).state, OperationState.preparing);
    h.transport.sockets.single.controller.add({
      'jsonrpc': '2.0',
      'id': create['id'],
      'result': _result('session-create'),
    });
    await sending;
    expect(methods(), ['session.create', 'prompt.submit']);
    expect(h.transport.frames.last['params'], {
      'session_id': 'a1b2c3d4',
      'text': _text,
    });
    expect(steps, [
      'ensureSession',
      'attachments',
      'notificationTracking',
      'submit',
    ]);
    op = await operation();
    expect(op['state'], 'accepted');
    expect(op['user_row_id'], 42);
    final stored = await outbox.draft(draft.key);
    expect(stored!.body, isEmpty);
    expect(stored.storedSessionId, '<SYNTHETIC_STORED_SESSION>');
    expect(outbox.status(draft.key).state, OperationState.accepted);
    final next = await outbox.openNewDraft(connection, profile);
    expect(next.key, isNot(draft.key));
    expect(next.storedSessionId, isNull);
  });

  test('deux ensureSession simultanés : une seule session.create', () async {
    await start();
    h.transport.rpc = _happy;
    final both = await Future.wait([
      outbox.ensureSession(draft.key),
      outbox.ensureSession(draft.key),
    ]);
    expect(both, ['a1b2c3d4', 'a1b2c3d4']);
    expect(methods(), ['session.create']);
    // Session déjà connue sur cette socket : aucun nouvel appel.
    await outbox.ensureSession(draft.key);
    expect(methods(), ['session.create']);
  });

  test('réponse perdue : unknown, brouillon intact, aucun 2e submit', () async {
    await start();
    h.transport.rpc = (method, params) =>
        method == 'prompt.submit' ? const RpcDrop() : _happy(method, params);
    await outbox.send(draft.key);
    final status = outbox.status(draft.key);
    expect(status.state, OperationState.unknown);
    expect(status.errorCode, 'send.unknown');
    expect(methods().where((m) => m == 'prompt.submit'), hasLength(1));
    expect((await operation())['state'], 'unknown');
    expect((await outbox.draft(draft.key))!.body, _text);
    await settle();
    expect(methods().where((m) => m == 'prompt.submit'), hasLength(1));
  });

  test('timeout après écriture : unknown, sans renvoi', () async {
    await start();
    h.transport.rpc = (method, params) =>
        method == 'prompt.submit' ? null : _happy(method, params);
    await outbox.send(draft.key);
    expect(outbox.status(draft.key).state, OperationState.unknown);
    expect(methods().where((m) => m == 'prompt.submit'), hasLength(1));
  });

  for (final code in [4009, 4090, 5035]) {
    test('refus $code : failed, brouillon intact', () async {
      await start();
      h.transport.rpc = (method, params) =>
          method == 'prompt.submit' ? RpcFail(code) : _happy(method, params);
      await outbox.send(draft.key);
      final status = outbox.status(draft.key);
      expect(status.state, OperationState.failed);
      expect(status.errorCode, 'rpc.$code');
      expect(status.retryable, isTrue);
      expect((await outbox.draft(draft.key))!.body, _text);
    });
  }

  test('4001 : session.resume puis un seul nouveau submit', () async {
    await start();
    var submits = 0;
    h.transport.rpc = (method, params) {
      if (method == 'prompt.submit' && ++submits == 1) {
        return const RpcFail(4001);
      }
      return _happy(method, params);
    };
    await outbox.send(draft.key);
    expect(methods(), [
      'session.create',
      'prompt.submit',
      'session.resume',
      'prompt.submit',
    ]);
    expect(h.transport.frames[3]['params'], {
      'session_id': '<SYNTHETIC_STORED_SESSION>',
      'profile': 'default',
    });
    expect(h.transport.frames.last['params']['session_id'], 'e5f6a7b8');
    expect(outbox.status(draft.key).state, OperationState.accepted);
  });

  test('4001 persistant : failed après un seul nouvel essai', () async {
    await start();
    h.transport.rpc = (method, params) => method == 'prompt.submit'
        ? const RpcFail(4001)
        : _happy(method, params);
    await outbox.send(draft.key);
    expect(methods().where((m) => m == 'prompt.submit'), hasLength(2));
    expect(outbox.status(draft.key).state, OperationState.failed);
    expect(outbox.status(draft.key).errorCode, 'rpc.4001');
  });

  test("saisie pendant l'envoi : la plus récente est conservée", () async {
    await start();
    h.transport.rpc = (method, params) =>
        method == 'prompt.submit' ? null : _happy(method, params);
    final sending = outbox.send(draft.key);
    await until(() => outbox.status(draft.key).state == OperationState.sending);
    expect(outbox.status(draft.key).state, OperationState.sending);
    await outbox.saveText(draft.key, "suite écrite pendant l'envoi");
    final submit = h.transport.frames.last;
    expect(submit['params']['text'], _text);
    h.transport.sockets.single.controller.add({
      'jsonrpc': '2.0',
      'id': submit['id'],
      'result': _result('prompt-submit'),
    });
    await sending;
    expect(outbox.status(draft.key).state, OperationState.accepted);
    expect(
      (await outbox.draft(draft.key))!.body,
      "suite écrite pendant l'envoi",
    );
  });

  test("un tour en cours bloque un nouvel envoi jusqu'à sa fin", () async {
    await start();
    h.transport.rpc = _happy;
    await outbox.send(draft.key);
    final socket = h.transport.sockets.single.controller;
    socket.add(fixture('message-start'));
    await settle();
    expect(outbox.status(draft.key).turnActive, isTrue);
    await outbox.saveText(draft.key, 'deuxième');
    final before = h.transport.frames.length;
    await outbox.send(draft.key);
    expect(h.transport.frames.length, before);
    socket.add(fixture('message-complete'));
    await settle();
    expect(outbox.status(draft.key).turnActive, isFalse);
    await outbox.send(draft.key);
    expect(methods().where((m) => m == 'prompt.submit'), hasLength(2));
    // Même session : pas de seconde création.
    expect(methods().where((m) => m == 'session.create'), hasLength(1));
  });

  test('dialecte canonique : aucun appel, capacité absente', () async {
    await start(ready: fixture('gateway-ready'));
    h.transport.rpc = _happy;
    expect(
      h.repository.snapshot.capabilities
          .singleWhere((c) => c.name == 'conversation')
          .state,
      CapabilityState.absent,
    );
    await outbox.send(draft.key);
    expect(outbox.status(draft.key).errorCode, 'send.unavailable');
    expect(methods(), isEmpty);
    expect(await database.query('outbox_operations'), isEmpty);
  });

  test('connexion absente : failed retryable, aucune trame', () async {
    await start(connect: false);
    await outbox.send(draft.key);
    expect(outbox.status(draft.key).state, OperationState.failed);
    expect(outbox.status(draft.key).retryable, isTrue);
    expect(h.transport.frames, isEmpty);
    expect((await outbox.draft(draft.key))!.body, _text);
  });

  test(
    "échec de session.create : failed, la clé d'idempotence reste",
    () async {
      await start();
      h.transport.rpc = (method, params) =>
          method == 'session.create' ? const RpcDrop() : null;
      await outbox.send(draft.key);
      expect(outbox.status(draft.key).state, OperationState.failed);
      expect(methods(), ['session.create']);
      expect(
        (await database.query('outbox_drafts')).single['idempotency_key'],
        'default/${draft.key.value}',
      );
    },
  );

  Future<void> reconnect() async {
    await h.transport.sockets.last.drop();
    await until(() => h.delays.isNotEmpty);
    h.delays.last.complete();
    await until(
      () =>
          h.transport.sockets.length == 2 &&
          h.repository.snapshot.link == LinkState.connected,
    );
  }

  test(
    'reconnexion : tour terminé, session.resume, ancienne génération ignorée',
    () async {
      await start();
      h.transport.rpc = _happy;
      await outbox.send(draft.key);
      h.transport.sockets.single.controller.add(fixture('message-start'));
      await until(() => outbox.status(draft.key).turnActive);
      expect(outbox.status(draft.key).turnActive, isTrue);
      await reconnect();
      expect(outbox.status(draft.key).turnActive, isFalse);
      // Un événement du runtime périmé ne rouvre pas le tour.
      h.transport.sockets.last.controller.add(fixture('message-start'));
      await settle();
      expect(outbox.status(draft.key).turnActive, isFalse);
      await outbox.saveText(draft.key, 'suite');
      await outbox.send(draft.key);
      expect(methods().where((m) => m == 'session.create'), hasLength(1));
      expect(methods().where((m) => m == 'session.resume'), hasLength(1));
      expect(h.transport.frames.last['params']['session_id'], 'e5f6a7b8');
    },
  );

  test('session reprise en plein tour : aucun submit, tour actif', () async {
    await start();
    h.transport.rpc = _happy;
    await outbox.send(draft.key);
    await reconnect();
    h.transport.rpc = (method, params) => method == 'session.resume'
        ? {..._result('session-resume'), 'running': true}
        : _happy(method, params);
    await outbox.saveText(draft.key, 'suite');
    await outbox.send(draft.key);
    expect(methods().where((m) => m == 'prompt.submit'), hasLength(1));
    expect(outbox.status(draft.key).turnActive, isTrue);
    expect(outbox.status(draft.key).errorCode, 'send.turn_active');
    expect((await outbox.draft(draft.key))!.body, 'suite');
  });

  test("l'événement error termine le tour", () async {
    await start();
    h.transport.rpc = _happy;
    await outbox.send(draft.key);
    final socket = h.transport.sockets.single.controller;
    socket.add(fixture('message-start'));
    await until(() => outbox.status(draft.key).turnActive);
    socket.add({
      'jsonrpc': '2.0',
      'method': 'event',
      'params': {
        'type': 'error',
        'session_id': 'a1b2c3d4',
        'payload': {'message': 'SYNTHETIC'},
      },
    });
    await until(() => !outbox.status(draft.key).turnActive);
    expect(outbox.status(draft.key).turnActive, isFalse);
  });

  test('statut de submit inconnu : unknown, brouillon gardé', () async {
    await start();
    h.transport.rpc = (method, params) => method == 'prompt.submit'
        ? {'status': 'mystère'}
        : _happy(method, params);
    await outbox.send(draft.key);
    expect(outbox.status(draft.key).state, OperationState.unknown);
    expect((await outbox.draft(draft.key))!.body, _text);
  });

  test(
    'session.create sans stored_session_id : failed, aucun submit',
    () async {
      await start();
      h.transport.rpc = (method, params) => method == 'session.create'
          ? {'session_id': 'a1b2c3d4'}
          : _happy(method, params);
      await outbox.send(draft.key);
      expect(outbox.status(draft.key).state, OperationState.failed);
      expect(methods(), ['session.create']);
    },
  );

  test('réponse queued : acceptée', () async {
    await start();
    h.transport.rpc = (method, params) => method == 'prompt.submit'
        ? {'status': 'queued'}
        : _happy(method, params);
    await outbox.send(draft.key);
    expect(outbox.status(draft.key).state, OperationState.accepted);
    expect((await operation())['user_row_id'], isNull);
  });

  test('écriture de prompt.submit en erreur : unknown, aucun renvoi', () async {
    await start();
    h.transport.rpc = _happy;
    h.transport.throwOnMethod = 'prompt.submit';
    await outbox.send(draft.key);
    expect(outbox.status(draft.key).state, OperationState.unknown);
    expect(methods().where((m) => m == 'prompt.submit'), hasLength(1));
    expect((await outbox.draft(draft.key))!.body, _text);
  });

  test('relance après interruption : état persisté visible', () async {
    await start();
    Future<void> insert(String key, String state, [String? code]) =>
        database.insert('outbox_operations', {
          'operation_key': key,
          'draft_key': draft.key.value,
          'connection_key': 'c-1',
          'profile_key': 'default',
          'body': _text,
          'revision': 1,
          'state': state,
          'error_code': code,
          'created_at': '2026-10-21T0${key.length}:00:00Z',
          'updated_at': 'x',
        });
    await insert('a', 'sending');
    final relaunched = OutboxRepository(database, gateway: h.repository);
    addTearDown(relaunched.dispose);
    await relaunched.draft(draft.key);
    expect(relaunched.status(draft.key).state, OperationState.unknown);
    expect(relaunched.status(draft.key).errorCode, 'send.unknown');
    expect((await operation())['state'], 'unknown');
    // Dernier état « failed » : affiché tel quel.
    await insert('bb', 'failed', 'rpc.4009');
    final again = OutboxRepository(database, gateway: h.repository);
    addTearDown(again.dispose);
    await again.draft(draft.key);
    expect(again.status(draft.key).errorCode, 'rpc.4009');
    expect(again.status(draft.key).retryable, isTrue);
  });

  test('migration réelle v3 vers v7 : données et index « nouveau »', () async {
    directory = await Directory.systemTemp.createTemp('hermes-v3-');
    final path = '${directory.path}/hermes.sqlite';
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE connection_entries (connection_key TEXT PRIMARY KEY, '
            'origin TEXT NOT NULL, selected_profile TEXT)',
          );
          await db.execute(
            'CREATE TABLE outbox_drafts (draft_key TEXT PRIMARY KEY, '
            'connection_key TEXT NOT NULL, profile_key TEXT NOT NULL, '
            'body TEXT NOT NULL, updated_at TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE UNIQUE INDEX outbox_drafts_target '
            'ON outbox_drafts (connection_key, profile_key)',
          );
          await db.insert('outbox_drafts', {
            'draft_key': 'd-1',
            'connection_key': 'c-1',
            'profile_key': 'p',
            'body': 'gardé',
            'updated_at': '2026-10-21T00:00:00.000Z',
          });
        },
      ),
    );
    await old.close();
    database = await openConnectionDatabase(
      factory: databaseFactoryFfi,
      path: path,
    );
    h = Harness();
    outbox = OutboxRepository(database, gateway: h.repository);
    expect(await database.getVersion(), connectionMigrations.length);
    final row = (await database.query('outbox_drafts')).single;
    expect(row['body'], 'gardé');
    expect(row['revision'], 0);
    expect(row['stored_session_id'], isNull);
    expect(await database.query('outbox_operations'), isEmpty);
    // Un second brouillon « nouveau » du même couple est refusé ; avec session, non.
    final extra = {
      'connection_key': 'c-1',
      'profile_key': 'p',
      'body': '',
      'updated_at': 'x',
    };
    await expectLater(
      database.insert('outbox_drafts', {...extra, 'draft_key': 'd-2'}),
      throwsA(isA<DatabaseException>()),
    );
    await database.update(
      'outbox_drafts',
      {'stored_session_id': 's'},
      where: 'draft_key = ?',
      whereArgs: ['d-1'],
    );
    await database.insert('outbox_drafts', {...extra, 'draft_key': 'd-2'});
    // L'accueil ne rend que des brouillons sans session, même si l'un d'eux
    // porte un texte : celui-ci se retrouve par l'historique.
    await outbox.saveText(const DraftKey('d-1'), 'suite');
    final reopened = await outbox.openNewDraft(
      const ConnectionKey('c-1'),
      const ProfileKey('p'),
    );
    expect(reopened.key, const DraftKey('d-2'));
    expect(reopened.storedSessionId, isNull);
  });
}
