// Libellés d'interface (UX-DR22), séparés des styles.
// Vocabulaire du quotidien : pas de jargon technique en avant.
import '../models/result.dart';
import '../models/timeline.dart';
import '../models/attachment.dart';
import '../models/room.dart';

abstract final class Content {
  static const rooms = 'Salons';
  static const roomRefresh = 'Actualiser le salon';
  static const roomStop = 'Arrêter le salon';
  static const roomDiscard = 'Abandonner';
  static const roomDiscardConfirm =
      'Abandonner cette tentative au résultat inconnu ? Cela ne peut pas annuler les effets déjà produits.';
  static const roomTaskContextMissing =
      'Résultat inconnu. Hermes ne fournit pas le contexte nécessaire pour abandonner cette tentative.';
  static const roomApprovalContextMissing =
      'Hermes ne fournit pas l’identité ou le contenu complet de cette demande. La décision est indisponible.';
  static String roomStopStatus(String state) => switch (state) {
    'confirmed' => 'Arrêt confirmé par Hermes',
    'unknown' =>
      'Arrêt à vérifier : la coupure réseau ne confirme pas l’arrêt.',
    _ => 'Arrêt demandé — en attente de confirmation de Hermes',
  };
  static String roomTaskStatus(String member, bool failed, String reason) =>
      '$member — ${failed ? 'Échec' : 'Résultat inconnu'}${reason.isEmpty ? '' : ' : $reason'}';
  static const roomNeedsUser = 'A besoin de toi';
  static const roomNotificationBody = 'Un agent a besoin de vous dans un salon';
  static const roomNotificationsPending =
      'Notifications app fermée : le relais Hermes reste à vérifier sur cette installation.';
  static const roomWaiting = 'Le salon attend votre réponse.';
  static const roomMentionHelp =
      'Sans mention, tous peuvent répondre. Utilisez @ pour choisir un agent.';
  static const roomSendUnavailable = 'Envoi indisponible sur ce Hermes.';
  static String roomSendStatus(String state) => switch (state) {
    'unknown' => 'Envoi à vérifier. Aucun renvoi automatique.',
    'refused' => 'Envoi refusé. Le brouillon est conservé.',
    _ => 'Envoi en cours…',
  };
  static const newRoom = 'Nouveau salon';
  static const roomCancel = 'Annuler';
  static const roomName = 'Nom du salon';
  static const roomMemberLimit = 'Choisissez entre 2 et 6 profils éligibles.';
  static const roomIneligible = 'Profil non annoncé comme éligible par Hermes';
  static const roomCreate = 'Créer le salon';
  static const roomVerify = 'Vérifier le résultat';
  static const roomsLoading = 'Chargement des salons…';
  static const roomsEmpty = 'Aucun salon pour le moment.';
  static const roomWorking = 'Des agents travaillent';
  static const roomPreparation =
      'Le salon est prêt. Le fil arrive dans la prochaine étape.';
  static String roomError(String code) => switch (code) {
    'room.stale' => 'Cette demande est devenue obsolète. Actualisez le salon avant de continuer.',
    'room.history' => 'Historique incomplet : actualisez le salon. Le fil précédent est conservé.',
    'storage.unavailable' =>
      'Enregistrement local impossible. Votre saisie reste affichée.',
    'room.driver_missing' => 'Le serveur Hermes annonce que le pilote des salons est indisponible. Modifier Bot Mode ne suffit pas à confirmer sa disponibilité.',
    'room.eligibility_unknown' => 'Hermes ne fournit pas la liste des profils utilisables en salon. L’app ne peut pas vérifier leur éligibilité.',
    'room.no_eligible' => 'Hermes annonce zéro profil utilisable en salon. La cause n’est pas précisée par le serveur.',
    'room.missing' =>
      'Cette fonction de salon n’est pas disponible sur ce Hermes.',
    'room.refused' =>
      'Hermes a refusé cette action. Votre saisie est conservée.',
    'room.busy' => 'Une action est déjà en cours dans ce salon.',
    'rpc.uncertain' =>
      'Résultat à vérifier : actualisez le salon. Aucun renvoi automatique.',
    'connection.mismatch' =>
      'Ce salon appartient à une autre connexion ou à un autre profil.',
    _ => 'Impossible de charger ou de modifier le salon. Réessayez.',
  };
  static String _roomFlag(bool? value) => value == null
      ? 'non annoncé'
      : value
      ? 'oui'
      : 'non';
  static String roomCapabilityDetails(RoomCapabilities caps) =>
      'Détails annoncés par Hermes\n'
      'Pilote salons : ${_roomFlag(caps.driver)}\n'
      'Processus persistant : ${_roomFlag(caps.persistentProcess)}\n'
      'Version du protocole : ${caps.protocolVersion ?? 'non annoncée'}\n'
      'Profils éligibles : ${caps.profilesAnnounced ? caps.profiles.length.toString() : 'liste non fournie'}\n'
      'Méthodes disponibles : ${caps.methods.length}';
  static const notificationUnfollowed = 'Notification non suivie';
  static const notificationTargetMissing =
      'Conversation de cette notification introuvable sur ce téléphone. Retour à l’accueil.';
  static const conversationDeleted =
      'Cette conversation a été supprimée. Retour à l’accueil.';
  static const notifications = 'Notifications de fin de travail';
  static const notificationEnable = 'Autoriser les notifications';
  static const notificationPrerequisites =
      'Les services Google et la permission Android sont nécessaires. Vérifie aussi les réglages de batterie. Après un arrêt forcé, rouvre l’application pour reprendre la réception. Le silence ne prouve pas que le travail continue.';
  static String notificationDevice(String value) => switch (value) {
    'ready' => 'Téléphone : notifications autorisées',
    'denied' => 'Téléphone : permission refusée. Autorise les notifications dans les réglages Android.',
    'unavailable' => 'Téléphone : token indisponible. Vérifie les services Google et la connexion.',
    _ => 'Téléphone : Firebase non configuré. L’application reste utilisable ; la configuration Android reste à installer.',
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
  static String compactFileSize(int bytes) => bytes < 1024
      ? '$bytes o'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} Ko'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
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
  static const workWaitingInput = 'Hermes attend ta réponse';
  static const workWaitingApproval = 'Hermes demande ton autorisation';

