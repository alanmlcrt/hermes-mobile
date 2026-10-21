import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/data/storage/migrations.dart';
import 'package:hermes_mobile/features/conversation/draft_view.dart';
import 'package:hermes_mobile/features/conversation/draft_view_model.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/message_bubble.dart';
import 'package:hermes_mobile/ui/components/work_state_label.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'contracts_test.dart' show contract;
import 'support/connection_fakes.dart';

Map<String, dynamic> _result(String name) =>
    Map<String, dynamic>.from(fixture(name)['result'] as Map);

Object? _happy(String method, Map<String, dynamic> params) => switch (method) {
  'session.create' => _result('session-create'),
  'prompt.submit' => _result('prompt-submit'),
  _ => null,
};

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

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await settle();
    }
  }

  ConversationRepository newConversation() => ConversationRepository(
    database,
    gateway: h.repository,
    mapping: mapping,
  );

  Future<void> start() async {
    started = true;
    directory = await Directory.systemTemp.createTemp('hermes-timeline-');
    database = await openConnectionDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/hermes.sqlite',
    );
    h = Harness();
    await h.connect();
    await settle();
    conversation = newConversation();
    outbox = OutboxRepository(
      database,
      gateway: h.repository,
      timeout: const Duration(milliseconds: 100),
      conversation: conversation,
    );
    draft = await outbox.openNewDraft(connection, profile);
    await outbox.saveText(draft.key, _text);
    key = const TimelineKey(connection, profile, _stored);
    h.transport.rpc = _happy;
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

  void emit(
    String type,
    Map<String, dynamic> payload, {
    int? seq,
    String session = 'a1b2c3d4',
  }) {
    h.transport.sockets.last.controller.add({
      'jsonrpc': '2.0',
      'method': 'event',
      'params': {
        'type': type,
        'session_id': session,
        'payload': payload,
        'seq': ?seq,
      },
    });
  }

  TimelineProjection timeline() => conversation.projection(key);
  List<Type> kinds() => [for (final i in timeline().items) i.runtimeType];

  test('tour nominal : bulle liée par user_row_id, réponse, « Terminé », '
      'projection et curseur en une ligne', () async {
    await start();
    await outbox.send(draft.key);
    expect(timeline().workState, WorkState.sending);
    emit('message.start', {}, seq: 1);
    emit('message.delta', {'text': 'Voici '}, seq: 2);
    emit('message.delta', {'text': null}, seq: 3);
    emit('message.delta', {'text': 'la **réponse**'}, seq: 4);
    await until(() => timeline().seq == 4);
    expect(timeline().workState, WorkState.running);
    emit('message.complete', {
      'text': 'Voici la **réponse**',
      'status': 'complete',
      'persisted_turn': {'row_ids': [42, 43], 'user_row_id': 42},
    }, seq: 5);
    await until(() => timeline().workState == WorkState.succeeded);
    final p = timeline();
    expect(p.workState, WorkState.succeeded);
    expect(kinds(), [UserItem, ResponseItem]);
    expect((p.items[0] as UserItem).text, _text);
    expect((p.items[0] as UserItem).userRowId, 42);
    expect((p.items[1] as ResponseItem).text, 'Voici la **réponse**');
    final rows = await database.query('conversation_timelines');
    expect(rows, hasLength(1));
    expect(rows.single['stored_session_id'], _stored);
    expect(rows.single['replay_epoch'], 'synthetic-epoch');
    expect(rows.single['seq'], 5);
  });

  test('rapprochement par position (persisted_turn), jamais par le texte',
      () async {
    await start();
    h.transport.rpc = (method, params) => method == 'prompt.submit'
        ? {'status': 'streaming'}
        : _happy(method, params);
    await outbox.send(draft.key);
    expect((timeline().items.first as UserItem).userRowId, isNull);
    emit('message.start', {}, seq: 1);
    emit('message.complete', {
      'text': _text, // même texte que la demande : sans effet sur le lien
      'status': 'complete',
      'persisted_turn': {
        'user_row_ids': [7],
        'complete': true,
      },
    }, seq: 2);
    await until(() => timeline().seq == 2);
    expect((timeline().items.first as UserItem).userRowId, 7);
  });

  test('événements avant la réponse de soumission : la bulle passe devant',
      () async {
    await start();
    h.transport.rpc = (method, params) =>
        method == 'prompt.submit' ? null : _happy(method, params);
    final sending = outbox.send(draft.key);
    await until(() => h.transport.frames.last['method'] == 'prompt.submit');
    emit('message.start', {}, seq: 1);
    emit('message.delta', {'text': 'déjà là'}, seq: 2);
    await until(() => timeline().seq == 2);
    h.transport.sockets.single.controller.add({
      'jsonrpc': '2.0',
      'id': h.transport.frames.last['id'],
      'result': _result('prompt-submit'),
    });
    await sending;
    expect(kinds(), [UserItem, ResponseItem]);
    expect(timeline().workState, WorkState.running);
  });

  test('doublon, autre session et ancienne génération sont ignorés', () async {
    await start();
    await outbox.send(draft.key);
    emit('message.start', {}, seq: 1);
    emit('message.delta', {'text': 'a'}, seq: 2);
    emit('message.delta', {'text': 'a'}, seq: 2); // même seq
    emit('message.delta', {'text': 'ancien'}, seq: 1); // seq ≤ curseur
    emit('message.delta', {'text': 'autre'}, seq: 9, session: 'zzzzzzzz');
    emit('message.delta', {'text': 'b'}, seq: 3);
    await until(() => timeline().seq == 3);
    expect((timeline().items.last as ResponseItem).text, 'ab');
    // Nouvelle socket : la session liée l'était à l'ancienne génération.
    await h.transport.sockets.last.drop();
    await until(() => h.delays.isNotEmpty);
    h.delays.last.complete();
    await until(
      () =>
          h.transport.sockets.length == 2 &&
          h.repository.snapshot.link == LinkState.connected,
    );
    emit('message.delta', {'text': 'périmé'}, seq: 10);
    await settle();
    await settle();
    expect(timeline().seq, 3);
    expect((timeline().items.last as ResponseItem).text, 'ab');
  });

  for (final (status, expected) in [
    ('error', WorkState.failed),
    ('interrupted', WorkState.stopped),
    ('complete', WorkState.succeeded),
    ('surprise', WorkState.unknown),
  ]) {
    test('message.complete $status → ${expected.name}', () async {
      await start();
      await outbox.send(draft.key);
      emit('message.start', {}, seq: 1);
      emit('message.complete', {'text': '', 'status': status}, seq: 2);
      await until(() => timeline().seq == 2);
      expect(timeline().workState, expected);
      expect(
        timeline().errorCode,
        expected == WorkState.failed ? 'turn.error' : isNull,
      );
    });
  }

  test("événement error : échec simple, détail du serveur jamais affiché",
      () async {
    await start();
    await outbox.send(draft.key);
    emit('message.start', {}, seq: 1);
    emit('error', {'message': 'SYNTHETIC_DETAIL'}, seq: 2);
    await until(() => timeline().seq == 2);
    expect(timeline().workState, WorkState.failed);
    expect(Content.error(timeline().errorCode!), isNot(contains('SYNTHETIC')));
  });

  test('perte de socket en cours : « non synchronisé », jamais terminé',
      () async {
    await start();
    await outbox.send(draft.key);
    emit('message.start', {}, seq: 1);
    await until(() => timeline().workState == WorkState.running);
    await h.transport.sockets.single.drop();
    await until(() => timeline().workState == WorkState.unknown);
    expect(timeline().workState, WorkState.unknown);
    expect(timeline().errorCode, isNull);
    // Un tour terminé n'est pas touché par une perte de socket.
  });

  test('types inconnus et outils : ligne d’activité générique', () async {
    await start();
    await outbox.send(draft.key);
    emit('message.start', {}, seq: 1);
    emit('tool.start', {'name': 'SYNTHETIC'}, seq: 2);
    emit('tool.complete', {}, seq: 3);
    emit('foo.bar', {'x': 1}, seq: 4);
    await until(() => timeline().items.whereType<ActivityItem>().length == 2);
    final activities = timeline().items.whereType<ActivityItem>().toList();
    expect(activities.map((a) => a.kind), ['tool', 'unknown']);
    expect(timeline().workState, WorkState.running);
  });

  test('relance : fil relu depuis SQLite, travail en cours non synchronisé',
      () async {
    await start();
    await outbox.send(draft.key);
    emit('message.start', {}, seq: 1);
    emit('message.delta', {'text': 'partiel'}, seq: 2);
    await until(() => timeline().seq == 2);
    await Future<void>.delayed(ConversationRepository.flushInterval * 2);
    final relaunched = newConversation();
    addTearDown(relaunched.dispose);
    final loaded = await relaunched.load(key);
    expect(loaded.items.map((i) => i.runtimeType), [UserItem, ResponseItem]);
    expect((loaded.items.last as ResponseItem).text, 'partiel');
    expect(loaded.seq, 2);
    expect(loaded.workState, WorkState.unknown);
  });

  test('migration réelle v4 vers v5 : ajout seul, données conservées',
      () async {
    started = true;
    directory = await Directory.systemTemp.createTemp('hermes-v4-');
    final path = '${directory.path}/hermes.sqlite';
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          for (var i = 0; i < 4; i++) {
            await connectionMigrations[i](db);
          }
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
    conversation = newConversation();
    expect(await database.getVersion(), 5);
    expect((await database.query('outbox_drafts')).single['body'], 'gardé');
    expect(await database.query('conversation_timelines'), isEmpty);
  });

  Future<(MemoryOutbox, Draft)> pumpView(
    WidgetTester tester,
    MemoryConversation memory, {
    String? session = _stored,
  }) async {
    final outbox = MemoryOutbox();
    final h = Harness();
    final d = await outbox.openNewDraft(
      const ConnectionKey('c-1'),
      const ProfileKey('default'),
    );
    outbox.drafts[d.key] = Draft(
      key: d.key,
      connection: d.connection,
      profile: d.profile,
      body: '',
      storedSessionId: session,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(null, Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: DraftView(
            create: () => DraftViewModel(
              outbox: outbox,
              gateway: h.repository,
              conversation: memory,
              key: d.key,
            ),
            onOpenProfiles: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (outbox, outbox.drafts[d.key]!);
  }

  testWidgets('réponse riche à 200 % en sombre : code défilant, sans '
      'débordement ; reconstruction sans appel', (tester) async {
    final memory = MemoryConversation();
    memory.projections[key = const TimelineKey(
      ConnectionKey('c-1'),
      ProfileKey('default'),
      _stored,
    )] = TimelineProjection(
      items: [
        UserItem(1, 'Demande', operation: const OperationKey('o-1')),
        ResponseItem(
          1,
          '# Titre\n\n- liste 🚀\n- **gras**\n\n'
          '```dart\nfinal ligneTresLongue = ${'valeur' * 30};\n```',
        ),
        const ActivityItem(1, 'tool'),
      ],
      workState: WorkState.succeeded,
      turns: 1,
      userTurns: 1,
    );
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpView(tester, memory);
    expect(tester.takeException(), isNull);
    expect(find.byType(MessageBubble), findsNWidgets(2));
    expect(find.text(WorkStateLabel.label(WorkState.succeeded)), findsOne);
    final scroll = find.descendant(
      of: find.byType(MessageBubble),
      matching: find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      ),
    );
    expect(scroll, findsOneWidget);
    final extent = tester
        .state<ScrollableState>(
          find.descendant(of: scroll, matching: find.byType(Scrollable)),
        )
        .position
        .maxScrollExtent;
    expect(extent, greaterThan(0));
    // Rotation : le fil reste identique, la projection n'est pas rechargée.
    final loads = memory.loaded.length;
    tester.view.physicalSize = const Size(3000, 6000);
    await tester.pumpAndSettle();
    expect(find.byType(MessageBubble), findsNWidgets(2));
    expect(memory.loaded.length, loads);
  });

  testWidgets('mouvement réduit : aucune animation d’apparition', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MessageBubble(text: 'Réponse 🚀'),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(MessageBubble),
        matching: find.byWidgetPredicate(
          (w) => w is ImplicitlyAnimatedWidget || w is AnimatedWidget,
        ),
      ),
      findsNothing,
    );
  });

  Future<void> startTurn() async {
    await start();
    await outbox.send(draft.key);
    emit('message.start', {}, seq: 1);
    await until(() => timeline().seq == 1);
  }

  test('interim : already_streamed false en paragraphe, true sans effet',
      () async {
    await startTurn();
    emit('message.delta', {'text': 'A'}, seq: 2);
    emit('message.interim', {'text': 'B', 'already_streamed': false}, seq: 3);
    await until(() => timeline().seq == 3);
    expect((timeline().items.last as ResponseItem).text, 'A\n\nB');
    emit('message.interim', {'text': 'C', 'already_streamed': true}, seq: 4);
    await until(() => timeline().seq == 4);
    expect((timeline().items.last as ResponseItem).text, 'A\n\nB');
  });

  test('nouvel replay_epoch : seq plus bas appliqué ; bind efface le curseur',
      () async {
    await startTurn();
    final epochs = <String?>[];
    final sub = h.repository.events.listen((e) => epochs.add(e.replayEpoch));
    addTearDown(sub.cancel);
    emit('message.delta', {'text': 'a'}, seq: 5);
    await until(() => timeline().seq == 5);
    final ready = fixture('gateway-ready-legacy');
    ready['params']['payload']['replay_epoch'] = 'epoch-2';
    h.transport.sockets.last.controller.add(ready);
    await settle();
    emit('message.delta', {'text': 'b'}, seq: 1);
    await until(() => timeline().replayEpoch == 'epoch-2');
    expect(epochs.last, 'epoch-2');
    expect(timeline().seq, 1);
    expect((timeline().items.last as ResponseItem).text, 'ab');
    conversation.bind(key, 'nouveau1', h.repository.socketGeneration);
    await until(() => timeline().seq == null);
    expect(timeline().seq, isNull);
  });

  test('texte final : fait foi, ajouté sans deltas, ignoré si partiel',
      () async {
    await startTurn();
    emit('message.delta', {'text': 'abc'}, seq: 2);
    emit('message.complete', {'text': 'XYZ', 'status': 'complete'}, seq: 3);
    await until(() => timeline().seq == 3);
    expect((timeline().items.last as ResponseItem).text, 'XYZ');
    expect(timeline().items.whereType<ResponseItem>(), hasLength(1));
  });

  test('texte final sans deltas : réponse ajoutée', () async {
    await startTurn();
    emit('message.complete', {'text': 'seul', 'status': 'complete'}, seq: 2);
    await until(() => timeline().seq == 2);
    expect((timeline().items.last as ResponseItem).text, 'seul');
  });

  test('texte final partiel : deltas conservés', () async {
    await startTurn();
    emit('message.delta', {'text': 'abc'}, seq: 2);
    emit('message.complete', {
      'text': 'zzz',
      'status': 'error',
      'partial': true,
    }, seq: 3);
    await until(() => timeline().seq == 3);
    expect((timeline().items.last as ResponseItem).text, 'abc');
  });

  testWidgets('premier envoi : après le changement outbox, bulle et réponse '
      'affichées', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final memory = MemoryConversation();
    final (outbox, d) = await pumpView(tester, memory, session: null);
    expect(find.byType(MessageBubble), findsNothing);
    outbox.drafts[d.key] = Draft(
      key: d.key,
      connection: d.connection,
      profile: d.profile,
      body: '',
      storedSessionId: _stored,
    );
    memory.projections[const TimelineKey(
      ConnectionKey('c-1'),
      ProfileKey('default'),
      _stored,
    )] = TimelineProjection(
      items: [
        UserItem(1, 'Ma demande', operation: const OperationKey('o-1')),
        const ResponseItem(1, 'Ma réponse'),
      ],
      workState: WorkState.running,
    );
    outbox.setStatus(d.key, const SendStatus(state: OperationState.accepted));
    await tester.pumpAndSettle();
    expect(find.text('Ma demande'), findsOne);
    expect(find.text('Ma réponse'), findsOne);
  });

  testWidgets('projection en échec : message d’erreur du tour', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final memory = MemoryConversation();
    memory.projections[const TimelineKey(
      ConnectionKey('c-1'),
      ProfileKey('default'),
      _stored,
    )] = const TimelineProjection(
      workState: WorkState.failed,
      errorCode: 'turn.error',
    );
    await pumpView(tester, memory);
    expect(find.text(Content.error('turn.error')), findsOne);
  });

  testWidgets('image Markdown : texte alternatif, aucune image chargée',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MessageBubble(
          text: '![texte alt](https://exemple.invalid/pixel.png) [lien](https://exemple.invalid)',
        ),
      ),
    );
    expect(find.text('texte alt'), findsOne);
    expect(find.byType(Image), findsNothing);
  });
}
