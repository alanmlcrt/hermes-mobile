import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/app_error.dart';
import '../../models/connection.dart';
import '../../models/connection_gateway.dart';
import '../../models/draft.dart';
import '../../models/profile.dart';

class DraftViewModel extends ChangeNotifier {
  DraftViewModel({
    required this.outbox,
    required this.gateway,
    required this.key,
  }) {
    _subscription = gateway.snapshots.listen((_) => notifyListeners());
    unawaited(_load());
  }
  final OutboxGateway outbox;
  final ConnectionGateway gateway;
  final DraftKey key;
  late final StreamSubscription<ConnectionSnapshot> _subscription;
  Draft? draft;
  AppError? error;
  bool _disposed = false;

  Profile? get profile => gateway.snapshot.profiles
      .where((p) => p.key == draft?.profile)
      .firstOrNull;

  Future<void> _load() async {
    try {
      draft = await outbox.draft(key);
      if (draft == null) error = const AppError('draft.not_found');
    } catch (_) {
      error = const AppError('storage.unavailable');
    }
    _notify();
  }

  /// Chaque modification est écrite ; en cas d'échec le texte reste à l'écran.
  Future<void> update(String body) async {
    try {
      await outbox.saveText(key, body);
      if (error == null) return;
      error = null;
    } catch (_) {
      error = const AppError('storage.unavailable');
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