  // Question de Hermes (story 6.2).
  static const questionTitle = 'Question de Hermes';
  static const questionOpen = workWaitingInput;
  static const questionSending = 'Envoi de la réponse…';
  static const questionSent = 'Réponse envoyée';
  static const questionConfirmed = 'Réponse prise en compte';
  static const questionUnknown = 'Issue inconnue. Aucun renvoi automatique.';
  static const questionExpired = 'Question expirée';
  static const questionCancelled = 'Question annulée';
  static const questionClosed = 'Question close';
  static const questionPreviousUnanswered =
      'Réponse précédente non reçue. Tu peux répondre à nouveau.';
  static const questionMultiHint = 'Plusieurs choix possibles';
  static String questionFieldLabel(int index, int count) =>
      count == 1 ? 'Ta réponse' : 'Ta réponse à la question ${index + 1}';
  static const questionSend = 'Envoyer la réponse';
  static const questionIncomplete = 'Réponds à chaque question pour envoyer.';
  static const questionOffline = 'Réponse impossible hors connexion.';

  // Autorisation demandée par Hermes (story 6.3).
  static const approvalTitle = 'Autorisation demandée par Hermes';
  static const approvalOpen = workWaitingApproval;
  static const approvalSending = 'Envoi de la décision…';
  static const approvalSent = 'Décision envoyée';
  static const approvalAllowed = 'Autorisée';
  static const approvalDenied = 'Refusée, la commande n’a pas été lancée';
  static const approvalUnknown = questionUnknown;
  static const approvalExpired = 'Demande expirée';
  static const approvalCancelled = 'Demande annulée';
  static const approvalClosed = 'Demande close';
  static const approvalPreviousUnanswered =
      'Décision précédente non reçue. Tu peux décider à nouveau.';
  static const approvalCommand = 'Commande';
  static const approvalAllow = 'Autoriser';
  static const approvalDeny = 'Refuser';
  static const approvalAllowSemantics = 'Autoriser la commande';
  static const approvalDenySemantics = 'Refuser la commande';
  static const approvalOffline = 'Décision impossible hors connexion.';

