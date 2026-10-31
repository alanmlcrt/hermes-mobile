import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/conversation_repository.dart';
import 'package:hermes_mobile/data/event_mapping.dart';
import 'package:hermes_mobile/data/intervention_repository.dart';
import 'package:hermes_mobile/data/room_repository.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/room.dart';
import 'package:hermes_mobile/models/timeline.dart';

import 'contracts_test.dart' show contract;
import 'support/connection_fakes.dart';
import 'support/room_harness.dart';

void main() {
  late RoomHarness r;
  late ConversationRepository conversation;
  late InterventionRepository interventions;
  late RoomApproval approval;
  Map<String, dynamic> pending(int generation) => {
    'kind': 'approval',
    'member_id': 'm1',
    'task_id': 'Task_A',
    'execution_generation': generation,
    'request_id': 'Req_A',
    'description': 'Écrire le fichier demandé',
    'command': 'write_file /tmp/test.txt',
  };
  setUp(() async {
    r = RoomHarness();
    await r.open();
    conversation = ConversationRepository(
      r.db,
      gateway: r.h.repository,
      mapping: EventMapping(contract('event-mapping')),
    );
    interventions = InterventionRepository(
      r.db,
      gateway: r.h.repository,
      conversation: conversation,
    )..rooms = r.rooms;
    await interventions.recovered;
    r.driver['pending_actions'] = [pending(4)];
    approval = (await r.rooms.load(r.key)).approvals.single;
  });
  tearDown(() async {
    await conversation.dispose();
    await r.close();
  });
  test('8.7 demande réelle, contexte exact, refus utilisateur confirmé, clé complète', () async {
    expect(approval.command, 'write_file /tmp/test.txt');
    expect(
      (await r.rooms.list(r.key.connection, r.key.profile)).single.needsUser,
      isTrue,
    );
    r.h.transport.rpc = (m, p) => m == 'groups.approve'
        ? {
            'approved': true,
            'result': {'ok': true},
          }
        : r.rpc(m, p);
    await interventions.approveRoom(r.key, approval, 'deny');
    final p = r.h.transport.frames.lastWhere(
      (f) => f['method'] == 'groups.approve',
    )['params'];
    expect(p, {
      'profile': 'default',
      'room_id': 'Room_A',
      'member_id': 'm1',
      'task_id': 'Task_A',
      'execution_generation': 4,
      'request_id': 'Req_A',
      'choice': 'deny',
    });
    expect((await interventions.roomDecision(r.key, approval)).blocked, isTrue);
    expect(
      (await interventions.roomDecision(
        RoomKey(r.key.connection, const ProfileKey('Other'), r.key.room),
        approval,
      )).state,
      QuestionState.open,
    );
    await expectLater(
      interventions.approveRoom(r.key, approval, 'once'),
      throwsA(roomCode('room.stale')),
    );
  });
  test(
    '8.7 nouveau tour ou salon arrêté : demande périmée jamais envoyée',
    () async {
      r.driver['pending_actions'] = [pending(5)];
      await expectLater(
        interventions.approveRoom(r.key, approval, 'once'),
        throwsA(roomCode('room.stale')),
      );
      r.driver['pending_actions'] = <Map<String, dynamic>>[];
      await expectLater(
        interventions.approveRoom(r.key, approval, 'once'),
        throwsA(roomCode('room.stale')),
      );
      expect(
        r.h.transport.frames.where((f) => f['method'] == 'groups.approve'),
        isEmpty,
      );
    },
  );
  test(
    '8.7 refus serveur, incertain durable après redémarrage et aucun rejeu',
    () async {
      r.h.transport.rpc = (m, p) =>
          m == 'groups.approve' ? const RpcFail(403) : r.rpc(m, p);
      await expectLater(
        interventions.approveRoom(r.key, approval, 'once'),
        throwsA(roomCode('room.refused')),
      );
      r.h.transport.rpc = (m, p) => m == 'groups.approve' ? null : r.rpc(m, p);
      await expectLater(
        interventions.approveRoom(r.key, approval, 'once'),
        throwsA(roomCode('rpc.uncertain')),
      );
      interventions.rooms = RoomRepository(
        gateway: r.h.repository,
        database: r.db,
      );
      expect(
        (await interventions.roomDecision(r.key, approval)).state,
        QuestionState.unknown,
      );
      await expectLater(
        interventions.approveRoom(r.key, approval, 'once'),
        throwsA(roomCode('rpc.uncertain')),
      );
      expect(
        r.h.transport.frames
            .where((f) => f['method'] == 'groups.approve')
            .length,
        2,
      );
    },
  );
  test(
    '8.7 méthode absente et demande incomplète restent indisponibles',
    () async {
      r.h.transport.rpc = (m, p) =>
          m == 'groups.approve' ? const RpcFail(-32601) : r.rpc(m, p);
      await expectLater(
        interventions.approveRoom(r.key, approval, 'once'),
        throwsA(roomCode('room.missing')),
      );
      expect(
        (await r.rooms.capabilities(
          r.key.connection,
          r.key.profile,
        )).available.contains(RoomFeature.approve),
        isFalse,
      );
      r.driver['pending_actions'] = [
        {'kind': 'approval', 'description': 'Demande sans identité'},
      ];
      final incomplete = (await r.rooms.load(r.key)).approvals.single;
      expect(incomplete.actionable, isFalse);
      await expectLater(
        interventions.approveRoom(r.key, incomplete, 'once'),
        throwsA(roomCode('room.stale')),
      );
    },
  );
}
