import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/app_error.dart';
import '../../models/connection.dart';
import '../../models/connection_gateway.dart';
import '../../models/history.dart';
import '../../models/profile.dart';
import '../../models/timeline.dart';
import '../../ui/content.dart';

enum HistoryState { loading, empty, error, ready }

/// Renommage d'une conversation : saisie conservée, en cours, erreur.
class RenameStatus {
  const RenameStatus({required this.draft, this.busy = false, this.error});
  final String draft;
  final bool busy;
  final String? error;
}

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

  /// Épinglées d'abord (ordre d'épinglage), puis l'ordre du serveur.
  List<SessionSummary> sessions = const [];
  Map<String, ConversationMarker> markers = const {};

  /// Dernière écriture de marqueur échouée (rien n'a été enregistré).
  bool markerFailed = false;
  int _request = 0;
  bool _disposed = false;

  /// Connexion de la liste présentée ; `null` tant qu'aucune n'est chargée.
  ConnectionKey? _listed;
  final _renames = <String, RenameStatus>{};

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
    _listed = null;
    // La liste relue tranche les résultats à vérifier ; les saisies restent.
    _renames.updateAll((_, r) => r.busy ? r : RenameStatus(draft: r.draft));
    _notify();
    try {
      final connection = gateway.snapshot.connection?.key;
      if (connection == null) throw StateError('no connection');
      final list = await conversation.sessions(connection, profile);
      Map<String, ConversationMarker> marks;
      try {
        marks = await conversation.markers(connection, profile);
      } catch (_) {
        marks = const {};
      }
      if (request != _request) return;
      markers = marks;
      sessions = _ordered(list);
      _listed = connection;
      state = list.isEmpty ? HistoryState.empty : HistoryState.ready;
    } catch (_) {
      if (request != _request) return;
      state = HistoryState.error;
    }
    _notify();
  }

  List<SessionSummary> _ordered(List<SessionSummary> list) {
    final pinned = list.where((s) => markers[s.id]?.pinned ?? false).toList()
      ..sort(
        (a, b) => markers[a.id]!.pinOrder!.compareTo(markers[b.id]!.pinOrder!),
      );
    return [...pinned, ...list.where((s) => !pinned.contains(s))];
  }

  ConversationMarker markerOf(String session) =>
      markers[session] ?? const ConversationMarker();

  Future<void> togglePin(String session) => _markerCommand(
    session,
    (k) => conversation.setPinned(k, !markerOf(session).pinned),
  );

  Future<void> toggleUnread(String session) => _markerCommand(
    session,
    (k) => conversation.setUnread(k, !markerOf(session).unread),
  );

  /// Écriture locale puis relecture des marqueurs ; un échec est signalé.
  Future<void> _markerCommand(
    String session,
    Future<void> Function(TimelineKey) write,
  ) async {
    final connection = _listed;
    if (connection == null) return;
    try {
      await write(TimelineKey(connection, profile, session));
      final marks = await conversation.markers(connection, profile);
      if (_disposed || _listed != connection) return;
      markers = marks;
      sessions = _ordered(sessions);
      markerFailed = false;
    } catch (_) {
      markerFailed = true;
    }
    _notify();
  }

  /// `session.title` absente constatée sur la connexion de la liste.
  bool get renameMissing {
    final connection = _listed ?? gateway.snapshot.connection?.key;
    return connection != null && conversation.renameMissing(connection);
  }

  RenameStatus? renameOf(String session) => _renames[session];

  /// Erreur dont le résultat distant reste à vérifier par une actualisation.
  static bool needsRefresh(String? code) =>
      code == 'rpc.uncertain' ||
      code == 'rename.pending' ||
      code == 'contract.invalid_response' ||
      code == 'connection.mismatch';

  /// Vide (ou espaces) ou identique au titre courant, espaces externes
  /// retirés : aucun appel.
  static String? titleProblem(SessionSummary session, String input) {
    final title = input.trim();
    if (title.isEmpty) return 'rename.empty';
    if (title == session.title?.trim()) return 'rename.same';
    return null;
  }

  /// Renomme [session] avec la cible figée au lancement ; le titre n'est
  /// remplacé qu'après confirmation, dans la seule liste de sa connexion.
  /// Vrai si Hermes a confirmé.
  Future<bool> rename(SessionSummary session, String input) async {
    if (_renames[session.id]?.busy == true) return false;
    final problem = titleProblem(session, input);
    final connection = _listed;
    if (problem != null || connection == null) {
      _renames[session.id] = RenameStatus(
        draft: input,
        error: problem ?? 'connection.mismatch',
      );
      _notify();
      return false;
    }
    final key = TimelineKey(connection, profile, session.id);
    _renames[session.id] = RenameStatus(draft: input, busy: true);
    _notify();
    try {
      final title = await conversation.rename(key, input.trim());
      if (_disposed) return false;
      _renames.remove(session.id);
      if (_listed == key.connection) {
        sessions = [
          for (final s in sessions)
            s.id == session.id
                ? SessionSummary(
                    id: s.id,
                    title: title,
                    preview: s.preview,
                    startedAt: s.startedAt,
                    messageCount: s.messageCount,
                  )
                : s,
        ];
      } else {
        // Liste en cours de relecture ou relue entre-temps : elle peut
        // précéder la confirmation, on la relit une fois de plus.
        unawaited(refresh());
      }
      _notify();
      return true;
    } catch (e) {
      if (_disposed) return false;
      _renames[session.id] = RenameStatus(
        draft: input,
        error: e is AppError ? e.code : 'rename.failed',
      );
      _notify();
      return false;
    }
  }

  /// Dialogue fermé sans validation : rien n'est transmis ; un renommage en
  /// cours garde son état jusqu'à sa réponse.
  void dismissRename(String session) {
    if (_renames[session]?.busy == true) return;
    if (_renames.remove(session) != null) _notify();
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
