// Libellés d'interface (UX-DR22), séparés des styles.
// Vocabulaire du quotidien : pas de jargon technique en avant.
import '../models/timeline.dart';
import '../models/attachment.dart';

abstract final class Content {
  static const notificationUnfollowed = 'Notification non suivie';
  static const notifications = 'Notifications de fin de travail';
  static const observerOrigin = 'Adresse HTTPS de l’observateur';
  static const observerBearer = 'Credential de l’observateur';
  static const notificationSave = 'Enregistrer l’observateur';
  static const notificationEnable = 'Activer les notifications';
  static const notificationDisable = 'Désactiver et révoquer';
  static const notificationHealth = 'Vérifier la santé de l’observateur';
  static const notificationEnabled = 'Suivi activé pour cette connexion';
  static const notificationDisabled = 'Suivi désactivé pour cette connexion';
  static const notificationRevocationHint =
      'Si l’observateur est indisponible lors de la désactivation, la révocation distante reprend à la prochaine ouverture.';
  static const notificationPrerequisites =
      'Les services Google et la permission Android sont nécessaires. Vérifie aussi les réglages de batterie. Après un arrêt forcé, rouvre l’application pour reprendre la réception. Le silence ne prouve pas que le travail continue.';
  static const notificationConfigError =
      'Configuration invalide ou enregistrement impossible. Utilise une adresse HTTPS et un credential distinct de celui de Hermes.';
  static String notificationDevice(String value) => switch (value) {
    'ready' => 'Téléphone : notifications autorisées',
    'denied' => 'Téléphone : permission refusée. Autorise les notifications dans les réglages Android.',
    'unavailable' => 'Téléphone : token indisponible. Vérifie les services Google et la connexion.',
    _ => 'Téléphone : Firebase non configuré. L’application reste utilisable ; la configuration Android reste à installer.',
  };
  static String observerHealth(String value) => switch (value) {
    'unchecked' => 'Observateur : santé non vérifiée',
    'ok' => 'Observateur : disponible',
    'degraded' => 'Observateur : dégradé',
    'unconfigured' => 'Observateur : non configuré',
    _ => 'Observateur : indisponible ou credential refusé',
  };
  static const attachments = 'Pièces jointes';
  static String attachmentPreview(String name) => 'Aperçu de $name';
  static const attachmentText = 'Texte';
  static const attachmentPdf = 'PDF';
  static const attachmentOffice = 'Word';
  static const attach = 'Joindre';
  static const photos = 'Photos';
  static const files = 'Fichiers';
  static const attachmentSelected = 'Sélectionné localement';
  static const attachmentMissing =
      'Copie locale absente. Retirez cette pièce puis sélectionnez-la à nouveau.';
  static const attachmentSendBlocked = attachmentRetryRequired;
  static const attachmentRetryRequired =
      'Une pièce doit être retirée ou faire l’objet d’un nouvel essai explicite.';
  static const attachmentVisionUnknown =
      'La réception de l’image peut être confirmée ; son analyse dépend du profil Hermes.';
  static const attachmentRetry = 'Réessayer';
  static String retryAttachment(String name) => 'Réessayer l’envoi de $name';
  static String attachmentStatus(
    AttachmentState state,
    bool sent,
    String? errorCode,
  ) => switch (state) {
    AttachmentState.selected => attachmentSelected,
    AttachmentState.uploading => 'Téléversement en cours',
    AttachmentState.uploaded => 'Téléversé, réception à vérifier',
    AttachmentState.received => 'Reçu dans la conversation',
    AttachmentState.failed =>
      'Envoi refusé : ${error(errorCode ?? 'attachment.refused')}',
    AttachmentState.uncertain =>
      'Réception incertaine : ${error(errorCode ?? 'attachment.unknown')}',
  };
  static const attachmentFormats =
      'Photos (PNG, JPEG), texte (.txt), PDF et Word (.docx).';
  static const attachmentLoading = 'Copie de la pièce jointe…';
  static const remove = 'Retirer';
  static String removeAttachment(String name) => 'Retirer $name';
  static String fileSize(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(2)} Mo ($bytes octets)';
  static String attachmentTypeRefused(String type) =>
      'Type non pris en charge : $type.';
  static const attachmentSizeRefused =
      'Fichier trop volumineux. Choisissez un fichier plus léger.';
  static String attachmentCountLimit(int count) =>
      '$count ${count == 1 ? 'pièce' : 'pièces'} maximum';
  static const detailName = 'Nom';
  static const detailContext = 'Contexte';
  static const detailArguments = 'Arguments';
  static const detailOutput = 'Sortie';
  static const detailDiff = 'Différence';
  static const detailError = 'Erreur';
  static const expandDetails = 'Déplier les détails reçus';
  static const collapseDetails = 'Replier les détails reçus';
  static const backgroundTitle = 'Arrière-plan';
  static const backgroundPreview = 'Aperçu';
  static const backgroundApply = 'Appliquer';
  static const backgroundCancel = 'Annuler';
  static const backgroundSaving = 'Enregistrement…';
  static const backgroundLoading = 'Chargement de l’arrière-plan…';
  static const backgroundReadError =
      'Impossible de lire l’arrière-plan enregistré.';
  static const backgroundSaveError =
      'Impossible d’enregistrer l’arrière-plan. Réessayez ou annulez.';
  static const backgroundRetry = 'Réessayer';
  static const lavenderPeach = 'Lavande et pêche';
  static const mintSky = 'Menthe et ciel';
  static const roseLilac = 'Rose et lilas';
  static const peachSun = 'Pêche et soleil';
  static const oceanMist = 'Océan et brume';
  static const sageSand = 'Sauge et sable';
  static const coralRose = 'Corail et rose';
  static const pearl = 'Gris perle';
  static const backgroundSelected = 'Sélectionnée';
  static const companionName = 'Otc';
  static const companionFallback = 'Compagnon';
  static const pauseCompanion = 'Mettre les animations en pause';
  static const resumeCompanion = 'Reprendre les animations';
  static String tickleCompanion(String name) => 'Chatouiller $name';
  static const appTitle = 'Hermes Mobile';
  static const homePlaceholder = 'Bienvenue dans Hermes Mobile';
  static const connectTitle = 'Connecter Hermes';
  static const originLabel = 'Adresse du serveur';
  static const originHint = 'http://mon-serveur.ts.net:9119';
  static const originHelp =
      'Scannez le QR avec la caméra Android ou saisissez l’adresse.';
  static const reviewOrigin = 'Vérifier l’adresse';
  static const confirmOrigin = 'Confirmer ce serveur';
  static const confirmationHelp =
      'Vérifiez cette adresse avant de saisir votre mot de passe.';
  static const passwordLabel = 'Mot de passe Hermes';
  static const signIn = 'Se connecter';
  static const working = 'Connexion en cours…';
  static const changeServer = 'Changer de serveur';
  static const profilesTitle = 'Mes profils';
  static const refresh = 'Actualiser les profils';
  static const retry = 'Réessayer la connexion';
  static const loadingProfiles = 'Chargement des profils…';
  static const refreshingProfiles = 'Actualisation des profils…';
  static const emptyProfiles = 'Aucun profil disponible sur ce serveur.';
  static const profilesError = 'Impossible de charger les profils.';
  static const selected = 'Profil sélectionné';
  static const localSelection =
      'Ce choix est mémorisé uniquement sur ce téléphone.';
  static const capabilitiesTitle = 'Fonctions disponibles';
  static const profilesSection = 'Profils';
  static const serverSection = 'Serveur';
  static const wordmark = 'Hermes';
  static const greeting = 'Comment puis-je t’aider ?';
  static const suggestions = [
    'Résume-moi un long texte',
    'Écris un script bash',
    'Aide-moi à planifier ma semaine',
    'Explique-moi un concept simplement',
  ];
  static const unverified = 'Non vérifiée';
  static const missing = 'Indisponible';
  static const acceptanceOpen =
      'La validation des fonctions requises reste ouverte.';
  static const startupError =
      'Impossible d’ouvrir le stockage sécurisé de l’application.';
  static const newConversation = 'Nouvelle conversation';
  static const composerLabel = 'Votre demande';
  static const send = 'Envoyer';
  static const sendEmpty = 'Saisissez votre demande pour pouvoir l’envoyer.';
  static const sendCapabilityMissing =
      'Envoi indisponible : ce serveur ne prend pas en charge cette conversation.';
  static const sendCapabilityPending =
      'Envoi indisponible : vérification du serveur en cours.';
  static const sending = 'Envoi en cours…';
  static const sendAccepted = 'Demande acceptée par Hermes.';
  static const turnActive = 'Hermes traite encore la demande précédente.';
  static String sendLink(String label) => 'Envoi indisponible : $label.';
  static const timelineTitle = 'Conversation';
  static const yourRequest = 'Votre demande';
  static const hermesReply = 'Réponse de Hermes';
  static const activityTool = 'Appel d’outil';
  static const activityCode = 'Écriture du code';
  static const activityUnknown = 'Événement non reconnu';
  static String activityLabel(ActivityKind kind) => switch (kind) {
    ActivityKind.tool => activityTool,
    ActivityKind.code => activityCode,
    ActivityKind.fileCreate => 'Création du fichier',
    ActivityKind.webSearch => 'Recherche sur le web',
    ActivityKind.fileRead => 'Lecture du fichier',
    ActivityKind.command => 'Exécution d’une commande',
    ActivityKind.webBrowse => 'Navigation sur le web',
    ActivityKind.fileEdit => 'Modification du fichier',
    ActivityKind.fileSearch => 'Recherche de fichiers',
    ActivityKind.imageCreate => 'Création d’une image',
    ActivityKind.memory => 'Mémorisation',
    ActivityKind.delegate => 'Travail en parallèle',
    ActivityKind.organize => 'Organisation du travail',
    ActivityKind.imageAnalyze => 'Analyse de l’image',
    ActivityKind.skill => 'Consultation d’un savoir-faire',
    ActivityKind.schedule => 'Programmation',
    ActivityKind.preparation => 'Préparation de la réponse',
    ActivityKind.unknown => activityUnknown,
  };
  static const activityEnd = 'Fin reçue';
  static const activityEndAccessible = 'Fin d’action reçue';
  static String activitySummary(int count, int pending) => pending == 0
      ? '$count actions terminées'
      : '$count actions · $pending en cours';
  static const expandActivities = 'Déplier les activités';
  static const collapseActivities = 'Replier les activités';
  static const workSending = 'Envoi…';
  static const workRunning = 'Hermes travaille…';
  static const workSucceeded = 'Terminé';
  static const workFailed = 'Erreur';
  static const workStopped = 'Arrêt confirmé';
  static const stop = 'Arrêter';
  static const stopRequested = 'Arrêt demandé';
  static const stopPreparing = 'Préparation de l’arrêt…';
  static const stopUnknown =
      'Issue de l’arrêt inconnue. Aucun renvoi automatique.';
  static const stopDemo = 'Arrêt du travail — démonstration fictive';
  static const stopReminder =
      'L’arrêt n’annule pas les actions déjà effectuées.';
  static const workUnknown = 'Non synchronisé';
  static const draftKept = 'Votre texte reste affiché sur cet écran.';
  static String draftProfile(String name) => 'Profil : $name';
  static const chooseProfileHint = 'Ouvre la liste des profils';
  static const chooseProfile = 'Choisir le profil';
  static const conversations = 'Conversations';
  static const openConversationsHint = 'Ouvre les conversations de ce profil';
  static String writeTo(String name) => 'Écrire à $name';
  static String conversationCount(int n) =>
      n == 1 ? '1 conversation' : '$n conversations';

