import 'connection.dart';
import 'attachment.dart';
import 'draft.dart';
import 'history.dart';
import 'profile.dart';

/// État du travail distant ; distinct de l'état de la connexion.
/// `waitingInput` : le tour est en cours et Hermes attend une réponse (6.2).
enum WorkState {
  sending,
  running,
  waitingInput,
  succeeded,
  failed,
  stopped,
  unknown,
}

enum ActivityKind {
  tool,
  code,
  fileCreate,
  webSearch,
  fileRead,
  command,
  webBrowse,
  fileEdit,
  fileSearch,
  imageCreate,
  memory,
  delegate,
  organize,
  imageAnalyze,
  skill,
  schedule,
  preparation,
  unknown;

  static ActivityKind decode(Object? value) => switch (value) {
    'tool' => ActivityKind.tool,
    'code' => ActivityKind.code,
    'fileCreate' => ActivityKind.fileCreate,
    'webSearch' => ActivityKind.webSearch,
    'fileRead' => ActivityKind.fileRead,
    'command' => ActivityKind.command,
    'webBrowse' => ActivityKind.webBrowse,
    'fileEdit' => ActivityKind.fileEdit,
    'fileSearch' => ActivityKind.fileSearch,
    'imageCreate' => ActivityKind.imageCreate,
    'memory' => ActivityKind.memory,
    'delegate' => ActivityKind.delegate,
    'organize' => ActivityKind.organize,
    'imageAnalyze' => ActivityKind.imageAnalyze,
    'skill' => ActivityKind.skill,
    'schedule' => ActivityKind.schedule,
    'preparation' => ActivityKind.preparation,
    _ => ActivityKind.unknown,
  };

  /// Famille d'un outil Hermes d'après son nom (`tool.start`), `tool` si le
  /// nom est absent ou inconnu. Noms : hermes-agent/tools (recherche du
  /// 20/10, .working/hermes-tool-activity-research.md).
  static ActivityKind forTool(Object? name) {
    if (name is! String) return ActivityKind.tool;
    final tool = name.trim().split(RegExp(r'\s')).first;
    if (tool.startsWith('browser_')) {
      return tool == 'browser_vision'
          ? ActivityKind.imageAnalyze
          : ActivityKind.webBrowse;
    }
    if (tool.startsWith('cronjob')) return ActivityKind.schedule;
    return switch (tool) {
      'terminal' || 'process' => ActivityKind.command,
      'execute_code' => ActivityKind.code,
      'read_file' => ActivityKind.fileRead,
      'write_file' => ActivityKind.fileCreate,
      'patch' => ActivityKind.fileEdit,
      'search_files' => ActivityKind.fileSearch,
      'web_search' => ActivityKind.webSearch,
      'web_extract' => ActivityKind.webBrowse,
      'image_generate' => ActivityKind.imageCreate,
      'vision_analyze' => ActivityKind.imageAnalyze,
      'memory' || 'session_search' => ActivityKind.memory,
      'skills_list' || 'skill_view' || 'skill_manage' => ActivityKind.skill,
      'delegate_task' || 'mixture_of_agents' => ActivityKind.delegate,
      'todo' => ActivityKind.organize,
      _ => ActivityKind.tool,
    };
  }
}

/// Pose courante de présentation, sans mesure de progression ni succès.
/// Non persistée : la reprise reconstruit la pose depuis l'état courant.
enum CompanionPhase { neutral, concentrating, reading }

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

/// Repère local observé, jamais présenté comme identité de tour serveur.
class StopTarget {
  const StopTarget(
    this.key,
    this.runtime,
    this.generation,
    this.turn,
    this.revision,
  );
  final TimelineKey key;
  final String runtime;
  final int generation;
  final int turn;
  final int revision;
  @override
  bool operator ==(Object other) =>
      other is StopTarget &&
      key == other.key &&
      runtime == other.runtime &&
      generation == other.generation &&
      turn == other.turn &&
      revision == other.revision;
  @override
  int get hashCode => Object.hash(key, runtime, generation, turn, revision);
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
        notificationUnfollowed: json['notificationUnfollowed'] == true,
        attachments: [
          for (final a in (json['attachments'] as List? ?? const []))
            Attachment.fromJson(Map<String, Object?>.from(a as Map)),
        ],
      ),
      'resp' => ResponseItem(turn, json['text'] as String),
      'ask' => QuestionItem.fromJson(json),
      _ => ActivityItem.fromJson(json),
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
    this.notificationUnfollowed = false,
    this.attachments = const [],
  });
  final String text;
  final OperationKey operation;
  final int? userRowId;
  final bool notificationUnfollowed;
  final List<Attachment> attachments;
  UserItem withRow(int row) => UserItem(
    turn,
    text,
    operation: operation,
    userRowId: row,
    attachments: attachments,
    notificationUnfollowed: notificationUnfollowed,
  );
  @override
  Map<String, Object?> toJson() => {
    'k': 'user',
    'turn': turn,
    'text': text,
    'op': operation.value,
    'row': userRowId,
    'notificationUnfollowed': notificationUnfollowed,
    'attachments': [for (final a in attachments) a.toJson()],
  };
}

