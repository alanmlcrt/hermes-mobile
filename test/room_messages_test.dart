import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/outbox_repository.dart';
import 'package:hermes_mobile/features/rooms/room_view.dart';
import 'package:hermes_mobile/features/rooms/room_view_model.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/room.dart';
import 'package:hermes_mobile/ui/theme.dart';

import 'support/connection_fakes.dart';
import 'support/room_harness.dart';

void main() {
  late RoomHarness r;
  setUp(() async {
    r = RoomHarness();
    await r.open();
  });
  tearDown(() async => r.close());
  test(
    '8.4 brouillon isolé, opération persistée avant envoi, succès',
    () async {
      await r.outbox.saveRoomText(r.key, 'Bonjour @agent1');
      expect(
        await r.outbox.roomText(
          RoomKey(r.key.connection, const ProfileKey('Other'), r.key.room),
        ),
        '',
      );
      r.h.transport.rpc = (m, p) {
        if (m != 'groups.send') return r.rpc(m, p);
        expect(p['profile'], 'default');
        expect((p['payload'] as Map)['thread_id'], p['event_id']);
        final e = r.event(
          1,
          text: 'Bonjour @agent1',
          kind: 'message.user',
          id: p['event_id'] as String,
        );
        r.events.add(e);
        return {'accepted': true, 'client_event_id': p['event_id'], 'event': e};
      };
      await r.outbox.sendRoom(r.key, 'Bonjour @agent1');
      expect((await r.outbox.roomSends(r.key)).single.state, 'confirmed');
      expect(await r.outbox.roomText(r.key), '');
      expect((await r.rooms.load(r.key)).entries.single.fromUser, isTrue);
    },
  );
  test('8.4 refus, incertain, redémarrage et aucun rejeu', () async {
    await r.outbox.saveRoomText(r.key, 'Conserver');
    r.h.transport.rpc = (m, p) =>
        m == 'groups.send' ? const RpcFail(403) : r.rpc(m, p);
    await expectLater(
      r.outbox.sendRoom(r.key, 'Conserver'),
      throwsA(roomCode('room.refused')),
    );
    r.h.transport.rpc = (m, p) => m == 'groups.send' ? null : r.rpc(m, p);
    await expectLater(
      r.outbox.sendRoom(r.key, 'Conserver'),
      throwsA(roomCode('rpc.uncertain')),
    );
    final before = r.h.transport.frames
        .where((e) => e['method'] == 'groups.send')
        .length;
    await r.outbox.dispose();
    r.outbox = OutboxRepository(r.db, gateway: r.h.repository)..rooms = r.rooms;
    expect(await r.outbox.roomText(r.key), 'Conserver');
    expect((await r.outbox.roomSends(r.key)).last.state, 'unknown');
    await expectLater(
      r.outbox.sendRoom(r.key, 'Conserver'),
      throwsA(roomCode('rpc.uncertain')),
    );
    expect(
      r.h.transport.frames.where((e) => e['method'] == 'groups.send').length,
      before,
    );
  });
  test('8.4 reprise paginée, sans doublon ; un trou est refusé', () async {
    r.events.addAll([r.event(1), r.event(2, actor: 'm2')]);
    r.h.transport.rpc = (m, p) => m == 'groups.log'
        ? {
            'events': [r.events[p['since_seq'] as int]],
            'cursor': (p['since_seq'] as int) + 1,
            'latest_seq': 2,
            'has_more': p['since_seq'] == 0,
          }
        : r.rpc(m, p);
    expect((await r.rooms.load(r.key)).entries.length, 2);
    expect((await r.rooms.load(r.key)).entries.length, 2);
    r.h.transport.rpc = r.rpc;
    r.events.removeAt(0);
    await expectLater(r.rooms.load(r.key), throwsA(roomCode('room.history')));
  });
  testWidgets('8.4 fil, mentions et texte à 200 % sans débordement', (
    tester,
  ) async {
    r.events.add(r.event(1, text: '**Bonjour** @user'));
    final vm = RoomViewModel(r.rooms, r.outbox, r.key);
    await tester.runAsync(vm.open);
    final accents = ProfileAccents(r.h.repository);
    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(null, Brightness.light),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: RoomView(create: () => vm, accents: accents),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('A besoin de toi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    accents.dispose();
  });
}