  // Réglages d'un profil (refonte 2026-10-23).
  static const profileSettings = 'Réglages du profil';
  static const nameFromHermes = 'Nom repris du profil Hermes';
  static const appearance = 'Apparence';
  static const profileColor = 'Couleur du profil';
  static const profileColorHint = 'Avatar, bouton d’envoi, repères';
  static const profileColorFailed = 'Couleur non enregistrée. Réessaie.';
  static const profileSection = 'Profil';
  static const identifier = 'Identifiant';
  static const connectionRow = 'Connexion';
  static const change = 'Changer';
  static const allProfiles = 'Tous les profils';
  static String accentName(String id) => switch (id) {
    'indigo' => 'Indigo',
    'blue' => 'Bleu',
    'violet' => 'Violet',
    'teal' => 'Sarcelle',
    'orange' => 'Orange',
    'raspberry' => 'Framboise',
    _ => id,
  };
  static const historyLoading = 'Chargement des conversations…';
  static const historyEmpty = 'Aucune conversation pour ce profil';
  static const historyError =
      'Impossible de charger les conversations de ce profil.';
  static const refreshHistory = 'Actualiser la liste';
  static const historyLimitNote =
      'Seules les conversations les plus récentes sont affichées.';
  static const retryList = 'Réessayer';
  static const untitledConversation = 'Conversation sans titre';
  static const openingConversation = 'Ouverture de la conversation…';
  static const resumeFailed =
      'Impossible de retrouver la suite de cette conversation. Votre texte est conservé.';
  static String messageCount(int count) =>
      count == 1 ? '1 message' : '$count messages';