class ResponseItem extends TimelineItem {
  const ResponseItem(super.turn, this.text);
  final String text;
  @override
  Map<String, Object?> toJson() => {'k': 'resp', 'turn': turn, 'text': text};
}

/// Cycle d'une question de Hermes (`clarify`) vu par l'app. Seuls `sent` →
/// `confirmed` (fin de l'outil `clarify`) et les fermetures viennent du
/// serveur ; `sending`, `sent` et `unknown` décrivent la réponse locale.
enum QuestionState {
  open,
  sending,
  sent,
  confirmed,
  unknown,
  expired,
  cancelled,
  closed;

  /// Plus aucune saisie ni réouverture possible.
  bool get settled =>
      this == confirmed ||
      this == expired ||
      this == cancelled ||
      this == closed;
}

/// Une question telle qu'émise (`questions[]`), choix inclus, sans reformulation.
class ClarifyQuestion {
  const ClarifyQuestion({
    required this.qid,
    required this.text,
    this.choices = const [],
    this.multiSelect = false,
  });
  final String qid;
  final String text;
  final List<String> choices;
  final bool multiSelect;

  Map<String, Object?> toJson() => {
    'qid': qid,
    'question': text,
    'choices': choices,
    'multi_select': multiSelect,
  };

  /// `null` si l'entrée n'est pas exploitable (pas d'identifiant ni de texte).
  static ClarifyQuestion? fromJson(Object? json) {
    if (json is! Map) return null;
    final qid = json['qid'];
    final text = json['question'];
    if (qid is! String || qid.isEmpty || text is! String || text.isEmpty) {
      return null;
    }
    final choices = json['choices'];
    return ClarifyQuestion(
      qid: qid,
      text: text,
      choices: [
        if (choices is List)
          for (final c in choices)
            if (c is String && c.isNotEmpty) c,
      ],
      multiSelect: json['multi_select'] == true,
    );
  }
}

/// Carte « question » : une requête serveur `clarify` (id `srq-…`).
class QuestionItem extends TimelineItem {
  const QuestionItem(
    super.turn, {
    required this.requestId,
    required this.questions,
    this.state = QuestionState.open,
    this.previousUnanswered = false,
  });
  final String requestId;
  final List<ClarifyQuestion> questions;
  final QuestionState state;

  /// Rouverte par `open_requests` alors qu'une réponse locale existait.
  final bool previousUnanswered;

  QuestionItem copyWith({QuestionState? state, bool? previousUnanswered}) =>
      QuestionItem(
        turn,
        requestId: requestId,
        questions: questions,
        state: state ?? this.state,
        previousUnanswered: previousUnanswered ?? this.previousUnanswered,
      );

  static QuestionItem fromJson(Map<String, Object?> json) => QuestionItem(
    json['turn'] as int,
    requestId: json['id'] as String,
    questions: [
      for (final q in (json['questions'] as List? ?? const []))
        ?ClarifyQuestion.fromJson(q),
    ],
    state:
        QuestionState.values.asNameMap()[json['state']] ?? QuestionState.closed,
    previousUnanswered: json['previousUnanswered'] == true,
  );

  @override
  Map<String, Object?> toJson() => {
    'k': 'ask',
    'turn': turn,
    'id': requestId,
    'questions': [for (final q in questions) q.toJson()],
    'state': state.name,
    'previousUnanswered': previousUnanswered,
  };
}

/// Réponse aux questions de Hermes, depuis la carte ; aucun appel direct.
abstract interface class InterventionGateway {
  /// Enregistre la réponse ([answers] : `qid` → texte non vide) puis l'envoie
  /// une seule fois. Lève `AppError` si rien n'a pu partir.
  Future<void> answer(
    TimelineKey key,
    String requestId,
    Map<String, String> answers,
  );
}

/// Ligne d'activité générique ; [kind] vient de la table de mapping.
class ActivityItem extends TimelineItem {
  const ActivityItem(
    super.turn,
    this.kind, {
    this.toolId,
    this.started = false,
    this.completed = false,
    this.eventKey,
    this.responseReceived = false,
    this.details = const {},
  });
  final ActivityKind kind;
  final String? toolId;
  final bool started;
  final bool completed;
  final String? eventKey;
  final bool responseReceived;

  /// Champs autorisés reçus sur les événements d’outil connus. Les nulls
  /// retirent un champ lors de la fusion, sans rester dans la projection.
  final Map<String, Object?> details;

