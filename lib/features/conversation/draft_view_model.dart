import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/app_error.dart';
import '../../models/connection.dart';
import '../../models/connection_gateway.dart';
import '../../models/draft.dart';
import '../../models/profile.dart';
import '../../ui/content.dart';

class DraftViewModel extends ChangeNotifier {
  DraftViewModel({
    required this.outbox,
    required this.gateway,
    required this.key,
  }) {
    _subscription = gateway.snapshots.listen((_) => _notify());
    _outboxChanges = outbox.changes.listen(_onOutbox);
    unawaited(_load());
  }
  final OutboxGateway outbox;
  final ConnectionGateway gateway;
  final DraftKey key;
  late final StreamSubscription<ConnectionSnapshot> _subscription;
  late final StreamSubscription<DraftKey> _outboxChanges;
  String _text = '';
  String? _sentText;

  /// Incrémenté quand la saisie envoyée doit être retirée de l'écran.
  int clearTick = 0;
  Draft? draft;
  AppError? error;
  bool _disposed = false;

  Profile? get profile => gateway.snapshot.profiles
      .where((p) => p.key == draft?.profile)
      .firstOrNull;

  Future<void> _load() async {
    try {
      draft = await outbox.draft(key);
      _text = draft?.body ?? '';
      if (draft == null) error = const AppError('draft.not_found');
    } catch (_) {
      error = const AppError('storage.unavailable');
    }
    _notify();
  }

  /// Chaque modification est écrite ; en cas d'échec le texte reste à l'écran.
  Future<void> update(String body) async {
    final wasEmpty = _text.trim().isEmpty;
    _text = body;
    if (wasEmpty != body.trim().isEmpty) _notify();
    try {
      await outbox.saveText(key, body);
      if (error == null) return;
      error = null;
    } catch (_) {
      error = const AppError('storage.unavailable');
    }
    _notify();
  }

  SendStatus get sendStatus => outbox.status(key);

  /// Raison pour laquelle « Envoyer » est désactivé, ou null s'il est actif.
  String? get blockedReason {
    final snapshot = gateway.snapshot;
    final status = sendStatus;
    if (status.busy) return Content.sending;
    if (status.turnActive) return Content.turnActive;
    if (snapshot.link != LinkState.connected) {
      return Content.sendLink(switch (snapshot.link) {
        LinkState.resyncing => ConnectionLabels.resyncing,
        _ => ConnectionLabels.offline,
      });
    }
    final conversation = snapshot.capabilities
        .where((c) => c.name == 'conversation')
        .firstOrNull;
    if (conversation?.state == CapabilityState.absent) {
      return Content.sendCapabilityMissing;
    }
    if (conversation?.state != CapabilityState.present) {
      return Content.sendCapabilityPending;
    }
    if (_text.trim().isEmpty) return Content.sendEmpty;
    return null;
  }

  /// Texte d'état annoncé par la région live ; null si rien à signaler.
  String? get statusText {
    final status = sendStatus;
    if (status.busy) return Content.sending;
    if (status.turnActive) return Content.turnActive;
    return switch (status.state) {
      OperationState.accepted => Content.sendAccepted,
      OperationState.unknown || OperationState.failed => Content.error(
        status.errorCode ?? 'send.unavailable',
      ),
      _ => null,
    };
  }

  Future<void> send() {
    _sentText = _text;
    return outbox.send(key);
  }

  Future<void> _onOutbox(DraftKey changed) async {
    if (changed != key) return;
    if (sendStatus.state == OperationState.accepted && _sentText != null) {
      final sent = _sentText;
      _sentText = null;
      try {
        final fresh = await outbox.draft(key);
        // Brouillon vidé côté stockage et aucune frappe depuis : on efface.
        if (fresh != null && fresh.body.isEmpty && _text == sent) {
          _text = '';
          clearTick++;
        }
        draft = fresh ?? draft;
      } catch (_) {
        error = const AppError('storage.unavailable');
      }
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
    unawaited(_outboxChanges.cancel());
    super.dispose();
  }
}