  /// Date locale lisible : jour/mois/année à heure:minute.
  static String historyDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = date.toLocal();
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}';
  }

  /// Tranche de date du menu latéral (style Grok), en jours calendaires.
  static String historyBucket(DateTime date, DateTime now) {
    final d = date.toLocal();
    final n = now.toLocal();
    final days = DateTime(
      n.year,
      n.month,
      n.day,
    ).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return 'Aujourd’hui';
    if (days == 1) return 'Hier';
    if (days < 7) return '7 derniers jours';
    if (days < 30) return '30 derniers jours';
    return 'Plus ancien';
  }

  static const settings = 'Profils et réglages';
  static const home = 'Accueil';
  static const homeNoConversation = 'Aucune conversation pour l’instant';

  /// Heure si aujourd'hui, sinon jour/mois (liste d'accueil).
  static String homeTime(DateTime date, DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = date.toLocal();
    final n = now.toLocal();
    return d.year == n.year && d.month == n.month && d.day == n.day
        ? '${two(d.hour)}:${two(d.minute)}'
        : '${two(d.day)}/${two(d.month)}';
  }

  static const profileFixture = 'Principal';
  static const profileFixtureKey = 'default';
  static String profileName(String label, String key) =>
      label == key ? label : '$label ($key)';
  static String capability(String name) => switch (name) {
    'profiles' => 'Liste des profils',
    'websocket' => 'Connexion en direct',
    'replay_epoch' => 'Reprise après redémarrage',
    'change_events' => 'Signalement des changements',
    'heartbeat' => 'Vérification de présence',
    'per_session_exclusive_submit' => 'Envoi exclusif par conversation',
    'session.events.since' => 'Reprise des événements',
    'session.create.idempotency_key' => 'Création sans doublon',
    'file.attach' => 'Pièces jointes',
    'conversation' => 'Conversations',
    _ => name,
  };
  static String error(String code) => switch (code) {
    'attachment.permission' => 'L’accès aux fichiers a été refusé. Autorisez-le dans les réglages puis réessayez.',
    'attachment.selection' =>
      'La sélection a échoué. Réessayez de choisir votre fichier.',
    'attachment.type' => 'Ce type de fichier n’est pas pris en charge.',
    'attachment.size' => attachmentSizeRefused,
    'attachment.busy' =>
      'Attendez la fin de l’opération en cours pour modifier les pièces.',
    'attachment.retry_required' => attachmentRetryRequired,
    'attachment.refused' => 'Hermes a refusé cette pièce.',
    'attachment.unknown' => 'Le résultat du téléversement est incertain. Vérifiez la conversation avant un nouvel essai.',
    'attachment.missing' => attachmentMissing,
    'attachment.retained' => 'Cette copie reste conservée pour vérifier la réception dans la conversation.',
    'attachment.scope_changed' => 'La conversation cible a changé. Retirez cette pièce et sélectionnez-la de nouveau.',
    'attachment.send_blocked' => attachmentSendBlocked,
    'stop.stale' => 'La cible de l’arrêt a changé. Aucun arrêt transmis.',
    'stop.not_interrupted' =>
      'Hermes n’a pas accepté l’arrêt. Le travail reste suivi.',
    'stop.unknown' => stopUnknown,
    'connection.invalid_origin' => 'Adresse invalide. Utilisez HTTPS ou HTTP sur un sous-domaine ts.net, sans chemin ni identifiants.',
    'auth.refused' => 'Authentification refusée. Vérifiez votre mot de passe.',
    'auth.password_required' => 'Saisissez votre mot de passe Hermes.',
    'auth.invalid_session' =>
      'La réponse de connexion ne contient pas de session utilisable.',
    'contract.method_missing' => 'Cette fonction est absente du serveur.',
    'contract.capabilities_timeout' => 'La vérification des fonctions du serveur a expiré. Réessayez la connexion.',
    'contract.rpc_failed' => 'Le serveur ne peut pas vérifier cette fonction.',
    'contract.invalid_response' =>
      'La réponse du serveur n’est pas compatible.',
    'transport.redirect' =>
      'Le serveur redirige la connexion. Vérifiez son adresse.',
    'storage.unavailable' => startupError,
    'draft.profile_busy' => 'Un envoi est en cours sur l’autre brouillon de ce profil. Réessayez après son envoi.',
    'draft.not_found' => 'Ce brouillon est introuvable.',
    'send.unknown' => 'Résultat incertain : vérifiez la conversation avant de renvoyer. Votre texte est conservé.',
    'send.turn_active' => turnActive,
    'send.not_received' => 'Hermes n’affiche pas cette demande. Vérifiez la conversation, puis renvoyez-la si besoin. Votre texte est conservé.',
    'turn.error' =>
      'Hermes n’a pas pu terminer cette réponse. Votre brouillon reste intact.',
    'send.unavailable' =>
      'Hermes n’est pas joignable pour le moment. Votre texte est conservé.',
    'transport.offline' =>
      'Hermes n’est pas joignable pour le moment. Votre texte est conservé.',
    'transport.unreachable' =>
      'La conversation n’a pas pu être préparée. Votre texte est conservé.',
    'rpc.4009' => 'La conversation est occupée. Votre texte est conservé.',
    'rpc.4090' => 'Trop de conversations sont actives sur Hermes. Votre texte est conservé.',
    'rpc.5035' => 'Hermes s’arrête ou redémarre. Votre texte est conservé.',
    'rpc.4064' =>
      'Ce profil n’existe plus sur le serveur. Votre texte est conservé.',
    final code when code.startsWith('rpc.') =>
      'Hermes a refusé la demande. Votre texte est conservé.',
    _ => 'Serveur inaccessible. Vérifiez votre connexion et réessayez.',
  };
}

