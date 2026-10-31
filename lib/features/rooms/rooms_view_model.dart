import 'package:flutter/foundation.dart';

import '../../models/app_error.dart';
import '../../models/connection.dart';
import '../../models/profile.dart';
import '../../models/room.dart';

class RoomsViewModel extends ChangeNotifier {
  RoomsViewModel(this.repository, this.connection, this.profile);
  final RoomGateway repository;
  final ConnectionKey connection;
  final ProfileKey profile;
  List<RoomSummary> rooms = const [];
  bool loading = false;
  String? error;
  bool _disposed = false;
  int _request = 0;
  String name = '';
  final selected = <ProfileKey>{};
  Set<ProfileKey> eligible = const {};
  bool creating = false;
  bool creationUncertain = false;
  String? createError;
  late String creationId = repository.newId();
  bool get canCreate =>
      name.trim().isNotEmpty &&
      selected.length >= 2 &&
      selected.length <= 6 &&
      !creating &&
      !creationUncertain;

  Future<void> prepareCreate() async {
    try {
      final caps = await repository.capabilities(connection, profile);
      eligible = caps.driver ? caps.profiles : const {};
      createError = caps.driver ? null : 'room.bot_mode';
    } catch (e) {
      createError = e is AppError ? e.code : 'room.failed';
    }
    _notify();
  }

  void setName(String value) {
    name = value;
    _notify();
  }

  void select(ProfileKey key, bool value) {
    if (creating || creationUncertain || !eligible.contains(key)) return;
    value ? selected.add(key) : selected.remove(key);
    _notify();
  }

  Future<RoomSummary?> create() async {
    if (!canCreate) return null;
    creating = true;
    createError = null;
    _notify();
    try {
      final result = await repository.create(
        RoomKey(connection, profile, creationId),
        name,
        Set.of(selected),
      );
      return result;
    } catch (e) {
      createError = e is AppError ? e.code : 'room.failed';
      creationUncertain =
          createError == 'rpc.uncertain' ||
          createError == 'contract.invalid_response';
      return null;
    } finally {
      creating = false;
      _notify();
    }
  }

  Future<RoomSummary?> verifyCreation() async {
    try {
      return await repository.find(RoomKey(connection, profile, creationId));
    } catch (e) {
      createError = e is AppError ? e.code : 'room.failed';
      _notify();
      return null;
    }
  }

  Future<void> refresh() async {
    final request = ++_request;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await repository.list(connection, profile);
      if (_disposed || request != _request) return;
      rooms = result;
    } catch (e) {
      if (_disposed || request != _request) return;
      error = e is AppError ? e.code : 'room.failed';
    }
    loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
