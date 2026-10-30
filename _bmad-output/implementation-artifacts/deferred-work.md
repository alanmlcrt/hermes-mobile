- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-init-app-telephone.md`
  summary: Choisir l'identifiant de bundle iOS (actuellement `fr.hermesMobile`, généré par `flutter create`), puisque `fr.hermes_mobile` est invalide sur iOS.
  evidence: `ios/Runner.xcodeproj/project.pbxproj` l.386 diffère de l'identifiant Android ; les `_` sont interdits dans un bundle id iOS. À trancher avant le travail iPhone.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-1-nouvelle-conversation-brouillon.md`
  summary: Après un changement de profil depuis « Mes profils », ouvrir le brouillon du nouveau profil au lieu de revenir à celui de l'ancien.
  evidence: `/profiles` est poussé depuis `/draft/<clé>` et `selectProfile` ne relance pas `resolveLaunchTarget` ; relève de la story 2.5.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-1-nouvelle-conversation-brouillon.md`
  summary: Tester que `MainApp.dispose` vide l'outbox avant de fermer la base via le gateway.
  evidence: `MemoryOutbox.dispose` est vide ; l'ordre `outbox.dispose().whenComplete(gateway.dispose)` de `lib/main.dart` n'est observé par aucun test.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-envoi-sans-double-execution.md`
  summary: Rapprocher une opération `unknown` quand une réponse tardive ou l'historique prouve son acceptation.
  evidence: `call()` retire l'id au timeout, une réponse tardive est ignorée ; relève de la story 2.4.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-envoi-sans-double-execution.md`
  summary: L'accueil rouvre un brouillon de conversation existante quand il contient du texte, au lieu d'une nouvelle conversation.
  evidence: `openNewDraft` préfère `body <> ''` ; à remplacer par la restauration de 2.4/2.6 une fois l'historique disponible.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-3-reponse-en-direct.md`
  summary: Appariement des bulles utilisateur aux tours robuste aux tours lancés par un autre client sur la même session.
  evidence: `accepted()` apparie par position (`userTurns + 1`) ; un tour démarré ailleurs décale les liaisons.

- source_spec: spec-compagnon-lapin-lot-1.md
  summary: Réconcilier les descriptions historiques de teinte et la maquette de contexte avec la planche v5.
  evidence: Sources UX préexistantes suivies à la demande utilisateur ; table taupe et ancien SVG à oreille pliée malgré la priorité v5 explicitement blanche sans pli. Aucun changement métier causé par ce lot.

- source_spec: `spec-3-5-arret-travail.md`
  summary: Distinguer chargement, erreur et liste vide sur l’accueil, empêcher l’ouverture prématurée d’un brouillon et permettre l’actualisation.
  evidence: Blind 3/4/5 et Edge 2 : FutureBuilder ignore hasError, onTap reste actif et _latest est final ; comportement antérieur à 3.5.
- source_spec: `spec-3-5-arret-travail.md`
  summary: Rendre les pastilles de couleur activables au lecteur d’écran.
  evidence: Blind 6 et Edge 3 : Semantics excludeSemantics masque InkResponse sans exposer onTap ; réglages préexistants.
- source_spec: `spec-3-5-arret-travail.md`
  summary: Protéger les sélections de couleur concurrentes contre le rollback d’une ancienne écriture échouée.
  evidence: Blind 7 : ProfileAccents.choose restaure previous sans vérifier la sélection actuelle ; module préexistant inchangé.
- source_spec: `spec-3-5-arret-travail.md`
  summary: Faire tenir les identifiants de profil longs avec texte agrandi dans les réglages.
  evidence: Blind 8 : Text(profile.value) non contraint dans ListTile.trailing ; surface préexistante.
- source_spec: `spec-3-5-arret-travail.md`
  summary: Regrouper l’historique par date calendaire, y compris lors du passage à l’heure d’été.
  evidence: Edge 4 : durée entre deux minuits locaux de 23 h ramenée à zéro jour par inDays ; fonction antérieure à 3.5.