  ActivityItem copyWith({
    int? turn,
    bool? started,
    bool? completed,
    bool? responseReceived,
    Map<String, Object?>? detailPatch,
  }) => ActivityItem(
    turn ?? this.turn,
    kind,
    toolId: toolId,
    started: started ?? this.started,
    completed: completed ?? this.completed,
    eventKey: eventKey,
    responseReceived: responseReceived ?? this.responseReceived,
    details: Map.unmodifiable(
      ActivityDetailFields.decode({...details, ...?detailPatch})
        ..removeWhere((k, v) => v == null),
    ),
  );

  static ActivityItem fromJson(Map<String, Object?> json) {
    // Une ancienne projection ne prouve ni début, ni fin, ni famille fiable.
    final modern = json['activityVersion'] == 1;
    return ActivityItem(
      json['turn'] as int,
      modern ? ActivityKind.decode(json['kind']) : ActivityKind.unknown,
      toolId: modern ? json['toolId'] as String? : null,
      started: modern && json['started'] == true,
      completed: modern && json['completed'] == true,
      eventKey: modern ? json['eventKey'] as String? : null,
      responseReceived: modern && json['responseReceived'] == true,
      details: modern && json['details'] is Map
          ? Map.unmodifiable(
              ActivityDetailFields.decode(
                Map<String, Object?>.from(json['details'] as Map),
              )..removeWhere((k, v) => v == null),
            )
          : const {},
    );
  }

  @override
  Map<String, Object?> toJson() => {
    'k': 'act',
    'turn': turn,
    'kind': kind.name,
    'activityVersion': 1,
    'toolId': toolId,
    'started': started,
    'completed': completed,
    'eventKey': eventKey,
    'responseReceived': responseReceived,
    if (details.isNotEmpty) 'details': details,
  };
}

/// Frontière du contrat : aucune clé arbitraire ne devient un détail.
abstract final class ActivityDetailFields {
  static Map<String, Object?> decode(Map<String, Object?> payload) => {
    for (final field in const [
      'name',
      'context',
      'args',
      'args_text',
      'preview',
      'result',
      'result_text',
      'inline_diff',
    ])
      if (payload.containsKey(field) &&
          (payload[field] == null ||
              (field == 'args' || field == 'result'
                  ? _json(payload[field])
                  : payload[field] is String)))
        field: _freeze(payload[field]),
  };

  static bool _json(Object? value) =>
      value == null ||
      value is String ||
      value is bool ||
      value is num && value.isFinite ||
      value is List && value.every(_json) ||
      value is Map &&
          value.entries.every((e) => e.key is String && _json(e.value));

  static Object? _freeze(Object? value) => switch (value) {
    Map() => Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freeze(entry.value),
    }),
    List() => List<Object?>.unmodifiable(value.map(_freeze)),
    _ => value,
  };
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
    this.companionPhase = CompanionPhase.neutral,
  });
  final List<TimelineItem> items;
  final CompanionPhase companionPhase;

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
    CompanionPhase? companionPhase,
  }) => TimelineProjection(
    items: items ?? this.items,
    workState: workState ?? this.workState,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
    turns: turns ?? this.turns,
    userTurns: userTurns ?? this.userTurns,
    replayEpoch: replayEpoch ?? this.replayEpoch,
    seq: resetSeq ? null : seq ?? this.seq,
    companionPhase: companionPhase ?? this.companionPhase,
  );

  bool get inFlight =>
      workState == WorkState.sending ||
      workState == WorkState.running ||
      workState == WorkState.waitingInput;

  /// Le tour serveur est en cours (travail ou attente d'une réponse).
  bool get working =>
      workState == WorkState.running || workState == WorkState.waitingInput;

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
    this.openRequests,
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

  /// Requêtes serveur encore ouvertes (`open_requests`, entrées
  /// `{id, method, params}`) ; `null` si le serveur n'en dit rien.
  final List<Map<String, Object?>>? openRequests;

  Resumed at(int generation) => Resumed(
    runtime: runtime,
    running: running,
    inflight: inflight,
    partial: partial,
    queued: queued,
    generation: generation,
    openRequests: openRequests,
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

  /// La dernière reprise de ce fil a échoué (la projection affichée peut être
  /// ancienne) ; revient à faux dès qu'une reprise aboutit.
  bool resumeFailed(TimelineKey key);

  /// Conversations du [profile] dans l'ordre du serveur ; jamais mises en
  /// cache : une erreur lève, aucune liste périmée n'est rendue.
  Future<List<SessionSummary>> sessions(
    ConnectionKey connection,
    ProfileKey profile,
  );

  /// Clé dont la projection a changé.
  Stream<TimelineKey> get changes;
  Future<void> dispose();
}
