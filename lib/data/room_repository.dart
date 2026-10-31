import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/app_error.dart';
import '../models/connection.dart';
import '../models/connection_gateway.dart';
import '../models/profile.dart';
import '../models/room.dart';
import 'hermes_adapter.dart';

/// Un seul accès aux salons ; le dialecte reste dans HermesRpc.
class RoomRepository implements RoomGateway {
  RoomRepository({
    required this.gateway,
    this.database,
    this.timeout = rpcTimeout,
  });
  final Database? database;
  final ConnectionGateway gateway;
  final Duration timeout;
  final _busy = <RoomKey>{};
  final _capabilities = <(ConnectionKey, ProfileKey, int), RoomCapabilities>{};
  @override
  RoomCapabilities? knownCapabilities(
    ConnectionKey connection,
    ProfileKey profile,
  ) {
    if (gateway.snapshot.connection?.key != connection) return null;
    return _capabilities[(connection, profile, gateway.socketGeneration)];
  }

  @override
  Future<void> markSeen(
    RoomKey key,
    int seq, {
    Set<String> approvals = const {},
  }) async {
    await database?.rawUpdate(
      'UPDATE room_snapshots SET seen_seq = MAX(seen_seq, ?), seen_approvals = ? WHERE $whereRoom',
      [seq, jsonEncode(approvals.toList()), ...key.args],
    );
  }

  final _missing = <(ConnectionKey, ProfileKey, int, String)>{};
  Future<void>? _commandsRecovered;
  Future<void> recoverCommands() => _commandsRecovered ??= (database == null
      ? Future.value()
      : database!
            .update(
              'room_commands',
              {'state': 'unknown'},
              where: 'state = ?',
              whereArgs: ['sending'],
            )
            .then((_) {}));

  @override
  Future<String?> commandState(RoomKey key, String command) async {
    await recoverCommands();
    final rows = await database?.query(
      'room_commands',
      columns: ['state'],
      where: '$whereRoom AND command_key = ?',
      whereArgs: [...key.args, command],
    );
    return rows == null || rows.isEmpty ? null : rows.single['state'] as String;
  }

