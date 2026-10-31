import '../models/app_error.dart';
import '../models/connection.dart';
import '../models/connection_gateway.dart';
import '../models/profile.dart';
import '../models/room.dart';
import 'hermes_adapter.dart';

/// Un seul accès aux salons ; le dialecte reste dans HermesRpc.
class RoomRepository implements RoomGateway {
  RoomRepository({required this.gateway, this.timeout = rpcTimeout});
  final ConnectionGateway gateway;
  final Duration timeout;
  final _busy = <RoomKey>{};
  final _missing = <(ConnectionKey, ProfileKey, int, String)>{};

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
  ) async => HermesRpc.roomCapabilities(
    await call(RoomKey(connection, profile, ''), HermesRpc.groupsCapabilities),
  );

  @override
  Future<List<RoomSummary>> list(
    ConnectionKey connection,
    ProfileKey profile,
  ) async {
    final caps = await capabilities(connection, profile);
    if (!caps.driver) throw const AppError('room.bot_mode');
    if (!caps.methods.contains(HermesRpc.groupsList)) {
      throw const AppError('room.missing');
    }
    final key = RoomKey(connection, profile, '');
    final rooms = <RoomSummary>[];
    int? offset;
    final seen = <int>{};
    do {
      final page = await call(key, HermesRpc.groupsList, {'offset': ?offset});
      rooms.addAll(HermesRpc.rooms(page));
      offset = page['next_offset'] as int?;
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
    final state = caps.methods.contains(HermesRpc.groupsState)
        ? await call(key, HermesRpc.groupsState)
        : <String, dynamic>{};
    final status = HermesRpc.roomStatus(state);
    final messages = caps.methods.contains(HermesRpc.groupsLog)
        ? HermesRpc.roomMessages(
            await call(key, HermesRpc.groupsLog, {'since_seq': 0}),
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