  // Mode d'autorisation d'un profil (story 6.3).
  static const approvalModes = 'Autorisations';
  static const approvalModesHint =
      'Réglé sur Hermes pour ce profil. Le mode affiché est celui relu sur Hermes.';
  static String approvalModeName(String mode) => switch (mode) {
    'manual' => 'Toujours me demander',
    'smart' => 'Hermes juge',
    'off' => 'Ne jamais demander',
    _ => mode,
  };
  static String approvalModeHint(String mode) => switch (mode) {
    'manual' => 'Chaque commande signalée attend ta décision.',
    'smart' =>
      'Hermes approuve seul ce qu’il juge sûr et te demande quand il hésite.',
    'off' => approvalModeOffWarning,
    _ => '',
  };
  static const approvalModeOffWarning =
      'Hermes ne demandera plus aucune autorisation pour ce profil.';
  static const approvalModeUnreadable =
      'Mode illisible : impossible de le lire sur Hermes. Changement désactivé.';
  static const approvalModeRetry = 'Relire le mode';
  static const approvalModeOffTitle = 'Ne plus jamais demander ?';
  static const approvalModeOffConfirm = 'Ne plus demander';
  static const approvalModeCancel = 'Annuler';
  static const approvalModeRefused =
      'Mode inchangé : Hermes a refusé le changement.';
  static const approvalModeUnconfirmed =
      'Changement non confirmé par Hermes. Le mode affiché est celui relu.';

