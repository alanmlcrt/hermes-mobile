import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/app/routes.dart';
import 'package:hermes_mobile/data/notification_repository.dart';
import 'package:hermes_mobile/data/room_repository.dart';
import 'package:hermes_mobile/models/notifications.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/room.dart';

import 'notification_repository_test.dart' show Device;
import 'support/room_harness.dart';

void main() {
  late RoomHarness r;
  setUp(() async {
    r = RoomHarness();
    await r.open();
  });
  tearDown(() => r.close());
  test(
    '8.6 badge durable, ouverture acquittée, nouveau signal et isolation',
    () async {
      r.events.add(r.event(1, text: 'Bonjour @user'));
      await r.rooms.load(r.key);
      var list = await r.rooms.list(r.key.connection, r.key.profile);
      expect(list.single.needsUser, isTrue);
      await r.rooms.markSeen(
        RoomKey(r.key.connection, const ProfileKey('Other'), r.key.room),
        1,
      );
      list = await r.rooms.list(r.key.connection, r.key.profile);
      expect(list.single.needsUser, isTrue);
      await r.rooms.markSeen(r.key, 1);
      final restarted = RoomRepository(gateway: r.h.repository, database: r.db);
      expect(
        (await restarted.list(
          r.key.connection,
          r.key.profile,
        )).single.needsUser,
        isFalse,
      );
      r.events.add(r.event(2, text: 'Encore @user', actor: 'm2'));
      expect(
        (await restarted.list(
          r.key.connection,
          r.key.profile,
        )).single.needsUser,
        isTrue,
      );
    },
  );
  test('8.6 payload minimal, cible froide/chaude, ambiguïté refusée', () async {
    final repo = NotificationRepository(r.db, Device());
    await r.rooms.load(r.key);
    final raw = roomNotification(r.key.room, 'needs_user');
    expect(notificationRoom(raw), r.key.room);
    expect(
      notificationRoom('{"roomId":"x","outcome":"approval","text":"secret"}'),
      isNull,
    );
    final target = await repo.roomTarget(r.key.room);
    expect(target, r.key);
    expect(
      await resolveLaunchTarget(r.h.repository, r.outbox, room: target),
      roomPath(r.key),
    );
    await r.db.insert('room_snapshots', {
      'connection_key': 'Other',
      'profile_key': 'default',
      'room_id': r.key.room,
      'state_json': '{}',
      'events_json': '[]',
    });
    expect(await repo.roomTarget(r.key.room), isNull);
    expect(await repo.roomTarget(r.key.room.toLowerCase()), isNull);
  });
}
