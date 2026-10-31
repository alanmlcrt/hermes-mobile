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
