import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/app_error.dart';
import '../../models/connection.dart';
import '../../models/connection_gateway.dart';
import '../../models/conversation_search.dart';
import '../../models/history.dart';
import '../../models/profile.dart';
import '../../models/timeline.dart';
import '../../ui/content.dart';

enum HistoryState { loading, empty, error, ready }

/// Liste principale ou conversations masquées (7.4).
enum HistorySection { main, hidden }

/// Recherche (7.6) : rien demandé, en cours, terminée.
enum SearchState { idle, searching, done }

/// Renommage d'une conversation : saisie conservée, en cours, erreur.
class RenameStatus {
  const RenameStatus({required this.draft, this.busy = false, this.error});
  final String draft;
  final bool busy;
  final String? error;
}

/// Masquage ou suppression d'une ligne : en cours, ou dernière erreur.
class RowStatus {
  const RowStatus({this.busy = false, this.error});
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
  HistorySection section = HistorySection.main;

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
      final list = section == HistorySection.main
          ? await conversation.sessions(connection, profile)
          : await conversation.hiddenSessions(connection, profile);
      Map<String, ConversationMarker> marks;
      Set<String> unsure;
      try {
        marks = await conversation.markers(connection, profile);
        unsure = await conversation.uncertainDeletions(connection, profile);
      } catch (_) {
        marks = const {};
        unsure = const {};
      }
      if (request != _request) return;
      markers = marks;
      _status
        ..removeWhere((_, s) => !s.busy)
        ..addAll({
          for (final id in unsure)
            id: const RowStatus(error: 'delete.uncertain'),
        });
      sessions = _ordered(list);
      _listed = connection;
      state = list.isEmpty ? HistoryState.empty : HistoryState.ready;
    } catch (_) {
      if (request != _request) return;
      state = HistoryState.error;
    }
    _notify();
    if (searching) unawaited(_search());
  }

  List<SessionSummary> _ordered(List<SessionSummary> list) {
    final pinned = list.where((s) => markers[s.id]?.pinned ?? false).toList()
      ..sort(
        (a, b) => markers[a.id]!.pinOrder!.compareTo(markers[b.id]!.pinOrder!),
      );
    return [...pinned, ...list.where((s) => !pinned.contains(s))];
  }

  /// Change de section ; la recherche suit la section active.
  void showSection(HistorySection next) {
    if (next == section) return;
    section = next;
    unawaited(refresh());
  }

  // ── Masquer, rétablir, supprimer (7.4, 7.5) ─────────────────────────────

  /// Opération en cours ou dernière erreur, par session de la liste.
  final _status = <String, RowStatus>{};
  RowStatus? statusOf(String session) => _status[session];

  /// Dernier fil masqué ici : cible de « Annuler ».
  SessionSummary? lastHidden;

  bool get hideMissing {
    final connection = _listed ?? gateway.snapshot.connection?.key;
    return connection != null && conversation.hideMissing(connection);
  }

  /// Masque (ou rétablit) le fil ; il ne quitte sa section qu'après
  /// confirmation. Vrai si Hermes a confirmé.
  Future<bool> setHidden(SessionSummary session, bool hidden) =>
      _rowCommand(session, (key) async {
        final confirmed = await conversation.setHidden(key, hidden);
        if (confirmed != hidden) throw const AppError('rpc.uncertain');
        lastHidden = hidden ? session : null;
      }, uncertain: 'hide.uncertain');

  /// « Annuler » : l'inverse serveur, confirmé lui aussi.
  Future<bool> undoHide() async {
    final session = lastHidden;
    if (session == null) return false;
    final ok = await setHidden(session, false);
    if (ok && section == HistorySection.main) unawaited(refresh());
    return ok;
  }

  /// Suppression définitive confirmée par Hermes : la ligne reste jusque-là.
  Future<bool> delete(SessionSummary session) => _rowCommand(
    session,
    (key) => conversation.delete(key),
    uncertain: 'delete.uncertain',
  );

  Future<bool> _rowCommand(
    SessionSummary session,
    Future<void> Function(TimelineKey) command, {
    required String uncertain,
  }) async {
    final connection = _listed;
    if (connection == null || _status[session.id]?.busy == true) return false;
    _status[session.id] = const RowStatus(busy: true);
    _notify();
    try {
      await command(TimelineKey(connection, profile, session.id));
      if (_disposed) return true;
      _status.remove(session.id);
      if (_listed == connection) {
        sessions = [
          for (final s in sessions)
            if (s.id != session.id) s,
        ];
        if (sessions.isEmpty) state = HistoryState.empty;
      }
      _notify();
      unawaited(_search());
      return true;
    } catch (e) {
      if (_disposed) return false;
      final code = e is AppError ? e.code : 'action.failed';
      _status[session.id] = RowStatus(
        error: code == 'rpc.uncertain' ? uncertain : code,
      );
      _notify();
      return false;
    }
  }

  // ── Recherche locale (7.6) ──────────────────────────────────────────────

  String query = '';
  bool allProfiles = false;
  SearchState searchState = SearchState.idle;

  /// Résultats groupés par profil, dans l'ordre des profils.
  Map<ProfileKey, List<SearchHit>> results = const {};

  /// Profils dont la liste n'a pas pu être lue : résultats partiels.
  Set<ProfileKey> searchFailed = const {};
  int _searchGeneration = 0;

  bool get searching => query.trim().isNotEmpty;

  void search(String text) {
    query = text;
    unawaited(_search());
  }

  void setAllProfiles(bool value) {
    allProfiles = value;
    unawaited(_search());
  }

  /// Une requête plus récente écarte les réponses des précédentes.
  Future<void> _search() async {
    final generation = ++_searchGeneration;
    final q = query;
    if (q.trim().isEmpty) {
      searchState = SearchState.idle;
      results = const {};
      searchFailed = const {};
      _notify();
      return;
    }
    final connection = _listed ?? gateway.snapshot.connection?.key;
    final profiles = allProfiles
        ? [
            profile,
            for (final p in gateway.snapshot.profiles)
              if (p.key != profile) p.key,
          ]
        : [profile];
    searchState = SearchState.searching;
    _notify();
    final found = <ProfileKey, List<SearchHit>>{};
    final failed = <ProfileKey>{};
    for (final p in profiles) {
      try {
        if (connection == null) throw StateError('no connection');
        final list = p == profile && _listed == connection
            ? sessions
            : section == HistorySection.main
            ? await conversation.sessions(connection, p)
            : await conversation.hiddenSessions(connection, p);
        final texts = await conversation.loadedTexts(connection, p);
        final hits = searchSessions(
          q,
          profile: p,
          sessions: list,
          texts: texts,
        );
        if (hits.isNotEmpty) found[p] = hits;
      } catch (_) {
        failed.add(p);
      }
      if (generation != _searchGeneration || _disposed) return;
    }
    results = found;
    searchFailed = failed;
    searchState = SearchState.done;
    _notify();
  }

  /// Nom affiché d'un profil de la connexion.
  String nameOf(ProfileKey key) {
    final known = gateway.snapshot.profiles
        .where((p) => p.key == key)
        .firstOrNull;
    return known == null
        ? key.value
        : Content.profileName(known.label, known.key.value);
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