  Future<void> recordCommand(RoomKey key, String command, String state) async {
    await database?.insert('room_commands', {
      'connection_key': key.connection.value,
      'profile_key': key.profile.value,
      'room_id': key.room,
      'command_key': command,
      'state': state,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Appelé sous la garde commune du salon, après vérification du contexte.
  Future<void> command(
    RoomKey key,
    String id,
    Future<bool> Function() send,
  ) async {
    final previous = await commandState(key, id);
    if (previous == 'unknown' || previous == 'sending') {
      throw const AppError('rpc.uncertain');
    }
    await recordCommand(key, id, 'sending');
    try {
      if (!await send()) throw const AppError('rpc.uncertain');
      await recordCommand(key, id, 'confirmed');
    } on AppError catch (e) {
      await recordCommand(
        key,
        id,
        {'room.refused', 'room.missing', 'transport.offline'}.contains(e.code)
            ? 'refused'
            : 'unknown',
      );
      rethrow;
    } catch (_) {
      await recordCommand(key, id, 'unknown');
      throw const AppError('rpc.uncertain');
    }
  }

  @override
  Future<void> stop(RoomKey key) => mutate(
    key,
    () => command(
      key,
      'stop',
      () async =>
          HermesRpc.roomStopReceipt(await call(key, HermesRpc.groupsStop)),
    ),
  );

  Future<void> _attempt(
    RoomKey key,
    RoomTask task, {
    required bool discard,
  }) => mutate(key, () async {
    final snapshot = await load(key);
    final fresh = snapshot.tasks.where(task.sameAttempt).firstOrNull;
    if (fresh == null ||
        (discard ? !fresh.canDiscard : !fresh.retryable || !fresh.failed)) {
      throw const AppError('room.stale');
    }
    final caps = await capabilities(key.connection, key.profile);
    final method = discard ? HermesRpc.groupsDiscard : HermesRpc.groupsRetry;
    if (!caps.methods.contains(method)) throw const AppError('room.missing');
    await command(
      key,
      jsonEncode([method, task.id, task.member, task.generation]),
      () async => HermesRpc.roomTaskReceipt(
        await call(key, method, HermesRpc.roomAttempt(task, discard: discard)),
        task,
        discard: discard,
      ),
    );
  });
  @override
  Future<void> retry(RoomKey key, RoomTask task) =>
      _attempt(key, task, discard: false);
  @override
  Future<void> discard(RoomKey key, RoomTask task) =>
      _attempt(key, task, discard: true);
  static const whereRoom =
      'connection_key = ? AND profile_key = ? AND room_id = ?';

  @override
  Future<RoomSnapshot> load(RoomKey key) async {
    final state = await call(key, HermesRpc.groupsState);
    final events = <Map<String, dynamic>>[];
    var cursor = 0;
    while (true) {
      final page = HermesRpc.roomLogPage(
        await call(key, HermesRpc.groupsLog, HermesRpc.roomLogParams(cursor)),
      );
      events.addAll(page.events);
      if (page.cursor < cursor || (page.more && page.cursor <= cursor)) {
        throw const AppError('room.history');
      }
      cursor = page.cursor;
      if (!page.more) {
        if (cursor != page.latest || cursor != events.length) {
          throw const AppError('room.history');
        }
        break;
      }
    }
    final snapshot = HermesRpc.roomSnapshot(state, events);
    check(key);
    if (!snapshot.working) {
      final pending = await commandState(key, 'stop');
      if (pending == 'confirmed' || pending == 'unknown') {
        await recordCommand(key, 'stop', 'settled');
      }
    }
    final db = database;
    if (db != null) {
      await db.transaction((tx) async {
        final old = await tx.query(
          'room_snapshots',
          columns: ['seen_seq', 'seen_approvals'],
          where: whereRoom,
          whereArgs: key.args,
        );
        await tx.insert('room_snapshots', {
          'connection_key': key.connection.value,
          'profile_key': key.profile.value,
          'room_id': key.room,
          'state_json': jsonEncode(state),
          'events_json': jsonEncode(events),
          'seen_seq': old.isEmpty ? 0 : old.single['seen_seq'],
          'seen_approvals': old.isEmpty ? '[]' : old.single['seen_approvals'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    }
    return snapshot;
  }

  @override
  Future<RoomSnapshot?> cached(RoomKey key) async {
    final rows = await database?.query(
      'room_snapshots',
      where: whereRoom,
      whereArgs: key.args,
    );
    if (rows == null || rows.isEmpty) return null;
    return HermesRpc.roomSnapshot(
      jsonDecode(rows.single['state_json'] as String) as Map,
      (jsonDecode(rows.single['events_json'] as String) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  @override
  String newId() => randomUuid();

  @override
  Future<RoomSummary> find(RoomKey key) async =>
      HermesRpc.roomFromResult(await call(key, HermesRpc.groupsState));

  @override
  Future<RoomSummary> create(
    RoomKey key,
    String name,
    Set<ProfileKey> members,
  ) => mutate(key, () async {
    if (name.trim().isEmpty || members.length < 2 || members.length > 6) {
      throw const AppError('room.invalid');
    }
    final caps = await capabilities(key.connection, key.profile);
    final reason = caps.creationUnavailableReason;
    if (reason != null) throw AppError(reason);
    if (!members.every(caps.profiles.contains)) {
      throw const AppError('room.no_eligible');
    }
    if (!caps.methods.contains(HermesRpc.groupsCreate)) {
      throw const AppError('room.missing');
    }
    final result = await call(
      key,
      HermesRpc.groupsCreate,
      HermesRpc.roomCreate(name.trim(), members),
    );
    try {
      final room = HermesRpc.roomFromResult(result);
      if (room.id != key.room) throw const AppError('rpc.uncertain');
      return room;
    } catch (_) {
      throw const AppError('rpc.uncertain');
    }
  });

  void check(RoomKey key) {
    if (gateway.snapshot.connection?.key != key.connection ||
        !gateway.snapshot.profiles.any((p) => p.key == key.profile)) {
      throw const AppError('connection.mismatch');
    }
  }

  Future<Map<String, dynamic>> call(
    RoomKey key,
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    check(key);
    final generation = gateway.socketGeneration;
    final missing = (key.connection, key.profile, generation, method);
    if (_missing.contains(missing)) throw const AppError('room.missing');
    try {
      final result = await gateway.call(
        method,
        HermesRpc.roomParams(key, params),
        timeout: timeout,
      );
      check(key);
      if (generation != gateway.socketGeneration) {
        throw const AppError('rpc.uncertain');
      }
      return result;
    } on RpcError catch (e) {
      if (e.code == HermesRpc.methodNotFound) {
        _missing.add(missing);
        throw const AppError('room.missing');
      }
      throw const AppError('room.refused');
    }
  }

  Future<T> mutate<T>(RoomKey key, Future<T> Function() action) async {
    check(key);
    if (!_busy.add(key)) throw const AppError('room.busy');
    try {
      return await action();
    } finally {
      _busy.remove(key);
    }
  }

  @override
  Future<RoomCapabilities> capabilities(
    ConnectionKey connection,
    ProfileKey profile,
  ) async {
    final generation = gateway.socketGeneration;
    _capabilities.removeWhere(
      (key, _) => key.$1 == connection && key.$2 == profile,
    );
    var caps = HermesRpc.roomCapabilities(
      await call(
        RoomKey(connection, profile, ''),
        HermesRpc.groupsCapabilities,
      ),
      unavailable: {
        for (final missing in _missing)
          if (missing.$1 == connection &&
              missing.$2 == profile &&
              missing.$3 == generation)
            missing.$4,
      },
    );
    if (caps.driver &&
        !caps.profilesAnnounced &&
        caps.available.contains(RoomFeature.create)) {
      try {
        caps = HermesRpc.roomRosterCapabilities(
          caps,
          await call(
            RoomKey(connection, profile, ''),
            HermesRpc.roomProfiles,
            HermesRpc.roomProfilesParams,
          ),
          {for (final p in gateway.snapshot.profiles) p.key},
        );
      } on AppError {
        // Ce complément concerne la création, jamais la disponibilité de groups.list.
      }
    }
    check(RoomKey(connection, profile, ''));
    if (generation != gateway.socketGeneration) {
      throw const AppError('rpc.uncertain');
    }
    _capabilities[(connection, profile, generation)] = caps;
    return caps;
  }

  @override
  Future<List<RoomSummary>> list(
    ConnectionKey connection,
    ProfileKey profile,
  ) async {
    final caps = await capabilities(connection, profile);
    final reason = caps.unavailableReason;
    if (reason != null) throw AppError(reason);
    if (!caps.methods.contains(HermesRpc.groupsList)) {
      throw const AppError('room.missing');
    }
    final key = RoomKey(connection, profile, '');
    final rooms = <RoomSummary>[];
    int? offset;
    final seen = <int>{};
    do {
      final page = await call(
        key,
        HermesRpc.groupsList,
        HermesRpc.roomListParams(offset),
      );
      rooms.addAll(HermesRpc.rooms(page));
      offset = HermesRpc.roomNextOffset(page);
      if (offset != null && !seen.add(offset)) {
        throw const AppError('contract.invalid_response');
      }
    } while (offset != null);
    return [
      for (final room in rooms)
        await _summary(RoomKey(connection, profile, room.id), room, caps),
    ];
  }

  Future<RoomSummary> _summary(
    RoomKey key,
    RoomSummary room,
    RoomCapabilities caps,
  ) async {
    if (database != null &&
        caps.methods.contains(HermesRpc.groupsState) &&
        caps.methods.contains(HermesRpc.groupsLog)) {
      final snapshot = await load(key);
      final rows = await database!.query(
        'room_snapshots',
        columns: ['seen_seq', 'seen_approvals'],
        where: whereRoom,
        whereArgs: key.args,
      );
      final seen = rows.isEmpty ? 0 : rows.single['seen_seq'] as int;
      final seenApprovals = rows.isEmpty
          ? const []
          : jsonDecode(rows.single['seen_approvals'] as String) as List;
      return RoomSummary(
        id: room.id,
        name: room.name,
        members: room.members,
        updatedAt: room.updatedAt,
        preview: snapshot.entries
            .where((e) => e.text.isNotEmpty)
            .lastOrNull
            ?.text,
        working: snapshot.working,
        needsUser:
            snapshot.entries.any((e) => e.needsUser && e.seq > seen) ||
            snapshot.approvals.any(
              (a) => !seenApprovals.contains(a.commandKey),
            ),
      );
    }
    final state = caps.methods.contains(HermesRpc.groupsState)
        ? await call(key, HermesRpc.groupsState)
        : <String, dynamic>{};
    final status = HermesRpc.roomStatus(state);
    final messages = caps.methods.contains(HermesRpc.groupsLog)
        ? HermesRpc.roomMessages(
            await call(key, HermesRpc.groupsLog, HermesRpc.roomLogParams(0)),
          )
        : <String>[];
    return RoomSummary(
      id: room.id,
      name: room.name,
      members: room.members,
      updatedAt: room.updatedAt,
      preview: messages.lastOrNull,
      working: status.working,
    );
  }
}