  // Fichier produit par Hermes (story 6.4).
  static const resultTitle = 'Fichier produit par Hermes';
  static const resultAvailable = 'Disponible';
  static const resultDownloading = 'Téléchargement…';
  static const resultDownloaded = 'Téléchargé';
  static const resultFailed = 'Échec';
  static const resultInterrupted = 'Échec — interrompu';
  static const resultDownload = 'Télécharger';
  static const resultRetry = 'Réessayer';
  static const resultOpen = 'Ouvrir';
  static String downloadResult(String name) => 'Télécharger le fichier $name';
  static String retryResult(String name) =>
      'Réessayer le téléchargement de $name';
  static String openResult(String name) => 'Ouvrir le fichier $name';
  static String resultStatus(ResultState state) => switch (state) {
    ResultState.available => resultAvailable,
    ResultState.downloading => resultDownloading,
    ResultState.downloaded => resultDownloaded,
    ResultState.failed => resultFailed,
    ResultState.interrupted => resultInterrupted,
  };
  static String resultType(String mediaType) => switch (mediaType) {
    'application/pdf' => attachmentPdf,
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
      attachmentOffice,
    'text/plain' => attachmentText,
    'text/markdown' => 'Markdown',
    'text/csv' => 'CSV',
    'application/json' => 'JSON',
    'application/zip' => 'Archive ZIP',
    'image/png' => 'Image PNG',
    'image/jpeg' => 'Image JPEG',
    'image/webp' => 'Image WebP',
    'image/gif' => 'Image GIF',
    _ => mediaType,
  };
  static String resultSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) {
      final ko = (bytes / 1024).toStringAsFixed(1);
      // Évite « 1024.0 Ko » juste sous le seuil du mégaoctet.
      if (ko != '1024.0') return '$ko Ko';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  /// Un échec de fichier ne reprend jamais un message d'un autre domaine
  /// (connexion, stockage, transport) qui parlerait d'autre chose.
  static String resultError(String code) =>
      code.startsWith('result.') ? error(code) : resultUnknown;

  static const resultOffline = 'Téléchargement impossible hors connexion';
  static const resultUnavailable =
      'Téléchargement indisponible sur ce serveur.';
  static const resultMissing = 'Ce fichier n’existe plus sur Hermes.';
  static const resultRefused =
      'Hermes a refusé le téléchargement de ce fichier.';
  static const resultOpenFailed =
      'Aucune application ne peut ouvrir ce fichier.';
  static const resultUnreadable =
      'Impossible de lire la copie locale. Téléchargez-la de nouveau.';
  static const resultWrite =
      'Impossible d’enregistrer le fichier sur le téléphone.';
  static const resultUnknown = 'Le fichier n’a pas pu être récupéré.';
  static const activityPathUnavailable =
      'Chemin sur Hermes — non récupérable depuis le téléphone';

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
  static String conversationActions(String title) =>
      'Actions pour la conversation $title';
  // 7.4 — masquer, 7.5 — supprimer, 7.6 — rechercher.
  static const hide = 'Masquer';
  static const restore = 'Rétablir';
  static const delete = 'Supprimer';
  static const sectionMain = 'Conversations';
  static const sectionHidden = 'Masquées';
  static const hiddenEmpty = 'Aucune conversation masquée.';
  static const hideMissing =
      'Indisponible : ce serveur Hermes ne permet pas de masquer.';
  static const conversationHidden =
      'Conversation masquée. Elle reste dans « Masquées ».';
  static const undo = 'Annuler';
  static const restored = 'Conversation rétablie.';
  static const rowWorking = 'En cours…';
  static const deleteTitle = 'Supprimer définitivement ?';
  static const deleteBody =
      'La conversation et son historique seront effacés dans Hermes, pour '
      'tous ses clients. Le brouillon, les pièces jointes copiées et les '
      'marqueurs de ce téléphone seront aussi effacés. Cette action est '
      'irréversible.';
  static const deleteConfirm = 'Supprimer définitivement';
  static const deleteCancel = 'Annuler';
  static String rowError(String code) => switch (code) {
    'hide.missing' => hideMissing,
    'hide.busy' => 'Une autre action est en cours sur cette conversation.',
    'hide.refused' => 'Hermes a refusé. Rien n’a changé.',
    'hide.uncertain' => 'Résultat inconnu : actualisez la liste pour vérifier. Rien n’a été renvoyé.',
    'delete.busy' =>
      'Un travail ou un envoi est en cours sur cette conversation : arrêtez-le '
          'et attendez sa fin avant de la supprimer.',
    'delete.missing' =>
      'Indisponible : ce serveur Hermes ne permet pas de supprimer.',
    'delete.refused' => 'Hermes a refusé la suppression. Rien n’a été effacé.',
    'delete.uncertain' =>
      'Suppression à vérifier : Hermes n’a pas répondu. Tout est conservé sur '
          'ce téléphone ; actualisez ou réessayez.',
    'transport.offline' => 'Hermes n’est pas joignable : rien n’a été envoyé.',
    _ => 'L’action a échoué. Rien n’a changé.',
  };
  static const searchHint = 'Rechercher une conversation';
  static const searchAllProfiles = 'Tous les profils';
  static const searchCoverage =
      'Recherche dans les titres et le contenu déjà chargé';
  static const searchEmpty = 'Aucun résultat.';
  static const searchRunning = 'Recherche…';
  static String searchFailed(String profile) =>
      '$profile : liste indisponible, résultats partiels.';
  static String searchResult(String profile, String title, String excerpt) =>
      '$title, profil $profile. Passage : $excerpt';
  static const pin = 'Épingler';
  static const unpin = 'Désépingler';
  static const markUnread = 'Marquer non lu';
  static const markRead = 'Marquer lu';
  static const pinned = 'Épinglée';
  static const unread = 'Non lu';
  static const markerFailed =
      'Le marqueur n’a pas pu être enregistré sur le téléphone. Réessayez.';
  static const rename = 'Renommer';
  static const renameMissing =
      'Indisponible : ce serveur Hermes ne permet pas de renommer.';
  static const renameTitle = 'Renommer la conversation';
  static const renameField = 'Titre de la conversation';
  static const renameHint =
      'Le nouveau titre est partagé avec Hermes et ses autres clients.';
  static const renameConfirm = 'Renommer';
  static const renameCancel = 'Annuler';
  static const renaming = 'Renommage en cours…';
  static String renameError(String code) => switch (code) {
    'rename.empty' => 'Saisissez un titre.',
    'rename.same' => 'Ce titre est déjà celui de la conversation.',
    'rename.missing' => renameMissing,
    'rename.busy' =>
      'Un changement est déjà en cours sur cette conversation. Patientez.',
    'rename.refused' =>
      'Hermes a refusé ce titre. Titre inchangé, saisie conservée.',
    'rename.pending' => 'Hermes n’a pas encore confirmé ce titre. Actualisez la liste pour le vérifier.',
    'rpc.uncertain' => 'Résultat incertain : actualisez la liste pour vérifier le titre avant un nouvel essai.',
    'contract.invalid_response' => 'Réponse de Hermes illisible : actualisez la liste pour vérifier le titre.',
    'rename.unreachable' => 'La conversation n’a pas pu être préparée. Titre inchangé, saisie conservée.',
    'transport.offline' =>
      'Hermes n’est pas joignable. Titre inchangé, saisie conservée.',
    'connection.mismatch' =>
      'La connexion a changé. Actualisez la liste avant de renommer.',
    _ => 'Le renommage a échoué. Titre inchangé, saisie conservée.',
  };
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
    'server_requests' => 'Questions et autorisations de Hermes',
    'clarify' => 'Questions de Hermes',
    'approval' => 'Autorisations de Hermes',
    'result_download' => 'Fichiers produits par Hermes',
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
    'question.closed' => 'Cette question n’attend plus de réponse.',
    'question.empty' => questionIncomplete,
    'approval.closed' => 'Cette demande n’attend plus de décision.',
    'approval.choice' => 'Cette décision n’est pas proposée.',
    'approval_mode.unreadable' => 'Hermes n’a pas rendu de mode lisible.',
    'approval_mode.invalid' => 'Ce mode n’existe pas.',
    'result.missing' => resultMissing,
    'result.refused' => resultRefused,
    'result.open' => resultOpenFailed,
    'result.unreadable' => resultUnreadable,
    'result.write' => resultWrite,
    'result.unavailable' => resultUnavailable,
    'result.offline' => resultOffline,
    final code when code.startsWith('result.') => resultUnknown,
    'send.not_received' => 'Hermes n’affiche pas cette demande. Vérifiez la conversation, puis renvoyez-la si besoin. Votre texte est conservé.',
    'turn.error' =>
      'Hermes n’a pas pu terminer cette réponse. Votre brouillon reste intact.',
    'send.unavailable' =>
      'Hermes n’est pas joignable pour le moment. Votre texte est conservé.',
    'send.deleting' =>
      'Cette conversation est en cours de suppression : rien n’a été envoyé.',
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
  static const questionSection = 'Question de Hermes · démonstration fictive';
  static const sampleQuestion = 'Quelle est ta couleur préférée ?';
  static const sampleChoices = ['rouge (Recommended)', 'bleu'];
  static const sampleMultiQuestion = 'Quels formats veux-tu ?';
  static const sampleMultiChoices = ['PDF', 'Markdown', 'HTML'];
  static const approvalSection =
      'Autorisation demandée par Hermes · démonstration fictive';
  static const sampleApprovalDescription = 'delete in root path';
  static const sampleApprovalCommand = 'rm -rf /tmp/exemple';
  static const approvalModeSection =
      'Mode d’autorisation · démonstration fictive';
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
