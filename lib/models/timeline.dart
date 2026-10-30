import 'connection.dart';
import 'attachment.dart';
import 'draft.dart';
import 'history.dart';
import 'profile.dart';

/// État du travail distant ; distinct de l'état de la connexion.
/// `waitingInput` : le tour est en cours et Hermes attend une réponse (6.2) ;
/// `waitingApproval` : il attend une autorisation (6.3).
enum WorkState {
  sending,
  running,
  waitingInput,
  waitingApproval,
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
      'approve' => ApprovalItem.fromJson(json),
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

/// Cycle d'une intervention de Hermes (question `clarify` ou autorisation
/// `approval`) vue par l'app. Seuls `sent` → `confirmed` (fin de l'outil qui
/// attendait) et les fermetures viennent du serveur ; `sending`, `sent` et
/// `unknown` décrivent la réponse locale.
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

/// Carte d'intervention : une requête serveur (id `srq-…`) dans le fil.
sealed class InterventionItem extends TimelineItem {
  const InterventionItem(
    super.turn, {
    required this.requestId,
    this.state = QuestionState.open,
    this.previousUnanswered = false,
  });
  final String requestId;
  final QuestionState state;

  /// Rouverte par `open_requests` alors qu'une réponse locale existait.
  final bool previousUnanswered;

  InterventionItem copyWith({QuestionState? state, bool? previousUnanswered});

  /// Même carte rattachée au tour [turn] (reprise par snapshot).
  InterventionItem atTurn(int turn);
}

/// Carte « question » : une requête serveur `clarify`.
class QuestionItem extends InterventionItem {
  const QuestionItem(
    super.turn, {
    required super.requestId,
    required this.questions,
    super.state,
    super.previousUnanswered,
  });
  final List<ClarifyQuestion> questions;

  @override
  QuestionItem copyWith({QuestionState? state, bool? previousUnanswered}) =>
      QuestionItem(
        turn,
        requestId: requestId,
        questions: questions,
        state: state ?? this.state,
        previousUnanswered: previousUnanswered ?? this.previousUnanswered,
      );

  @override
  QuestionItem atTurn(int turn) => QuestionItem(
    turn,
    requestId: requestId,
    questions: questions,
    state: state,
    previousUnanswered: previousUnanswered,
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

/// Décisions que l'app envoie ; `session` et `always` ne sont jamais proposés
/// ni envoyés, même quand Hermes les permet.
abstract final class ApprovalChoice {
  static const once = 'once';
  static const deny = 'deny';
  static const offered = [once, deny];
}

/// Carte « autorisation » : une requête serveur `approval`, champs tels
/// qu'émis (commande déjà expurgée par le serveur).
class ApprovalItem extends InterventionItem {
  const ApprovalItem(
    super.turn, {
    required super.requestId,
    required this.description,
    required this.command,
    this.choices = const [],
    this.allowSession = false,
    this.allowPermanent = false,
    this.choice,
    this.blocked,
    super.state,
    super.previousUnanswered,
  });
  final String description;
  final String command;

  /// Choix permis par Hermes (`once`, `session`, `always`, `deny`), gardés
  /// pour mémoire ; seuls `once` et `deny` sont proposés.
  final List<String> choices;
  final bool allowSession;
  final bool allowPermanent;

  /// Dernière décision envoyée (`once` ou `deny`).
  final String? choice;

  /// Posé par le `tool.complete` qui confirme : `true` si
  /// `result.status = "blocked"` (refusée, la commande n'a pas été lancée).
  final bool? blocked;

  @override
  ApprovalItem copyWith({
    QuestionState? state,
    bool? previousUnanswered,
    String? choice,
    bool? blocked,
  }) => ApprovalItem(
    turn,
    requestId: requestId,
    description: description,
    command: command,
    choices: choices,
    allowSession: allowSession,
    allowPermanent: allowPermanent,
    choice: choice ?? this.choice,
    blocked: blocked ?? this.blocked,
    state: state ?? this.state,
    previousUnanswered: previousUnanswered ?? this.previousUnanswered,
  );

  @override
  ApprovalItem atTurn(int turn) => ApprovalItem(
    turn,
    requestId: requestId,
    description: description,
    command: command,
    choices: choices,
    allowSession: allowSession,
    allowPermanent: allowPermanent,
    choice: choice,
    blocked: blocked,
    state: state,
    previousUnanswered: previousUnanswered,
  );

  static ApprovalItem fromJson(Map<String, Object?> json) => ApprovalItem(
    json['turn'] as int,
    requestId: json['id'] as String,
    description: json['description'] as String? ?? '',
    command: json['command'] as String? ?? '',
    choices: [
      for (final c in (json['choices'] as List? ?? const []))
        if (c is String) c,
    ],
    allowSession: json['allowSession'] == true,
    allowPermanent: json['allowPermanent'] == true,
    choice: json['choice'] as String?,
    blocked: json['blocked'] as bool?,
    state:
        QuestionState.values.asNameMap()[json['state']] ?? QuestionState.closed,
    previousUnanswered: json['previousUnanswered'] == true,
  );

  @override
  Map<String, Object?> toJson() => {
    'k': 'approve',
    'turn': turn,
    'id': requestId,
    'description': description,
    'command': command,
    'choices': choices,
    'allowSession': allowSession,
    'allowPermanent': allowPermanent,
    'choice': choice,
    'blocked': blocked,
    'state': state.name,
    'previousUnanswered': previousUnanswered,
  };
}

/// Réponse aux interventions de Hermes, depuis la carte ; aucun appel direct.
abstract interface class InterventionGateway {
  /// Enregistre la réponse ([answers] : `qid` → texte non vide) puis l'envoie
  /// une seule fois. Lève `AppError` si rien n'a pu partir.
  Future<void> answer(
    TimelineKey key,
    String requestId,
    Map<String, String> answers,
  );

  /// Enregistre la décision ([choice] : `once` ou `deny`) puis l'envoie une
  /// seule fois. Lève `AppError` si rien n'a pu partir.
  Future<void> decide(TimelineKey key, String requestId, String choice);
}

/// Les trois modes d'autorisation connus de Hermes (`approvals.mode`).
abstract final class ApprovalMode {
  static const manual = 'manual';
  static const smart = 'smart';
  static const off = 'off';
  static const values = [manual, smart, off];
}

/// Mode d'autorisation d'un profil, lu et écrit sur Hermes à la demande
/// d'Alanc ; l'app n'en impose jamais aucun.
abstract interface class ApprovalModes {
  /// Valeur lue sur Hermes (une de [ApprovalMode.values]) ; lève si illisible.
  Future<String> read(ProfileKey profile);

  /// Écrit [mode] pour ce seul profil, puis rend la valeur relue.
  Future<String> write(ProfileKey profile, String mode);
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

  bool get inFlight => workState == WorkState.sending || working;

  /// Le tour serveur est en cours (travail ou attente d'une intervention).
  bool get working =>
      workState == WorkState.running ||
      workState == WorkState.waitingInput ||
      workState == WorkState.waitingApproval;

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
