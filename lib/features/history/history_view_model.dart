import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/connection_gateway.dart';
import '../../models/history.dart';
import '../../models/profile.dart';
import '../../models/timeline.dart';
import '../../ui/content.dart';

enum HistoryState { loading, empty, error, ready }

/// Conversations d'un profil. Aucune liste n'est gardée d'un chargement à
/// l'autre : pendant le chargement et après une erreur, rien n'est présenté.
class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel({
    required this.gateway,
    required this.conversation,
    required this.profile,
  }) {
    unawaited(refresh());
  }
  final ConnectionGateway gateway;
  final ConversationGateway conversation;
  final ProfileKey profile;

  HistoryState state = HistoryState.loading;
  List<SessionSummary> sessions = const [];
  int _request = 0;
  bool _disposed = false;

  /// Profil listé, tel qu'annoncé à l'écran.
  String get profileName {
    final known = gateway.snapshot.profiles
        .where((p) => p.key == profile)
        .firstOrNull;
    return known == null
        ? profile.value
        : Content.profileName(known.label, known.key.value);
  }

  /// Un chargement plus récent écarte la réponse d'un plus ancien.
  Future<void> refresh() async {
    final request = ++_request;
    state = HistoryState.loading;
    sessions = const [];
    _notify();
    try {
      final connection = gateway.snapshot.connection?.key;
      if (connection == null) throw StateError('no connection');
      final list = await conversation.sessions(connection, profile);
      if (request != _request) return;
      sessions = list;
      state = list.isEmpty ? HistoryState.empty : HistoryState.ready;
    } catch (_) {
      if (request != _request) return;
      state = HistoryState.error;
    }
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
