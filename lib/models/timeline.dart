import 'connection.dart';
import 'draft.dart';
import 'profile.dart';

/// État du travail distant ; distinct de l'état de la connexion.
enum WorkState { sending, running, succeeded, failed, stopped, unknown }

/// Clé de la projection : (connexion, profil, session durable), sensible à la casse.
class TimelineKey {
  const TimelineKey(this.connection, this.profile, this.session);
  final ConnectionKey connection;
  final ProfileKey profile;
  final String session;
  @override
  bool operator ==(Object other) =>
      other is TimelineKey &&
      connection == other.connection &&
      profile == other.profile &&
      session == other.session;
  @override
  int get hashCode => Object.hash(connection, profile, session);
}

sealed class TimelineItem {
  const TimelineItem(this.turn);

  /// Rang du tour auquel l'élément appartient (1 pour le premier).
  final int turn;
  Map<String, Object?> toJson();
  static TimelineItem fromJson(Map<String, Object?> json) {
    final turn = json['turn'] as int;
    return switch (json['k']) {
      'user' => UserItem(
        turn,
        json['text'] as String,
        operation: OperationKey(json['op'] as String),
        userRowId: json['row'] as int?,
      ),
      'resp' => ResponseItem(turn, json['text'] as String),
      _ => ActivityItem(turn, json['kind'] as String),
    };
  }
}

/// Bulle locale, liée à la ligne serveur par `user_row_id`, jamais par le texte.
class UserItem extends TimelineItem {
  const UserItem(
    super.turn,
    this.text, {
    required this.operation,
    this.userRowId,
  });
  final String text;
  final OperationKey operation;
  final int? userRowId;
  UserItem withRow(int row) =>
      UserItem(turn, text, operation: operation, userRowId: row);
  @override
  Map<String, Object?> toJson() => {
    'k': 'user',
    'turn': turn,
    'text': text,
    'op': operation.value,
    'row': userRowId,
  };
}

class ResponseItem extends TimelineItem {
  const ResponseItem(super.turn, this.text);
  final String text;
  @override
  Map<String, Object?> toJson() => {'k': 'resp', 'turn': turn, 'text': text};
}

/// Ligne d'activité générique ; [kind] vient de la table de mapping.
class ActivityItem extends TimelineItem {
  const ActivityItem(super.turn, this.kind);
  final String kind;
  @override
  Map<String, Object?> toJson() => {'k': 'act', 'turn': turn, 'kind': kind};
}

/// Projection immuable d'une conversation ; seul `ConversationRepository` la produit.
class TimelineProjection {
  const TimelineProjection({
    this.items = const [],
    this.workState,
    this.errorCode,
    this.turns = 0,
    this.userTurns = 0,
    this.replayEpoch,
    this.seq,
  });
  final List<TimelineItem> items;

  /// Nul tant qu'aucune demande n'a été acceptée.
  final WorkState? workState;

  /// Code `domaine.code` de l'erreur du dernier tour, pour [Content.error].
  final String? errorCode;

  /// Tours démarrés par le serveur / demandes acceptées localement.
  final int turns;
  final int userTurns;

  /// Curseur : dernier `seq` appliqué sous cet `replay_epoch`.
  final String? replayEpoch;
  final int? seq;

  TimelineProjection copyWith({
    List<TimelineItem>? items,
    WorkState? workState,
    String? errorCode,
    bool clearError = false,
    int? turns,
    int? userTurns,
    String? replayEpoch,
    int? seq,
    bool resetSeq = false,
  }) => TimelineProjection(
    items: items ?? this.items,
    workState: workState ?? this.workState,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
    turns: turns ?? this.turns,
    userTurns: userTurns ?? this.userTurns,
    replayEpoch: replayEpoch ?? this.replayEpoch,
    seq: resetSeq ? null : seq ?? this.seq,
  );

  bool get inFlight =>
      workState == WorkState.sending || workState == WorkState.running;

  /// Contenu sans curseur (le curseur a ses propres colonnes).
  Map<String, Object?> toJson() => {
    'items': [for (final i in items) i.toJson()],
    'work': workState?.name,
    'error': errorCode,
    'turns': turns,
    'userTurns': userTurns,
  };

  static TimelineProjection fromJson(
    Map<String, Object?> json, {
    String? replayEpoch,
    int? seq,
  }) => TimelineProjection(
    items: [
      for (final i in json['items'] as List)
        TimelineItem.fromJson(Map<String, Object?>.from(i as Map)),
    ],
    workState: json['work'] == null
        ? null
        : WorkState.values.byName(json['work'] as String),
    errorCode: json['error'] as String?,
    turns: json['turns'] as int,
    userTurns: json['userTurns'] as int,
    replayEpoch: replayEpoch,
    seq: seq,
  );
}

/// Ce que `session.resume` apprend sur une session : liaison runtime et travail.
class Resumed {
  const Resumed({
    required this.runtime,
    this.running = false,
    this.inflight = false,
    this.partial,
    this.queued = false,
    this.generation = 0,
  });
  final String runtime;
  final bool running;

  /// Un tour en cours existe côté serveur (`inflight` non vide).
  final bool inflight;

  /// Texte assistant partiel du tour en cours.
  final String? partial;

  /// Des demandes attendent dans la file de la session.
  final bool queued;

  /// Génération de socket qui a porté la reprise.
  final int generation;

  Resumed at(int generation) => Resumed(
    runtime: runtime,
    running: running,
    inflight: inflight,
    partial: partial,
    queued: queued,
    generation: generation,
  );
}

/// Reprise de session fournie par l'outbox (seul appelant de `session.resume`)
/// à `ConversationRepository` ; jamais de création ni de renvoi.
abstract interface class SessionResumer {
  Future<Resumed> resume(TimelineKey key);

  /// Une opération `unknown` attend d'être tranchée : snapshot obligatoire.
  Future<bool> hasUnknown(TimelineKey key);

  /// Tranche les opérations `unknown` d'après les lignes utilisateur du
  /// snapshot (`row_id` croissants), par position, jamais par le texte.
  Future<void> reconcile(TimelineKey key, Resumed state, List<int> userRows);
}

/// Lecture de la projection par les ViewModels ; aucun appel Hermes.
abstract interface class ConversationGateway {
  /// Relit la projection enregistrée (ouverture de l'écran, relance).
  Future<TimelineProjection> load(TimelineKey key);

  /// Dernière projection connue en mémoire ([load] d'abord).
  TimelineProjection projection(TimelineKey key);

  /// Ce fil est en cours de resynchronisation (distinct de l'état du travail).
  bool resyncing(TimelineKey key);

  /// Clé dont la projection a changé.
  Stream<TimelineKey> get changes;
  Future<void> dispose();
}
