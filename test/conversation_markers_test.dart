// Story 7.3 — épingler et marquer non lu (marqueurs locaux au téléphone).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/data/storage/database.dart';
import 'package:hermes_mobile/features/history/history_view_model.dart';
import 'package:hermes_mobile/features/home/home_view.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/history.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'contracts_test.dart' show contract;
import 'support/connection_fakes.dart';

Map<String, dynamic> _result(String name) =>
    Map<String, dynamic>.from(fixture(name)['result'] as Map);

const _connection = ConnectionKey('c-1');
const _profile = ProfileKey('default');
const _stored = '<SYNTHETIC_STORED_SESSION>';
const _key = TimelineKey(_connection, _profile, _stored);

void main() {
  sqfliteFfiInit();
  final mapping = EventMapping(contract('event-mapping'));
  late Directory directory;
  late Database database;
  late Harness h;
  late ConversationRepository conversation;
  late OutboxRepository outbox;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await settle();
    }
  }

  ConversationRepository repo() =>
      ConversationRepository(database, gateway: h.repository, mapping: mapping);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hermes-markers-');
    database = await openConnectionDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/hermes.sqlite',
    );
    h = Harness();
    await h.connect();
    await settle();
    conversation = repo();
    outbox = OutboxRepository(
      database,
      gateway: h.repository,
      timeout: const Duration(milliseconds: 100),
      conversation: conversation,
    );
    h.transport.rpc = (method, _) => switch (method) {
      'session.create' => _result('session-create'),
      'prompt.submit' => _result('prompt-submit'),
      _ => null,
    };
  });

  tearDown(() async {
    await outbox.dispose();
    await conversation.dispose();
    await h.repository.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  void emit(String type, Map<String, dynamic> payload, int seq) =>
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

  Future<Map<String, ConversationMarker>> marks([
    ConnectionKey c = _connection,
  ]) => conversation.markers(c, _profile);

  Future<void> sendTurn() async {
    final draft = await outbox.openNewDraft(_connection, _profile);
    await outbox.saveText(draft.key, 'Bonjour');
    await outbox.send(draft.key);
    emit('message.start', {}, 1);
  }

  void complete(int seq) =>
      emit('message.complete', {'text': 'Fini', 'status': 'complete'}, seq);

  test('AC-1/2/3 : ordre d’épinglage persistant, isolé par clé', () async {
    TimelineKey k(String s, [ConnectionKey c = _connection]) =>
        TimelineKey(c, _profile, s);
    await conversation.setPinned(k('B'), true);
    await conversation.setPinned(k('A'), true);
    await conversation.setPinned(k('A', const ConnectionKey('c-2')), true);
    // Redémarrage : nouveau repository sur la même base.
    await conversation.dispose();
    conversation = repo();
    var m = await marks();
    expect(m['B']!.pinOrder! < m['A']!.pinOrder!, isTrue);
    expect(m.containsKey('C'), isFalse);
    await conversation.setPinned(k('B'), false);
    await conversation.setPinned(k('B'), true);
    m = await marks();
    expect(m['A']!.pinOrder! < m['B']!.pinOrder!, isTrue);
    await conversation.setPinned(k('A'), false);
    expect((await marks())['A']!.pinned, isFalse);
    expect((await marks(const ConnectionKey('c-2')))['A']!.pinned, isTrue);
  });

  test('AC-4/5/6 : fin non consultée → non lu ; ouverture, replay, '
      '« Marquer non lu » persistant', () async {
    await sendTurn();
    complete(2);
    await until(
      () => conversation.projection(_key).workState == WorkState.succeeded,
    );
    await settle();
    expect((await marks())[_stored]!.unread, isTrue);

    conversation.viewing(_key, true);
    await settle();
    expect((await marks())[_stored]!.unread, isFalse);
    conversation.viewing(_key, false);

    complete(2); // replay du même terminal
    await settle();
    await settle();
    expect((await marks())[_stored]!.unread, isFalse);

    await conversation.setUnread(_key, true);
    await conversation.dispose();
    conversation = repo();
    expect((await marks())[_stored]!.unread, isTrue);
  });

  test('AC-4 : fin reçue pendant l’affichage → reste lu', () async {
    conversation.viewing(_key, true);
    await sendTurn();
    complete(2);
    await until(
      () => conversation.projection(_key).workState == WorkState.succeeded,
    );
    await settle();
    expect((await marks())[_stored]?.unread ?? false, isFalse);
  });

  test('historique : épinglées d’abord dans l’ordre d’épinglage', () async {
    final memory = MemoryConversation();
    memory.lists[(h.repository.snapshot.connection!.key, _profile)] = [
      for (final id in ['A', 'B', 'C']) SessionSummary(id: id),
    ];
    final vm = HistoryViewModel(
      gateway: h.repository,
      conversation: memory,
      profile: _profile,
    );
    await until(() => vm.state == HistoryState.ready);
    await vm.togglePin('B');
    await vm.togglePin('A');
    expect([for (final s in vm.sessions) s.id], ['B', 'A', 'C']);
    await vm.toggleUnread('C');
    expect(vm.markerOf('C').unread, isTrue);
    memory.markerError = StateError('disk');
    await vm.togglePin('C');
    expect(vm.markerFailed, isTrue);
    expect(vm.markerOf('C').pinned, isFalse);
    vm.dispose();
  });

  testWidgets('accueil : « Non lu » sur la dernière conversation du profil', (
    tester,
  ) async {
    final memory = MemoryConversation();
    final connection = h.repository.snapshot.connection!.key;
    final profile = h.repository.snapshot.profiles.first.key;
    memory.lists[(connection, profile)] = const [
      SessionSummary(id: 'last', title: 'Dernière'),
    ];
    memory.markerRows[TimelineKey(connection, profile, 'last')] =
        const ConversationMarker(unread: true);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeView(
          gateway: h.repository,
          conversation: memory,
          accents: ProfileAccents(h.repository),
          onOpen: (_, _) {},
          onSettings: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dernière'), findsOne);
    expect(find.text(Content.unread), findsOne);
  });
}
