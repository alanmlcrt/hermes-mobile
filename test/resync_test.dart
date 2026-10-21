import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'contracts_test.dart' show contract;
import 'support/connection_fakes.dart';

Map<String, dynamic> _result(String name) =>
    Map<String, dynamic>.from(fixture(name)['result'] as Map);

const _text = 'Bonjour 🚀';
const _stored = '<SYNTHETIC_STORED_SESSION>';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database database;
  late Harness h;
  late OutboxRepository outbox;
  late ConversationRepository conversation;
  late Draft draft;
  late TimelineKey key;
  var started = false;
  const connection = ConnectionKey('c-1');
  const profile = ProfileKey('default');
  final mapping = EventMapping(contract('event-mapping'));

  /// Réponses scriptées par méthode ; le reste suit le déroulé nominal.
  final overrides = <String, Object?>{};

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await settle();
    }
  }

  Object? script(String method, Map<String, dynamic> params) {
    if (overrides.containsKey(method)) return overrides[method];
    return switch (method) {
      'session.create' => _result('session-create'),
      // Même runtime que la création : la numérotation des événements tient.
      'session.resume' => {
        ..._result('session-resume'),
        'session_id': 'a1b2c3d4',
      },
      'prompt.submit' => _result('prompt-submit'),
      _ => null,
    };
  }

  Future<void> start() async {
    started = true;
    overrides.clear();
    directory = await Directory.systemTemp.createTemp('hermes-resync-');
    database = await openConnectionDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/hermes.sqlite',
    );
    h = Harness();
    await h.connect();
    await settle();
    conversation = ConversationRepository(
      database,
      gateway: h.repository,
      mapping: mapping,
      timeout: const Duration(seconds: 1),
    );
    outbox = OutboxRepository(
      database,
      gateway: h.repository,
      timeout: const Duration(seconds: 1),
      conversation: conversation,
    );
    draft = await outbox.openNewDraft(connection, profile);
    await outbox.saveText(draft.key, _text);
    key = const TimelineKey(connection, profile, _stored);
    h.transport.rpc = script;
  }

  tearDown(() async {
    if (!started) return;
    started = false;
    await outbox.dispose();
    await conversation.dispose();
    await h.repository.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  void emit(String type, Map<String, dynamic> payload, int seq) {
    h.transport.sockets.last.controller.add({
      'jsonrpc': '2.0',
      'method': 'event',
      'params': {
        'type': type,
        'session_id': 'a1b2c3d4',
        'payload': payload,
        'seq': seq,
      },
    });
  }

  /// Coupe la socket puis laisse la reconnexion planifiée aboutir.
  Future<void> reconnect() async {
    final sockets = h.transport.sockets.length;
    final delays = h.delays.length;
    await h.transport.sockets.last.drop();
    await until(() => h.delays.length > delays);
    h.delays.last.complete();
    await until(
      () =>
          h.transport.sockets.length == sockets + 1 &&
          h.repository.snapshot.link == LinkState.connected,
    );
  }

  List<String> methods() => [
    for (final f in h.transport.frames)
      if (f['id'] != 'capabilities') f['method'] as String,
  ];
  int count(String method) => methods().where((m) => m == method).length;
  Map<String, dynamic> lastParams(String method) =>
      h.transport.frames.lastWhere((f) => f['method'] == method)['params']
          as Map<String, dynamic>;

  TimelineProjection timeline() => conversation.projection(key);
  Future<Map<String, Object?>> operation() async =>
      (await database.query('outbox_operations')).last;

  /// Tour accepté (ligne 42), début de réponse reçu jusqu'au `seq` 2.
  Future<void> acceptedTurn() async {
    await outbox.send(draft.key);
    emit('message.start', {}, 1);
    emit('message.delta', {'text': 'Voici '}, 2);
    await until(() => timeline().seq == 2);
  }

  test('coupure après acceptation, même epoch : events.since rejoue la fin, '
      'doublon écarté, aucun renvoi', () async {
    await start();
    await acceptedTurn();
    overrides['session.events.since'] = _result('session-events-since');
    await reconnect();
    await until(() => timeline().workState == WorkState.succeeded);
    final p = timeline();
    expect([for (final i in p.items) i.runtimeType], [UserItem, ResponseItem]);
    expect((p.items.last as ResponseItem).text, 'SYNTHETIC');
    expect(p.turns, 1);
    expect(p.seq, 3);
    expect(lastParams('session.events.since'), {
      'session_id': 'a1b2c3d4',
      'last_seen': 2,
    });
    expect(count('session.history'), 0);
    expect(count('prompt.submit'), 1);
    final row = (await database.query('conversation_timelines')).single;
    expect(row['seq'], 3);
    expect(row['replay_epoch'], 'synthetic-epoch');
  });

  test('tour toujours en cours : rejeu, fil « en cours », envoi bloqué',
      () async {
    await start();
    await acceptedTurn();
    overrides['session.resume'] = {
      ..._result('session-resume-running'),
      'session_id': 'a1b2c3d4',
    };
    overrides['session.events.since'] = {
      'events': [],
      'latest_seq': 2,
      'truncated': false,
      'count': 0,
      'epoch': 'synthetic-epoch',
      'open_requests': [],
    };
    await reconnect();
    await until(
      () =>
          outbox.status(draft.key).turnActive &&
          timeline().workState == WorkState.running,
    );
    expect(timeline().workState, WorkState.running);
    expect((timeline().items.last as ResponseItem).text, 'Voici ');
    expect(timeline().turns, 1);
    expect(outbox.status(draft.key).turnActive, isTrue);
    await outbox.saveText(draft.key, 'suite');
    await outbox.send(draft.key); // bloqué : rien ne part
    expect(count('prompt.submit'), 1);
    expect((await outbox.draft(draft.key))!.body, 'suite');
  });

  test('tronqué : snapshot par l\'historique, bulle liée par row_id, curseur '
      'sur latest_seq, aucun renvoi', () async {
    await start();
    await acceptedTurn();
    overrides['session.events.since'] = _result('session-events-since-truncated');
    overrides['session.history'] = _result('session-history');
    await reconnect();
    await until(() => timeline().workState == WorkState.succeeded);
    final p = timeline();
    expect([for (final i in p.items) i.runtimeType], [UserItem, ResponseItem]);
    final user = p.items.first as UserItem;
    expect(user.text, _text); // lien local par row_id 42, pas par le texte
    expect(user.userRowId, 42);
    expect((p.items.last as ResponseItem).text, 'SYNTHETIC_ANSWER');
    expect(p.seq, 9);
    expect(p.replayEpoch, 'synthetic-epoch');
    expect(count('prompt.submit'), 1);
  });

  test('trou de seq : snapshot', () async {
    await start();
    await acceptedTurn();
    overrides['session.events.since'] = {
      'events': [
        {'type': 'message.complete', 'payload': {'text': 'X'}, 'seq': 4},
      ],
      'latest_seq': 4,
      'truncated': false,
      'count': 1,
      'epoch': 'synthetic-epoch',
      'open_requests': [],
    };
    overrides['session.history'] = _result('session-history');
    await reconnect();
    await until(() => timeline().workState == WorkState.succeeded);
    expect(count('session.history'), 1);
    expect((timeline().items.last as ResponseItem).text, 'SYNTHETIC_ANSWER');
    expect(timeline().seq, 4);
  });

  test('redémarrage Hermes (autre replay_epoch) : snapshot, curseur vide, '
      'pas de events.since', () async {
    await start();
    await acceptedTurn();
    final ready = jsonDecode(jsonEncode(h.transport.ready)) as Map;
    ready['params']['payload']['replay_epoch'] = 'synthetic-epoch-2';
    h.transport.ready = Map<String, dynamic>.from(ready);
    overrides['session.history'] = _result('session-history');
    await reconnect();
    await until(() => timeline().workState == WorkState.succeeded);
    expect(timeline().seq, isNull); // curseur non relu : vide
    expect(timeline().replayEpoch, 'synthetic-epoch-2');
    expect(count('prompt.submit'), 1);
  });

  test('relance : fil rouvert, snapshot avec le partiel assistant en cours',
      () async {
    await start();
    await acceptedTurn();
    // Nouvelle exécution de l'app : projections en mémoire perdues.
    await outbox.dispose();
    await conversation.dispose();
    conversation = ConversationRepository(
      database,
      gateway: h.repository,
      mapping: mapping,
      timeout: const Duration(seconds: 1),
    );
    outbox = OutboxRepository(
      database,
      gateway: h.repository,
      timeout: const Duration(seconds: 1),
      conversation: conversation,
    );
    overrides['session.resume'] = _result('session-resume-running');
    overrides['session.history'] = {
      'count': 1,
      'messages': [
        {'role': 'user', 'text': _text, 'row_id': 42, 'display_kind': 'text'},
      ],
    };
    await conversation.load(key);
    await until(() => timeline().workState == WorkState.running);
    await settle();
    final p = timeline();
    expect([for (final i in p.items) i.runtimeType], [UserItem, ResponseItem]);
    expect((p.items.last as ResponseItem).text, 'SYNTHETIC_PARTIAL');
    expect(count('prompt.submit'), 1);
    // Les fragments suivants complètent le même tour.
    h.transport.sockets.last.controller.add({
      'jsonrpc': '2.0',
      'method': 'event',
      'params': {
        'type': 'message.delta',
        'session_id': 'e5f6a7b8',
        'payload': {'text': ' suite'},
        'seq': 5,
      },
    });
    await until(() => timeline().seq == 5);
    expect((timeline().items.last as ResponseItem).text, 'SYNTHETIC_PARTIAL suite');
    expect(timeline().turns, 1);
  });

  Map<String, dynamic> sinceBody(
    List<Map<String, Object?>> events,
    int latest, {
    String epoch = 'synthetic-epoch',
  }) => {
    'events': events,
    'latest_seq': latest,
    'truncated': false,
    'count': events.length,
    'epoch': epoch,
    'open_requests': [],
  };

  Future<void> expectSnapshot(String why) async {
    await acceptedTurn();
    overrides['session.history'] = _result('session-history');
    await reconnect();
    await until(() => timeline().workState == WorkState.succeeded);
    expect(count('session.history'), 1, reason: why);
    expect((timeline().items.last as ResponseItem).text, 'SYNTHETIC_ANSWER');
    expect(count('prompt.submit'), 1);
  }

  test('events.since en erreur : snapshot', () async {
    await start();
    overrides['session.events.since'] = const RpcFail(5000);
    await expectSnapshot('rpc');
  });

  test('epoch du corps de events.since différent : snapshot', () async {
    await start();
    overrides['session.events.since'] = sinceBody([], 2, epoch: 'autre');
    await expectSnapshot('epoch');
  });

  test('latest_seq en avance sur les événements rejoués : snapshot', () async {
    await start();
    overrides['session.events.since'] = sinceBody([], 5);
    await expectSnapshot('latest');
  });

  test('running:false alors que le tour était en cours : snapshot', () async {
    await start();
    overrides['session.events.since'] = sinceBody([], 2);
    await expectSnapshot('inflight');
  });

  test('deux bulles locales sans ligne : appariées par position, texte local '
      'gardé ; historique finissant par une ligne utilisateur', () async {
    await start();
    overrides['prompt.submit'] = {'status': 'streaming'};
    await outbox.send(draft.key);
    await outbox.saveText(draft.key, 'seconde');
    await outbox.send(draft.key);
    expect(count('prompt.submit'), 2);
    overrides['session.history'] = {
      'count': 3,
      'messages': [
        {'role': 'user', 'text': 'srv1', 'row_id': 50},
        {'role': 'assistant', 'text': 'r', 'row_id': 51},
        {'role': 'user', 'text': 'srv2', 'row_id': 52},
        {
          'role': 'assistant',
          'text': 'outil',
          'row_id': 53,
          'display_kind': 'tool',
        },
      ],
    };
    await reconnect();
    await until(() => timeline().items.length == 3);
    final items = timeline().items;
    expect((items[0] as UserItem).text, _text);
    expect((items[0] as UserItem).userRowId, 50);
    expect((items[2] as UserItem).text, 'seconde');
    expect((items[2] as UserItem).userRowId, 52);
    expect(timeline().workState, WorkState.unknown);
  });

  test('reprise en échec : resumeFailed signalé par un changement, effacé au succès',
      () async {
    await start();
    await outbox.send(draft.key);
    final changes = <TimelineKey>[];
    final sub = conversation.changes.listen(changes.add);
    addTearDown(sub.cancel);
    overrides['session.resume'] = const RpcFail(5000);
    await conversation.resync(key);
    expect(conversation.resumeFailed(key), isTrue);
    expect(changes, contains(key));
    overrides.remove('session.resume');
    overrides['session.history'] = _result('session-history');
    changes.clear();
    await conversation.resync(key);
    expect(conversation.resumeFailed(key), isFalse);
    expect(changes, contains(key));
  });

  test('migration v6 : colonne row_watermark ajoutée', () async {
    await start();
    final columns = await database.rawQuery(
      'PRAGMA table_info(outbox_operations)',
    );
    expect(columns.map((c) => c['name']), contains('row_watermark'));
  });

  group('opération incertaine', () {
    Future<void> uncertainSend({int submits = 1}) async {
      // La trame part puis la socket tombe : résultat inconnu.
      overrides['prompt.submit'] = const RpcDrop();
      await outbox.send(draft.key);
      expect(outbox.status(draft.key).state, OperationState.unknown);
      expect((await operation())['row_watermark'], isNotNull);
      expect(count('prompt.submit'), submits);
    }

    test('reçue : une seule ligne libre au-delà du repère → acceptée, texte du '
        'brouillon conservé, jamais de renvoi', () async {
      await start();
      await uncertainSend();
      await until(() => h.delays.isNotEmpty);
      h.delays.last.complete();
      overrides.remove('prompt.submit');
      overrides['session.history'] = {
        'count': 2,
        'messages': [
          {'role': 'user', 'text': _text, 'row_id': 43, 'display_kind': 'text'},
          {'role': 'assistant', 'text': 'ok', 'row_id': 44},
        ],
      };
      await until(
        () => outbox.status(draft.key).state == OperationState.accepted,
      );
      final op = await operation();
      expect(op['state'], 'accepted');
      expect(op['user_row_id'], 43);
      expect((await outbox.draft(draft.key))!.body, _text);
      expect(count('prompt.submit'), 1);
      expect(timeline().items.whereType<UserItem>().single.userRowId, 43);
    });

    test('non reçue : aucune nouvelle ligne, rien en cours → échec certain, '
        'brouillon intact, renvoi manuel permis', () async {
      await start();
      await outbox.send(draft.key); // ligne 42 déjà connue
      await outbox.saveText(draft.key, 'seconde');
      await uncertainSend(submits: 2);
      await until(() => h.delays.isNotEmpty);
      h.delays.last.complete();
      overrides.remove('prompt.submit');
      overrides['session.history'] = {
        'count': 1,
        'messages': [
          {'role': 'user', 'text': 'seconde', 'row_id': 42}, // même texte, ligne ancienne
        ],
      };
      await until(() => outbox.status(draft.key).state == OperationState.failed);
      final status = outbox.status(draft.key);
      expect(status.errorCode, 'send.not_received');
      expect(status.retryable, isTrue);
      expect((await operation())['state'], 'failed');
      expect((await outbox.draft(draft.key))!.body, 'seconde');
      expect(count('prompt.submit'), 2);
    });

    test('indémontrable : historique indisponible → reste unknown', () async {
      await start();
      await uncertainSend();
      await until(() => h.delays.isNotEmpty);
      h.delays.last.complete();
      overrides.remove('prompt.submit');
      overrides['session.history'] = const RpcFail(5070);
      await until(() => count('session.history') == 1);
      await settle();
      expect(outbox.status(draft.key).state, OperationState.unknown);
      expect((await operation())['state'], 'unknown');
      expect((await outbox.draft(draft.key))!.body, _text);
      expect(count('prompt.submit'), 1);
    });

    test('tour encore en cours : reste unknown même sans ligne', () async {
      await start();
      await uncertainSend();
      await until(() => h.delays.isNotEmpty);
      h.delays.last.complete();
      overrides.remove('prompt.submit');
      overrides['session.resume'] = {
        ..._result('session-resume-running'),
        'session_id': 'a1b2c3d4',
      };
      overrides['session.history'] = {'count': 0, 'messages': []};
      await until(() => count('session.history') == 1);
      await settle();
      expect((await operation())['state'], 'unknown');
      expect((await outbox.draft(draft.key))!.body, _text);
    });

    Future<void> reconnectAfterDrop() async {
      final sockets = h.transport.sockets.length;
      await until(() => h.delays.isNotEmpty);
      h.delays.last.complete();
      await until(
        () =>
            h.transport.sockets.length > sockets &&
            h.repository.snapshot.link == LinkState.connected,
      );
    }

    test('deux opérations incertaines, une seule ligne neuve : les deux restent '
        'unknown', () async {
      await start();
      await uncertainSend();
      overrides.remove('prompt.submit');
      overrides['session.history'] = const RpcFail(5070);
      await reconnectAfterDrop();
      await until(() => count('session.history') == 1);
      await settle();
      overrides['prompt.submit'] = const RpcDrop();
      final delays = h.delays.length;
      await outbox.send(draft.key);
      expect(count('prompt.submit'), 2);
      overrides.remove('prompt.submit');
      overrides['session.history'] = {
        'count': 1,
        'messages': [
          {'role': 'user', 'text': _text, 'row_id': 43},
        ],
      };
      await until(() => h.delays.length > delays);
      h.delays.last.complete();
      await until(() => count('session.history') == 2);
      await settle();
      await settle();
      final states = [
        for (final o in await database.query('outbox_operations')) o['state'],
      ];
      expect(states, ['unknown', 'unknown']);
      expect((await outbox.draft(draft.key))!.body, _text);
    });

    test('repère absent : reste unknown, jamais échec', () async {
      await start();
      await uncertainSend();
      await database.update('outbox_operations', {'row_watermark': null});
      overrides.remove('prompt.submit');
      overrides['session.history'] = {'count': 0, 'messages': []};
      await reconnectAfterDrop();
      await until(() => count('session.history') == 1);
      await settle();
      expect((await operation())['state'], 'unknown');
      expect(outbox.status(draft.key).state, OperationState.unknown);
    });

    test('file d\'attente non vide sans ligne : reste unknown', () async {
      await start();
      await uncertainSend();
      overrides.remove('prompt.submit');
      overrides['session.resume'] = {
        ..._result('session-resume'),
        'session_id': 'a1b2c3d4',
        'queued': [
          {'text': 'x'},
        ],
      };
      overrides['session.history'] = {'count': 0, 'messages': []};
      await reconnectAfterDrop();
      await until(() => count('session.history') == 1);
      await settle();
      expect((await operation())['state'], 'unknown');
    });

    test('ligne étrangère en plus : deux candidates → reste unknown, texte '
        'conservé', () async {
      await start();
      await uncertainSend();
      overrides.remove('prompt.submit');
      overrides['session.history'] = {
        'count': 2,
        'messages': [
          {'role': 'user', 'text': 'autre client', 'row_id': 43},
          {'role': 'user', 'text': _text, 'row_id': 44},
        ],
      };
      await reconnectAfterDrop();
      await until(() => count('session.history') == 1);
      await settle();
      expect((await operation())['state'], 'unknown');
      expect((await outbox.draft(draft.key))!.body, _text);
    });
  });
}
