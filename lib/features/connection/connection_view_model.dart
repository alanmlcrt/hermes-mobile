import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/app_error.dart';
import '../../models/connection.dart';
import '../../models/connection_gateway.dart';

class ConnectionViewModel extends ChangeNotifier {
  ConnectionViewModel(this.gateway) {
    _subscription = gateway.snapshots.listen((_) => notifyListeners());
  }
  final ConnectionGateway gateway;
  late final StreamSubscription<ConnectionSnapshot> _subscription;
  Uri? candidate;
  bool confirmed = false;
  AppError? inputError;
  ConnectionSnapshot get snapshot => gateway.snapshot;
  AppError? get error => inputError ?? snapshot.error;
  void edit() {
    candidate = null;
    confirmed = false;
    inputError = null;
    notifyListeners();
  }

  void preview(String input, {bool notify = true}) {
    confirmed = false;
    try {
      candidate = parseOrigin(input);
      inputError = null;
    } on AppError catch (error) {
      candidate = null;
      inputError = error;
    }
    if (notify) notifyListeners();
  }

  Future<void> confirm() async {
    if (candidate == null) return;
    await gateway.confirmOrigin(candidate!);
    confirmed = gateway.snapshot.connection?.origin == candidate;
    notifyListeners();
  }

  Future<void> login(String password) async {
    if (!confirmed) return;
    await gateway.authenticate(password);
  }

  bool matchesSavedOrigin(String input) {
    try {
      return parseOrigin(input) == snapshot.connection?.origin;
    } on AppError {
      return false;
    }
  }

  Future<void> reconnect() => gateway.reconnect();

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