/// Libellés de l'indicateur de connexion (utilisés à partir de la story 1.6).
abstract final class ConnectionLabels {
  static const connected = 'Connecté';
  static const resyncing = 'Resynchronisation';
  static const offline = 'Hors ligne';
}

/// Libellés et données fictives de la galerie de composants.
abstract final class GalleryContent {
  static const conversationCompanionSection = 'Otc pendant la réponse';
  static const companionStart = 'Démarrage confirmé';
  static const companionText = 'Réception de texte';
  static const companionRestore = 'Reprendre avec texte courant';
  static const companionSuspend = 'Masquer la surface';
  static const companionShow = 'Afficher la surface';
  static const backgroundFailure = 'Simuler un échec puis réessayer';
  static const rabbitSection = 'Compagnon lapin';
  static const rabbitName = 'Otc';
  static const rabbitLarge = '180 px';
  static const rabbitCompact = '64 px';
  static const rabbitMinimum = '48 px';
  static const pauseRabbit = 'Mettre les animations en pause';
  static const resumeRabbit = 'Reprendre les animations';
  static const title = 'Galerie de composants';

  static const variantLight = 'Clair';
  static const variantDark = 'Sombre';
  static const variantLargeText = 'Texte agrandi 200 %';
  static const variantReducedMotion = 'Mouvement réduit';

