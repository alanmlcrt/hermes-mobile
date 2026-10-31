import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/data/room_repository.dart';
import 'package:hermes_mobile/features/rooms/rooms_view_model.dart';
import 'package:hermes_mobile/models/profile.dart';

import 'support/connection_fakes.dart';
import 'rooms_list_test.dart' show roomCaps, roomData, roomProfile;

void main() {
  test(
    '8.3 éligibilité, bornes, confirmation, refus et incertain sans rejeu',
    () async {
      final h = Harness();
      await h.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final connection = h.repository.snapshot.connection!.key;
      final repo = RoomRepository(
        gateway: h.repository,
        timeout: const Duration(milliseconds: 50),
      );
      final vm = RoomsViewModel(repo, connection, roomProfile);
      h.transport.rpc = (m, p) => m == 'groups.capabilities'
          ? roomCaps()
          : {'room': roomData(p['room_id'] as String)};
      await vm.prepareCreate();
      vm.setName('Travail');
      vm.select(roomProfile, true);
      vm.select(const ProfileKey('ineligible'), true);
      expect(vm.selected.length, 1);
      expect(vm.canCreate, isFalse);
      vm.select(const ProfileKey('Second'), true);
      expect(vm.canCreate, isTrue);
      expect((await vm.create())!.id, vm.creationId);
      final calls = h.transport.frames.where(
        (f) => f['method'] == 'groups.create',
      );
      expect(calls.length, 1);
      expect((calls.single['params'] as Map)['profile'], 'default');
      h.transport.rpc = (m, p) =>
          m == 'groups.capabilities' ? roomCaps() : const RpcFail(403);
      expect(await vm.create(), isNull);
      expect(vm.name, 'Travail');
      expect(vm.selected.length, 2);
      expect(vm.createError, 'room.refused');
      h.transport.rpc = (m, p) =>
          m == 'groups.capabilities' ? roomCaps() : null;
      expect(await vm.create(), isNull);
      expect(vm.creationUncertain, isTrue);
      expect(await vm.create(), isNull);
      expect(calls.length, 3);
      vm.dispose();
      await h.repository.dispose();
    },
  );
}
