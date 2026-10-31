import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/room_repository.dart';
import 'package:hermes_mobile/features/rooms/room_view_model.dart';

import 'support/connection_fakes.dart';
import 'support/room_harness.dart';

void main() {
  late RoomHarness r;
  setUp(() async {
    r = RoomHarness();
    await r.open();
    r.driver['working'] = true;
  });
  tearDown(() => r.close());
  test('8.5 arrêt demandé puis état serveur confirmé', () async {
    final vm = RoomViewModel(r.rooms, r.outbox, r.key);
    await vm.open();
    r.h.transport.rpc = (m, p) =>
        m == 'groups.stop' ? {'cancelled': 1} : r.rpc(m, p);
    await vm.stop();
    expect(vm.stopState, 'requested');
    expect(vm.snapshot!.working, isTrue);
    r.driver['working'] = false;
    await vm.refresh();
    expect(vm.stopState, 'confirmed');
    expect(vm.snapshot!.working, isFalse);
    vm.dispose();
  });
  test(
    '8.5 refus, absent et incertain sans second appel ; exclusion par salon',
    () async {
      r.h.transport.rpc = (m, p) =>
          m == 'groups.stop' ? const RpcFail(403) : r.rpc(m, p);
      await expectLater(r.rooms.stop(r.key), throwsA(roomCode('room.refused')));
      r.h.transport.rpc = (m, p) => m == 'groups.stop' ? null : r.rpc(m, p);
      final stopping = r.rooms.stop(r.key);
      await expectLater(
        r.outbox.sendRoom(r.key, 'hello'),
        throwsA(roomCode('room.busy')),
      );
      await expectLater(stopping, throwsA(roomCode('rpc.uncertain')));
      final fresh = RoomRepository(gateway: r.h.repository, database: r.db);
      expect(await fresh.commandState(r.key, 'stop'), 'unknown');
      await expectLater(fresh.stop(r.key), throwsA(roomCode('rpc.uncertain')));
      expect(
        r.h.transport.frames.where((e) => e['method'] == 'groups.stop').length,
        2,
      );
      expect(
        r.h.transport.frames.where((e) => e['method'] == 'groups.send'),
        isEmpty,
      );
    },
  );
  test('8.5 nouvelle tentative seulement permise, inconnu seulement abandonné, contexte frais', () async {
    r.driver['pending_actions'] = [
      {
        'kind': 'retry',
        'task_id': 'Task',
        'member_id': 'm1',
        'execution_generation': 4,
        'status': 'failed',
        'reason': 'outil refusé',
      },
    ];
    var task = (await r.rooms.load(r.key)).tasks.single;
    expect(task.retryable, isTrue);
    r.h.transport.rpc = (m, p) => m == 'groups.retry'
        ? {
            'retried': true,
            'task': {'task_id': 'Task'},
          }
        : r.rpc(m, p);
    await r.rooms.retry(r.key, task);
    r.driver['pending_actions'] = [
      {
        'kind': 'retry',
        'task_id': 'Task',
        'member_id': 'm1',
        'execution_generation': 5,
        'status': 'unknown',
      },
    ];
    await expectLater(
      r.rooms.retry(r.key, task),
      throwsA(roomCode('room.stale')),
    );
    task = (await r.rooms.load(r.key)).tasks.single;
    expect(task.retryable, isFalse);
    expect(task.canDiscard, isTrue);
    await expectLater(
      r.rooms.retry(r.key, task),
      throwsA(roomCode('room.stale')),
    );
    r.h.transport.rpc = (m, p) => m == 'groups.discard'
        ? {
            'discarded': true,
            'task': {'task_id': 'Task'},
          }
        : r.rpc(m, p);
    await r.rooms.discard(r.key, task);
    final params =
        r.h.transport.frames.lastWhere(
              (e) => e['method'] == 'groups.discard',
            )['params']
            as Map;
    expect(params['execution_generation'], 5);
    expect(params['member_id'], 'm1');
  });
}
