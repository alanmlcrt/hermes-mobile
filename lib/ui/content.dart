// Libellés d'interface (UX-DR22), séparés des styles.
// Vocabulaire du quotidien : pas de jargon technique en avant.

abstract final class Content {
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
  static const draftKept = 'Votre texte reste affiché sur cet écran.';
  static String draftProfile(String name) => 'Profil : $name';
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
    'draft.not_found' => 'Ce brouillon est introuvable.',
    'send.unknown' =>
      'Résultat incertain : vérifiez la conversation avant de renvoyer. Votre texte est conservé.',
    'send.turn_active' => turnActive,
    'send.unavailable' =>
      'Hermes n’est pas joignable pour le moment. Votre texte est conservé.',
    'transport.offline' =>
      'Hermes n’est pas joignable pour le moment. Votre texte est conservé.',
    'transport.unreachable' =>
      'La conversation n’a pas pu être préparée. Votre texte est conservé.',
    'rpc.4009' => 'La conversation est occupée. Votre texte est conservé.',
    'rpc.4090' =>
      'Trop de conversations sont actives sur Hermes. Votre texte est conservé.',
    'rpc.5035' =>
      'Hermes s’arrête ou redémarre. Votre texte est conservé.',
    'rpc.4064' => 'Ce profil n’existe plus sur le serveur. Votre texte est conservé.',
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
  static const title = 'Galerie de composants';

  static const variantLight = 'Clair';
  static const variantDark = 'Sombre';
  static const variantLargeText = 'Texte agrandi 200 %';
  static const variantReducedMotion = 'Mouvement réduit';

  static const statusLabelSection = 'Indicateur d\'état';
  static const sectionCardSection = 'Carte de section';
  static const composerSection = 'Zone de saisie';

  static const sampleCardTitle = 'Mes profils';
  static const sampleProfiles = ['Profil principal', 'Profil travail'];
}