- source_spec: `spec-3-5-arret-travail.md`
  summary: Vérifier la sélection et la persistance des accents via leurs consommateurs.
  evidence: Verification 1 : aucune assertion sur choose/store.save, réouverture SQLite et isolement ; le test de migration écrit directement le SQL. Surface préexistante.
- source_spec: `spec-3-5-arret-travail.md`
  summary: Vérifier la classification d’un outil reconnu depuis les événements du repository jusqu’à la projection persistée.
  evidence: Verification 2 : forTool est testé seul ; le branchement repository préexistait à 3.5 et aucun scénario reçu reconnu ne le couvre.

- source_spec: `_bmad-output/implementation-artifacts/spec-5-2-faire-tourner-observateur-fins-travail.md`
  summary: Monter un chemin lisible pour `fcm_service_account` (secret Home Assistant ou volume `/share`) avant d'activer `personal`.
  evidence: `config.yaml` n'expose que `/data` et `Config.validate` exige un fichier existant ; en 5.2 `personal` est refus? avant usage. ? trancher avec la story 5.3 (FCM r?el).

- source_spec: `_bmad-output/implementation-artifacts/spec-5-2-faire-tourner-observateur-fins-travail.md`
  summary: Permettre ? plusieurs abonnements (appareils) de suivre la m?me ex?cution `(sessionId, user_row_id)`.
  evidence: `executions.execution_id` est cl? primaire et `Store.attach` renvoie `Conflict` (400) au second abonnement ; d?cision 5.2 : une ex?cution par abonnement. N?cessite une table de liaison et une politique de d?doublonnage par appareil.

- source_spec: `_bmad-output/implementation-artifacts/spec-5-4-ouvrir-conversation-depuis-notification.md`
  summary: Vérifier sur téléphone le chemin natif du toucher (extra `subscriptionId` posé par FCM et par `show`, `takeOpened` consommé une fois, `onNewIntent` à chaud, filtre `LAUNCHED_FROM_HISTORY`).
  evidence: aucun harnais de test Android (ni `src/test` ni `androidTest`) ; le test Dart scripte la réponse native. À couvrir par les essais G3 de la story 5.5 : toucher à froid, à chaud, relance depuis les récents.

- source_spec: `_bmad-output/implementation-artifacts/spec-etude-2-plugin-hermes-fcm.md`
  summary: Plugin de notifications : plusieurs téléphones par profil, sans qu'un client écrase le jeton d'un autre.
  evidence: `HERMES_HOME/hermes-mobile/fcm-token` est unique ; le dernier client qui appelle `command.dispatch` reçoit tout.
- source_spec: `_bmad-output/implementation-artifacts/spec-5-6-plugin-hermes-notifications.md`
  summary: Réduire `contracts/notification-tracking.json` au seul payload du plugin (titres, canal, `outcome`, `sessionId`) dans la story 5.8, avec le retrait de l'observateur.
  evidence: décision d'Alanc du 2026-10-29 ; le notifier (`contracts.py`, `sync_contracts.py --check`, tests, smoke Docker) et `test/notification_contract_test.dart` lisent encore le registre et le payload `subscriptionId`.

- source_spec: `_bmad-output/implementation-artifacts/spec-5-7-basculer-app-plugin.md`
  summary: Vérifier sur téléphone le côté Kotlin de `sessionId` (extra FCM au toucher à froid et à chaud, regex, `show` en premier plan) avec le vrai payload du plugin.
  evidence: Aucun test Android dans le dépôt ; les tests Dart simulent le canal `hermes/notifications`, une clé Kotlin erronée passerait inaperçue.
- source_spec: `_bmad-output/implementation-artifacts/spec-5-7-basculer-app-plugin.md`
  summary: Réécrire `contracts/notification-tracking.json` et `test/notification_contract_test.dart` sur le payload `{outcome, sessionId}` en 5.8.
  evidence: Le test exige encore `subscriptionId` et interdit `sessionId`, à l'opposé de ce que l'app accepte depuis la 5.7.
