// Libellés d'interface (UX-DR22), séparés des styles.
// Vocabulaire du quotidien : pas de jargon technique en avant.

abstract final class Content {
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
  static const activityUnknown = 'Événement non reconnu';
  static String activity(bool tool) => tool ? activityTool : activityUnknown;
  static const activityEnd = 'Fin reçue';
  static const activityEndAccessible = 'Fin d’action reçue';
  static String activitySummary(int count, int pending) =>
      '$count activités · $pending sans fin confirmée';
  static const expandActivities = 'Déplier les activités';
  static const collapseActivities = 'Replier les activités';
  static const workSending = 'Envoi…';
  static const workRunning = 'Hermes travaille…';
  static const workSucceeded = 'Terminé';
  static const workFailed = 'Erreur';
  static const workStopped = 'Arrêté';
  static const workUnknown = 'Non synchronisé';
  static const draftKept = 'Votre texte reste affiché sur cet écran.';
  static String draftProfile(String name) => 'Profil : $name';
  static const chooseProfileHint = 'Ouvre la liste des profils';
  static const chooseProfile = 'Choisir le profil';
  static const conversations = 'Conversations';
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

  static const profileFixture = 'Principal';
  static const profileFixtureKey = 'default';
  static String profileName(String label, String key) => '$label ($key)';
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
  static const activitySecond = 'Deuxième ID';
  static const activityComplete = 'Recevoir la fin';
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