  static const statusLabelSection = 'Indicateur d\'état';
  static const sectionCardSection = 'Carte de section';
  static const composerSection = 'Zone de saisie';
  static const messageSection = 'Message';
  static const activitySection = 'Ligne d’activité';
  static const activitySynthetic = 'Activités fictives · aucun appel Hermes';
  static const activityAnimated = 'Animé';
  static const activityStationary = 'Immobile';
  static const activityDemonstration =
      'Démonstration du catalogue · familles fictives';
  static const activityRealContract =
      'Scénario fictif · le contrat réel conserve outil et événement inconnu';
  static const activityPreparationNote =
      'Préparation : démonstration uniquement ; en conversation, Otc conserve ce rôle.';
  static const activityCatalog = 'Catalogue d’illustrations';
  static String activityCatalogItem(ActivityKind kind) =>
      '${Content.activityLabel(kind)} (${kind.name})';
  static const pauseActivities = 'Mettre les illustrations en pause';
  static const resumeActivities = 'Reprendre les illustrations';
  static const activitySecond = 'Deuxième ID';
  static const activityComplete = 'Recevoir la fin';
  static const activityCode = 'Ajouter code fictif';
  static const activityUnknown = 'Événement inconnu';
  static const activityReply = 'Recevoir une réponse';
  static const activityReplyText =
      'Voici la réponse fictive. Une action reste sans fin confirmée même pendant la réponse.';
  static const activityReset = 'Recommencer';
  static const workStateSection = 'États du travail';
  static const sampleRequest = 'Peux-tu résumer ce fichier ? 🙂';
  static const sampleReply =
      '# Résumé\n\n- Premier point 🚀\n- Deuxième point en **gras**\n\n'
      '```dart\nfinal resume = fichier.lignes.where((l) => l.isNotEmpty).map((l) => l.trim()).join("-");\n```';

  static const historySection = 'Historique';
  static const sampleSessionTitle = 'Résumé du contrat';
  static const sampleSessionPreview = 'Peux-tu résumer ce fichier ?';

  static const sampleCardTitle = 'Mes profils';
  static const sampleProfiles = ['Profil principal', 'Profil travail'];
}
