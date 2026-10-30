import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/intervention_repository.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/connection_gateway.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/question_card.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'contracts_test.dart' show contract;
import 'support/connection_fakes.dart';

Map<String, dynamic> _result(String name) =>
    Map<String, dynamic>.from(fixture(name)['result'] as Map);

const _stored = '<SYNTHETIC_STORED_SESSION>';
const _id = 'srq-000000000001';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database database;
  late Harness h;
  late OutboxRepository outbox;
  late ConversationRepository conversation;
  late InterventionRepository interventions;
  late Draft draft;
  late TimelineKey key;
  var started = false;
  late ConnectionKey connection;
  const profile = ProfileKey('default');
  final mapping = EventMapping(contract('event-mapping'));
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
    directory = await Directory.systemTemp.createTemp('hermes-intervention-');
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
    interventions = InterventionRepository(
      database,
      gateway: h.repository,
      conversation: conversation,
    );
    await interventions.recovered;
    connection = h.repository.snapshot.connection!.key;
    draft = await outbox.openNewDraft(connection, profile);
    await outbox.saveText(draft.key, 'Bonjour');
    key = TimelineKey(connection, profile, _stored);
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
    h.transport.push({
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

  TimelineProjection timeline() => conversation.projection(key);
  QuestionItem? question() =>
      timeline().items.whereType<QuestionItem>().firstOrNull;
  Future<String?> stored() async {
    final rows = await database.query('intervention_answers');
    return rows.isEmpty ? null : rows.single['state'] as String;
  }

  /// Tour accepté puis question `clarify` reçue en direct (fixture).
  Future<void> asked() async {
    await outbox.send(draft.key);
    emit('message.start', {}, 1);
    await until(() => timeline().seq == 1);
    h.transport.push(fixture('clarify-request'));
    await until(() => question() != null);
  }

  /// Reprise sur une nouvelle socket, rejeu sûr, `open_requests` imposé.
  Future<void> reconnectWith(
    List<Object?>? open, {
    bool resumeOpen = true,
  }) async {
    overrides['session.resume'] = {
      ..._result('session-resume'),
      'session_id': 'a1b2c3d4',
      'running': true,
      if (resumeOpen && open != null) 'open_requests': open,
    };
    overrides['session.events.since'] = {
      'events': [],
      'latest_seq': 1,
      'truncated': false,
      'count': 0,
      'epoch': 'synthetic-epoch',
      'open_requests': ?open,
    };
    int resumes() =>
        h.transport.frames.where((f) => f['method'] == 'session.resume').length;
    final before = resumes();
    await reconnect();
    await until(() => resumes() > before);
    await until(() => !conversation.resyncing(key));
    await settle();
  }

  Map<String, Object?> openEntry() {
    final request = fixture('clarify-request');
    return {
      'id': request['id'],
      'method': request['method'],
      'params': request['params'],
    };
  }

  test('une seule déclaration client.capabilities par socket, '
      'questions reconnues', () async {
    await start();
    final declared = h.transport.frames
        .where((f) => f['method'] == 'client.capabilities')
        .toList();
    expect(declared, hasLength(1));
    expect(declared.single['params'], {'server_requests': true});
    // Un second gateway.ready sur la même socket ne redéclare rien.
    h.transport.push(h.transport.ready);
    await settle();
    expect(
      h.transport.frames.where((f) => f['method'] == 'client.capabilities'),
      hasLength(1),
    );
    final caps = {
      for (final c in h.repository.snapshot.capabilities) c.name: c.state,
    };
    expect(caps['server_requests'], CapabilityState.present);
    expect(caps['clarify'], CapabilityState.present);
  });

  test('question en direct : carte ouverte, texte et choix tels qu’émis, '
      'attente de réponse', () async {
    await start();
    await asked();
    final q = question()!;
    expect(q.requestId, _id);
    expect(q.state, QuestionState.open);
    expect(q.questions.single.text, 'Quelle est ta couleur préférée ?');
    expect(q.questions.single.choices, ['rouge (Recommended)', 'bleu']);
    expect(q.questions.single.multiSelect, isFalse);
    expect(q.turn, timeline().turns);
    expect(timeline().workState, WorkState.waitingInput);
    // Persistée avec la projection.
    final row = (await database.query('conversation_timelines')).single;
    final restored = TimelineProjection.fromJson(
      jsonDecode(row['projection'] as String) as Map<String, Object?>,
    );
    final again = restored.items.whereType<QuestionItem>().single;
    expect(again.requestId, _id);
    expect(again.questions.single.choices, q.questions.single.choices);
    expect(restored.workState, WorkState.waitingInput);
    // Aucune réponse n'est partie d'elle-même.
    expect(h.transport.responses, isEmpty);
  });

  test('réponse : ligne en base avant la trame, trame unique conforme, '
      'prise en compte au tool.complete du clarify', () async {
    await start();
    await asked();
    Future<List<Map<String, Object?>>>? atSend;
    h.transport.onFrame = (frame) {
      if (frame['method'] == null) {
        atSend = database.query('intervention_answers');
      }
    };
    await interventions.answer(key, _id, {'q0': ' bleu '});
    final seen = await atSend!;
    expect(seen.single['state'], 'sending');
    expect(jsonDecode(seen.single['answers'] as String), {'q0': 'bleu'});
    final expected = fixture('clarify-answer');
    expect(h.transport.responses, [
      {'jsonrpc': '2.0', 'id': expected['id'], 'result': expected['result']},
    ]);
    await until(() => question()!.state == QuestionState.sent);
    expect(await stored(), 'sent');
    expect(timeline().workState, WorkState.waitingInput);
    emit('tool.start', {'tool_id': 'C', 'name': 'clarify'}, 2);
    emit('tool.complete', {'tool_id': 'C', 'name': 'clarify'}, 3);
    await until(() => question()!.state == QuestionState.confirmed);
    expect(timeline().workState, WorkState.running);
    await settle();
    expect(await stored(), 'confirmed');
    // Une seconde réponse au même id n'est jamais envoyée.
    await expectLater(
      interventions.answer(key, _id, {'q0': 'rouge'}),
      throwsA(isA<AppError>()),
    );
    expect(h.transport.responses, hasLength(1));
  });

  test('écriture socket impossible : issue inconnue, aucun renvoi', () async {
    await start();
    await asked();
    h.transport.throwOnResponse = true;
    await interventions.answer(key, _id, {'q0': 'bleu'});
    await until(() => question()!.state == QuestionState.unknown);
    expect(await stored(), 'unknown');
    h.transport.throwOnResponse = false;
    await expectLater(
      interventions.answer(key, _id, {'q0': 'bleu'}),
      throwsA(isA<AppError>()),
    );
    expect(h.transport.responses, hasLength(1));
  });

  test('réponse vide ou hors connexion : rien d’écrit ni d’envoyé', () async {
    await start();
    await asked();
    await expectLater(
      interventions.answer(key, _id, {'q0': '  '}),
      throwsA(isA<AppError>().having((e) => e.code, 'code', 'question.empty')),
    );
    await h.transport.sockets.last.drop();
    await until(() => h.repository.snapshot.link != LinkState.connected);
    await expectLater(
      interventions.answer(key, _id, {'q0': 'bleu'}),
      throwsA(
        isA<AppError>().having((e) => e.code, 'code', 'transport.offline'),
      ),
    );
    expect(await stored(), isNull);
    expect(h.transport.responses, isEmpty);
  });

  test('choix multiple : choix cochés joints par « , », texte libre en '
      'dernier ; choix unique : le texte prime', () {
    const multi = ClarifyQuestion(
      qid: 'q1',
      text: 'Formats ?',
      choices: ['PDF', 'Markdown', 'HTML'],
      multiSelect: true,
    );
    expect(
      QuestionCard.compose(multi, {'HTML', 'PDF'}, ' EPUB '),
      'PDF, HTML, EPUB',
    );
    expect(QuestionCard.compose(multi, {}, ''), '');
    const single = ClarifyQuestion(
      qid: 'q0',
      text: 'Couleur ?',
      choices: ['rouge (Recommended)', 'bleu'],
    );
    expect(
      QuestionCard.compose(single, {'rouge (Recommended)'}, ''),
      'rouge (Recommended)',
    );
    expect(QuestionCard.compose(single, {'bleu'}, 'vert'), 'vert');
  });

  test(
    'request.cancel : expirée (timeout) ou annulée, plus de saisie',
    () async {
      await start();
      await asked();
      h.transport.push(fixture('request-cancel'));
      await until(() => question()!.state == QuestionState.expired);
      expect(timeline().workState, WorkState.running);
      await expectLater(
        interventions.answer(key, _id, {'q0': 'bleu'}),
        throwsA(isA<AppError>()),
      );
      // Une autre question annulée par l'utilisateur ailleurs.
      final other = fixture('clarify-request');
      other['id'] = 'srq-000000000009';
      h.transport.push(other);
      await until(() => timeline().items.whereType<QuestionItem>().length == 2);
      expect(timeline().workState, WorkState.waitingInput);
      emit('request.cancel', {
        'id': 'srq-000000000009',
        'method': 'clarify',
        'reason': 'user',
      }, 2);
      await until(
        () =>
            timeline().items.whereType<QuestionItem>().last.state ==
            QuestionState.cancelled,
      );
      // L'ancienne question close n'est jamais rouverte par un doublon.
      h.transport.push(fixture('clarify-request'));
      await settle();
      expect(question()!.state, QuestionState.expired);
      expect(h.transport.responses, isEmpty);
    },
  );

  test('requête serveur non prise en charge (sudo) : erreur immédiate, rien '
      'dans le fil', () async {
    await start();
    await asked();
    final before = timeline().items.length;
    h.transport.push({
      'jsonrpc': '2.0',
      'id': 'srq-000000000003',
      'method': 'sudo',
      'params': {'session_id': 'a1b2c3d4', 'command': 'apt update'},
    });
    await until(() => h.transport.responses.isNotEmpty);
    final response = h.transport.responses.single;
    expect(response['id'], 'srq-000000000003');
    expect((response['error'] as Map)['code'], -32601);
    expect(response.containsKey('result'), isFalse);
    await settle();
    expect(timeline().items, hasLength(before));
    expect(timeline().items.whereType<ApprovalItem>(), isEmpty);
    expect(timeline().workState, WorkState.waitingInput);
  });

  test('reconnexion, encore ouverte avec réponse locale : rouverte, mention '
      'de non-réception, aucun renvoi', () async {
    await start();
    await asked();
    await interventions.answer(key, _id, {'q0': 'bleu'});
    await until(() => question()!.state == QuestionState.sent);
    await reconnectWith([openEntry()]);
    await until(() => question()!.state == QuestionState.open);
    expect(question()!.previousUnanswered, isTrue);
    expect(timeline().workState, WorkState.waitingInput);
    expect(h.transport.responses, hasLength(1));
    // Alanc peut répondre à nouveau, à la main.
    await interventions.answer(key, _id, {'q0': 'rouge (Recommended)'});
    expect(h.transport.responses, hasLength(2));
    expect((h.transport.responses.last['result'] as Map)['answers'], {
      'q0': 'rouge (Recommended)',
    });
  });

  test(
    'reconnexion, close : carte fermée, réponse locale jamais renvoyée',
    () async {
      await start();
      await asked();
      await interventions.answer(key, _id, {'q0': 'bleu'});
      await until(() => question()!.state == QuestionState.sent);
      await reconnectWith([]);
      await until(() => question()!.state == QuestionState.closed);
      expect(timeline().workState, WorkState.running);
      expect(h.transport.responses, hasLength(1));
      await settle();
      expect(await stored(), 'closed');
    },
  );

  test('reconnexion, question inconnue de la projection avec réponse locale : '
      'ouverte et signalée', () async {
    await start();
    await outbox.send(draft.key);
    emit('message.start', {}, 1);
    await until(() => timeline().seq == 1);
    await database.insert('intervention_answers', {
      'request_id': _id,
      'connection_key': connection.value,
      'profile_key': profile.value,
      'stored_session_id': _stored,
      'answers': '{}',
      'state': 'unknown',
      'created_at': '2026-10-30T00:00:00Z',
    });
    await reconnectWith([openEntry()]);
    await until(() => question() != null);
    expect(question()!.state, QuestionState.open);
    expect(question()!.previousUnanswered, isTrue);
    expect(h.transport.responses, isEmpty);
  });

  test(
    'relance : une réponse en sending devient unknown, jamais renvoyée',
    () async {
      await start();
      await asked();
      await database.insert('intervention_answers', {
        'request_id': _id,
        'connection_key': connection.value,
        'profile_key': profile.value,
        'stored_session_id': _stored,
        'answers': jsonEncode({'q0': 'bleu'}),
        'state': 'sending',
        'created_at': '2026-10-30T00:00:00Z',
      });
      await conversation.markQuestion(key, _id, QuestionState.sending);
      final relaunched = InterventionRepository(
        database,
        gateway: h.repository,
        conversation: conversation,
      );
      await relaunched.recovered;
      expect(await stored(), 'unknown');
      expect(question()!.state, QuestionState.unknown);
      expect(h.transport.responses, isEmpty);
    },
  );

  test(
    'fin de tour : toute question non close est close, registre compris',
    () async {
      await start();
      await asked();
      await interventions.answer(key, _id, {'q0': 'bleu'});
      await until(() => question()!.state == QuestionState.sent);
      final other = fixture('clarify-request');
      other['id'] = 'srq-000000000009';
      h.transport.push(other);
      await until(() => timeline().items.whereType<QuestionItem>().length == 2);
      emit('message.complete', {'status': 'complete', 'text': 'Fini'}, 2);
      await until(() => timeline().workState == WorkState.succeeded);
      expect(timeline().items.whereType<QuestionItem>().map((q) => q.state), [
        QuestionState.closed,
        QuestionState.closed,
      ]);
      await settle();
      expect(await stored(), 'closed');
      expect(h.transport.responses, hasLength(1));
    },
  );

  test('respond hors connexion : rien n’est parti, ligne retirée, carte '
      'rouverte', () async {
    await start();
    await asked();
    final offline = InterventionRepository(
      database,
      gateway: _OfflineRespond(h.repository),
      conversation: conversation,
    );
    await offline.recovered;
    await expectLater(
      offline.answer(key, _id, {'q0': 'bleu'}),
      throwsA(
        isA<AppError>().having((e) => e.code, 'code', 'transport.offline'),
      ),
    );
    expect(await stored(), isNull);
    expect(question()!.state, QuestionState.open);
    expect(h.transport.responses, isEmpty);
    // La carte accepte encore une réponse.
    await interventions.answer(key, _id, {'q0': 'bleu'});
    expect(h.transport.responses, hasLength(1));
  });

  test('reprise sans open_requests : rien n’est fermé', () async {
    await start();
    await asked();
    await reconnectWith(null);
    expect(question()!.state, QuestionState.open);
    expect(timeline().workState, WorkState.waitingInput);
    expect(h.transport.responses, isEmpty);
  });

  test(
    'snapshot : open_requests du curseur events.since pris en compte (close)',
    () async {
      await start();
      await asked();
      // Rejeu refusé (snapshot), puis curseur qui porte open_requests ; la
      // reprise, elle, n'en dit rien (champ facultatif).
      var sinceCalls = 0;
      h.transport.rpc = (method, params) {
        if (method == 'session.events.since' && ++sinceCalls == 1) {
          return const RpcFail(-32000);
        }
        if (method == 'session.history') return _result('session-history');
        return script(method, params);
      };
      await reconnectWith([], resumeOpen: false);
      await until(() => sinceCalls >= 2);
      await until(() => !conversation.resyncing(key));
      expect(
        h.transport.frames.where((f) => f['method'] == 'session.history'),
        isNotEmpty,
      );
      // Seul le curseur dit que la question n'est plus ouverte.
      expect(question()!.state, QuestionState.closed);
      expect(timeline().workState, WorkState.running);
    },
  );

  test(
    'arrêt pendant l’attente d’une réponse : seule sortie, possible',
    () async {
      await start();
      await asked();
      overrides['session.interrupt'] = {'status': 'interrupted'};
      expect(conversation.stopTarget(key), isNotNull);
      expect(outbox.canStop(draft.key), isTrue);
      await outbox.stop(draft.key);
      expect(
        h.transport.frames.where((f) => f['method'] == 'session.interrupt'),
        hasLength(1),
      );
    },
  );

  test('texte reçu pendant l’attente : même tour, attente conservée', () async {
    await start();
    await asked();
    final turns = timeline().turns;
    emit('message.delta', {'text': 'Je patiente.'}, 2);
    await until(() => timeline().seq == 2);
    expect(timeline().turns, turns);
    expect(timeline().workState, WorkState.waitingInput);
  });
  // --- Autorisations (story 6.3) ---------------------------------------

  const approvalId = 'srq-000000000002';
  ApprovalItem? approval() =>
      timeline().items.whereType<ApprovalItem>().firstOrNull;
  Future<Map<String, Object?>?> storedRow(String id) async {
    final rows = await database.query(
      'intervention_answers',
      where: 'request_id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : rows.single;
  }

  /// Tour accepté puis autorisation `approval` reçue en direct (fixture).
  Future<void> approvalAsked() async {
    await outbox.send(draft.key);
    emit('message.start', {}, 1);
    await until(() => timeline().seq == 1);
    h.transport.push(fixture('approval-request'));
    await until(() => approval() != null);
  }

  Map<String, Object?> approvalEntry() {
    final request = fixture('approval-request');
    return {
      'id': request['id'],
      'method': request['method'],
      'params': request['params'],
    };
  }

  test('autorisation reconnue par client.capabilities', () async {
    await start();
    final caps = {
      for (final c in h.repository.snapshot.capabilities) c.name: c.state,
    };
    expect(caps['approval'], CapabilityState.present);
  });

  test('autorisation en direct : carte ouverte, description et commande '
      'telles qu’émises, attente d’autorisation', () async {
    await start();
    await approvalAsked();
    final a = approval()!;
    expect(a.requestId, approvalId);
    expect(a.state, QuestionState.open);
    expect(a.description, 'delete in root path');
    expect(a.command, 'rm -rf /tmp/exemple');
    expect(a.choices, ['once', 'session', 'always', 'deny']);
    expect(a.allowSession, isTrue);
    expect(a.allowPermanent, isTrue);
    expect(a.turn, timeline().turns);
    expect(timeline().workState, WorkState.waitingApproval);
    // Persistée avec la projection.
    final row = (await database.query('conversation_timelines')).single;
    final restored = TimelineProjection.fromJson(
      jsonDecode(row['projection'] as String) as Map<String, Object?>,
    );
    final again = restored.items.whereType<ApprovalItem>().single;
    expect(again.command, a.command);
    expect(again.description, a.description);
    expect(restored.workState, WorkState.waitingApproval);
    // Rien ne part tout seul ; une fin d'outil ne touche pas une carte ouverte.
    expect(h.transport.responses, isEmpty);
    emit('tool.complete', {'tool_id': 'X', 'name': 'read_file'}, 2);
    await until(() => timeline().seq == 2);
    expect(approval()!.state, QuestionState.open);
  });

  test('refus : ligne en base avant la trame, trame deny conforme, « Décision '
      'envoyée » puis refusée au tool.complete bloqué', () async {
    await start();
    await approvalAsked();
    Future<List<Map<String, Object?>>>? atSend;
    h.transport.onFrame = (frame) {
      if (frame['method'] == null) {
        atSend = database.query('intervention_answers');
      }
    };
    await interventions.decide(key, approvalId, ApprovalChoice.deny);
    final seen = await atSend!;
    expect(seen.single['state'], 'sending');
    expect(jsonDecode(seen.single['answers'] as String), {'choice': 'deny'});
    final expected = fixture('approval-answer');
    expect(h.transport.responses, [
      {'jsonrpc': '2.0', 'id': expected['id'], 'result': expected['result']},
    ]);
    await until(() => approval()!.state == QuestionState.sent);
    expect(approval()!.choice, 'deny');
    expect(approval()!.blocked, isNull);
    expect((await storedRow(approvalId))!['state'], 'sent');
    h.transport.push(fixture('approval-denied'));
    await until(() => approval()!.state == QuestionState.confirmed);
    expect(approval()!.blocked, isTrue);
    expect(timeline().workState, WorkState.running);
    await settle();
    expect((await storedRow(approvalId))!['state'], 'confirmed');
    // Confirmation persistée avec la projection (écriture différée).
    Future<ApprovalItem> persistedCard() async {
      final row = (await database.query('conversation_timelines')).single;
      return TimelineProjection.fromJson(
        jsonDecode(row['projection'] as String) as Map<String, Object?>,
      ).items.whereType<ApprovalItem>().single;
    }

    var persisted = await persistedCard();
    for (
      var i = 0;
      i < 400 && persisted.state != QuestionState.confirmed;
      i++
    ) {
      await settle();
      persisted = await persistedCard();
    }
    expect(persisted.blocked, isTrue);
    expect(persisted.choice, 'deny');
    expect(persisted.state, QuestionState.confirmed);
    // Une seconde décision au même id n'est jamais envoyée.
    await expectLater(
      interventions.decide(key, approvalId, ApprovalChoice.once),
      throwsA(isA<AppError>().having((e) => e.code, 'code', 'approval.closed')),
    );
    expect(h.transport.responses, hasLength(1));
  });

  test(
    'autorisation : trame once, autorisée au tool.complete non bloqué',
    () async {
      await start();
      await approvalAsked();
      await interventions.decide(key, approvalId, ApprovalChoice.once);
      expect(h.transport.responses.single['result'], {'choice': 'once'});
      await until(() => approval()!.state == QuestionState.sent);
      emit('tool.complete', {
        'tool_id': 'SYNTHETIC_TOOL_2',
        'name': 'terminal',
        'result': {'output': 'ok', 'exit_code': 0},
      }, 2);
      await until(() => approval()!.state == QuestionState.confirmed);
      expect(approval()!.blocked, isFalse);
      expect(timeline().workState, WorkState.running);
    },
  );

  test('session et always ne sont jamais envoyés', () async {
    await start();
    await approvalAsked();
    for (final choice in ['session', 'always']) {
      await expectLater(
        interventions.decide(key, approvalId, choice),
        throwsA(
          isA<AppError>().having((e) => e.code, 'code', 'approval.choice'),
        ),
      );
    }
    expect(h.transport.responses, isEmpty);
    expect(await storedRow(approvalId), isNull);
    expect(approval()!.state, QuestionState.open);
  });

  test(
    'décision : écriture socket impossible, issue inconnue, aucun renvoi',
    () async {
      await start();
      await approvalAsked();
      h.transport.throwOnResponse = true;
      await interventions.decide(key, approvalId, ApprovalChoice.deny);
      await until(() => approval()!.state == QuestionState.unknown);
      expect((await storedRow(approvalId))!['state'], 'unknown');
      h.transport.throwOnResponse = false;
      await expectLater(
        interventions.decide(key, approvalId, ApprovalChoice.deny),
        throwsA(isA<AppError>()),
      );
      expect(h.transport.responses, hasLength(1));
    },
  );

  test(
    'décision hors connexion : rien d’écrit ni d’envoyé, la carte reste',
    () async {
      await start();
      await approvalAsked();
      await h.transport.sockets.last.drop();
      await until(() => h.repository.snapshot.link != LinkState.connected);
      await expectLater(
        interventions.decide(key, approvalId, ApprovalChoice.once),
        throwsA(
          isA<AppError>().having((e) => e.code, 'code', 'transport.offline'),
        ),
      );
      expect(await storedRow(approvalId), isNull);
      expect(approval()!.state, QuestionState.open);
      expect(h.transport.responses, isEmpty);
    },
  );

  test('request.cancel d’une autorisation : expirée ou annulée', () async {
    await start();
    await approvalAsked();
    emit('request.cancel', {
      'id': approvalId,
      'method': 'approval',
      'reason': 'timeout',
    }, 2);
    await until(() => approval()!.state == QuestionState.expired);
    expect(timeline().workState, WorkState.running);
    final other = fixture('approval-request');
    other['id'] = 'srq-000000000008';
    h.transport.push(other);
    await until(() => timeline().items.whereType<ApprovalItem>().length == 2);
    expect(timeline().workState, WorkState.waitingApproval);
    emit('request.cancel', {
      'id': 'srq-000000000008',
      'method': 'approval',
      'reason': 'interrupted',
    }, 3);
    await until(
      () =>
          timeline().items.whereType<ApprovalItem>().last.state ==
          QuestionState.cancelled,
    );
    expect(h.transport.responses, isEmpty);
  });

  test('reconnexion, autorisation encore ouverte avec décision locale : '
      'rouverte, mention de non-réception, aucun renvoi', () async {
    await start();
    await approvalAsked();
    await interventions.decide(key, approvalId, ApprovalChoice.deny);
    await until(() => approval()!.state == QuestionState.sent);
    await reconnectWith([approvalEntry()]);
    await until(() => approval()!.state == QuestionState.open);
    expect(approval()!.previousUnanswered, isTrue);
    expect(timeline().workState, WorkState.waitingApproval);
    expect(h.transport.responses, hasLength(1));
    // Nouvelle décision, prise à la main.
    await interventions.decide(key, approvalId, ApprovalChoice.once);
    expect(h.transport.responses, hasLength(2));
    expect(h.transport.responses.last['result'], {'choice': 'once'});
  });

  test('reconnexion, autorisation close : fermée sans renvoi', () async {
    await start();
    await approvalAsked();
    await interventions.decide(key, approvalId, ApprovalChoice.deny);
    await until(() => approval()!.state == QuestionState.sent);
    await reconnectWith([]);
    await until(() => approval()!.state == QuestionState.closed);
    expect(timeline().workState, WorkState.running);
    expect(h.transport.responses, hasLength(1));
    await settle();
    expect((await storedRow(approvalId))!['state'], 'closed');
  });

  test('reconnexion : autorisation inconnue de la projection rouverte depuis '
      'open_requests', () async {
    await start();
    await outbox.send(draft.key);
    emit('message.start', {}, 1);
    await until(() => timeline().seq == 1);
    await reconnectWith([approvalEntry()]);
    await until(() => approval() != null);
    expect(approval()!.state, QuestionState.open);
    expect(approval()!.previousUnanswered, isFalse);
    expect(approval()!.command, 'rm -rf /tmp/exemple');
    expect(timeline().workState, WorkState.waitingApproval);
    expect(h.transport.responses, isEmpty);
  });

  test(
    'relance : une décision en sending devient unknown, jamais renvoyée',
    () async {
      await start();
      await approvalAsked();
      await database.insert('intervention_answers', {
        'request_id': approvalId,
        'connection_key': connection.value,
        'profile_key': profile.value,
        'stored_session_id': _stored,
        'answers': jsonEncode({'choice': 'deny'}),
        'state': 'sending',
        'created_at': '2026-10-30T00:00:00Z',
      });
      await conversation.markQuestion(key, approvalId, QuestionState.sending);
      final relaunched = InterventionRepository(
        database,
        gateway: h.repository,
        conversation: conversation,
      );
      await relaunched.recovered;
      expect((await storedRow(approvalId))!['state'], 'unknown');
      expect(approval()!.state, QuestionState.unknown);
      expect(h.transport.responses, isEmpty);
    },
  );

  test('question et autorisation ouvertes : l’autorisation prime, puis '
      'l’attente de réponse revient', () async {
    await start();
    await asked();
    h.transport.push(fixture('approval-request'));
    await until(() => approval() != null);
    expect(timeline().workState, WorkState.waitingApproval);
    emit('request.cancel', {
      'id': approvalId,
      'method': 'approval',
      'reason': 'timeout',
    }, 2);
    await until(() => approval()!.state == QuestionState.expired);
    expect(timeline().workState, WorkState.waitingInput);
  });

  test('fin de tour : autorisation non close fermée', () async {
    await start();
    await approvalAsked();
    emit('message.complete', {'status': 'complete', 'text': 'Fini'}, 2);
    await until(() => timeline().workState == WorkState.succeeded);
    expect(approval()!.state, QuestionState.closed);
    expect(h.transport.responses, isEmpty);
  });
  test('refus suivi d’un tool.complete non bloqué : carte inchangée', () async {
    await start();
    await approvalAsked();
    await interventions.decide(key, approvalId, ApprovalChoice.deny);
    await until(() => approval()!.state == QuestionState.sent);
    emit('tool.complete', {
      'tool_id': 'AUTRE',
      'name': 'read_file',
      'result': {'output': 'ok'},
    }, 2);
    await until(() => timeline().seq == 2);
    expect(approval()!.state, QuestionState.sent);
    expect(approval()!.blocked, isNull);
    expect(timeline().workState, WorkState.waitingApproval);
  });

  test(
    'carte en cours d’envoi : un tool.complete ne la confirme pas',
    () async {
      await start();
      await approvalAsked();
      await conversation.markQuestion(
        key,
        approvalId,
        QuestionState.sending,
        choice: ApprovalChoice.deny,
      );
      await until(() => approval()!.state == QuestionState.sending);
      h.transport.push(fixture('approval-denied'));
      await settle();
      await settle();
      expect(approval()!.state, QuestionState.sending);
      expect(approval()!.blocked, isNull);
    },
  );

  test('issue inconnue puis tool.complete concordant : confirmée', () async {
    await start();
    await approvalAsked();
    h.transport.throwOnResponse = true;
    await interventions.decide(key, approvalId, ApprovalChoice.deny);
    await until(() => approval()!.state == QuestionState.unknown);
    h.transport.throwOnResponse = false;
    h.transport.push(fixture('approval-denied'));
    await until(() => approval()!.state == QuestionState.confirmed);
    expect(approval()!.blocked, isTrue);
    expect(timeline().workState, WorkState.running);
  });
}

/// Passerelle dont `respond` refuse sans rien écrire (socket absente).
class _OfflineRespond implements ConnectionGateway {
  _OfflineRespond(this.base);
  final ConnectionGateway base;
  @override
  ConnectionSnapshot get snapshot => base.snapshot;
  @override
  void respond(
    String id, {
    Map<String, dynamic>? result,
    Map<String, dynamic>? error,
  }) => throw const AppError('transport.offline', retryable: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
