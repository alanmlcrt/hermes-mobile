# Hermes Mobile — notes pour la suite du PRD

## Sources et décisions de cadrage

Les sources initiales sont le brief, son addendum et son journal dans `../../briefs/brief-Hermes-Mobile-2026-10-20/`, ainsi que la conversation avec Alanc. Images et pièces jointes restent incluses au MVP. Le cadrage actuel exclut les écrans de consultation et d'administration des profils : seuls leur référencement dans l'application et leur sélection sont nécessaires. Le brief antérieur inclut encore la configuration des profils au MVP ; pour ce point, se référer au PRD actualisé.

La consultation des outils, serveurs MCP et skills d'un profil est souhaitée après le MVP. Alanc souhaite privilégier la simplicité : il peut demander au profil Hermes par défaut de configurer les autres profils. Vérifier les permissions et capacités de l'installation réelle avant de garantir ce fonctionnement ; l'application ne doit pas nécessiter un écran d'administration pour référencer les profils existants.

Le serveur Home Assistant exécute déjà Hermes ; l'utilisateur le décrit comme un équivalent Docker. Tailscale est disponible. Aucune connexion à ce serveur n'a été réalisée. Version et exposition du backend restent inconnues.

## Intégration à vérifier

- [Backend distant Desktop](https://hermes-agent.nousresearch.com/docs/user-guide/multi-connection-desktop) : étudier découverte des profils, sessions et flux WebSocket sur `hermes serve`.
- [API Server](https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server) : distinguer les capacités de l'API compatible OpenAI de celles du backend Desktop, notamment pour les documents et les sessions partagées. L'exigence d'upload ne constitue pas une preuve de support.
- [Bot Mode](https://hermes-agent.nousresearch.com/docs/user-guide/bot-mode) : vérifier les possibilités d'édition de profils distants et les différences entre conversation canonique et sessions ordinaires.
- [Orca Mobile](https://www.onorca.dev/docs/mobile) et [serveurs distants](https://www.onorca.dev/docs/remote-servers) : références du parcours d'association Tailscale. Leur protocole d'association n'est pas présumé compatible avec Hermes.

Le fonctionnement serveur app fermée et la livraison d'une notification sont deux capacités distinctes. Vérifier le canal de notification sur Android avant de promettre ce comportement.

Extraction de recherche officielle reçue pendant Discovery : l'API compatible OpenAI accepte les images mais rejette les documents génériques (`file`, `input_file`, `file_id`). Pour les pièces jointes du MVP, vérifier le backend Desktop ou un transport complémentaire ; ne pas choisir l'API compatible OpenAI seule sans résoudre cet écart. Le Dashboard officiel expose des réglages de profils, mais leur contrat exploitable par le client mobile et leur disponibilité dans la version installée restent à vérifier. Sources : [API Server](https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server), [Web Dashboard](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard).

## Design et outillage

Pour le travail UX, le skill demandé par Alanc est disponible dans `.agents/skills/ui-ux-pro-max`. Références fournies : [overview Markdown Grok Bot](https://docs.x.ai/grok-bot/overview.md), [version HTML](https://docs.x.ai/grok-bot/overview) et [présentation](https://x.ai/bot). Muse reste non identifié et facultatif.

## Références fonctionnelles examinées le 2026-10-20

### Grok Bot : inspiration pour le client

- [Message and collaborate](https://docs.x.ai/grok-bot/chat-and-collaboration) : conversation regroupant messages, activité, questions et approbations ; nouvelles instructions pendant le travail et arrêt demandé par message. L'arrêt n'annule pas les actions déjà terminées.
- [Mobile](https://docs.x.ai/grok-bot/mobile) : lancer une tâche, répondre et consulter les résultats depuis le téléphone ; le travail continue lorsque l'app est fermée.
- [Files and results](https://docs.x.ai/grok-bot/files-and-results) : fichiers d'entrée et résultats accessibles dans le fil, avec aperçu selon le format et sauvegarde. Inspiration pour FR-14, encore proposé.
- [Settings and notifications](https://docs.x.ai/grok-bot/settings-and-notifications) : distinguer travail en cours, contenu non lu et besoin d'attention ; notifications de fin et d'intervention. Les notifications d'intervention restent une extension proposée à préciser, seule la fin étant confirmée dans le besoin actuel.
- [Approvals](https://docs.x.ai/grok-bot/approvals-security-and-privacy) : rendre une demande compréhensible et actionnable. Ne pas copier la politique Auto Review de Grok ni présumer une fonctionnalité équivalente dans Hermes.

Ces références étayent des comportements, pas une palette, une disposition exacte ou une compatibilité Hermes. Le client ne reprend pas implicitement le cloud Grok, ses ordinateurs, routines ou groupes de bots.

### Hermes : capacités à relier au client

- [Messaging Gateway](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/) documente notamment `/stop`, `/approve`, `/deny` et la gestion des sessions. Leur existence sur une gateway ne prouve pas leur exposition par chaque transport mobile.
- [Intégration programmatique](https://hermes-agent.nousresearch.com/docs/developer-guide/programmatic-integration) décrit suivi d'exécution, arrêt, instructions pendant le travail et réponses aux approbations. Vérifier le contrat et la version réellement installés.
- [Interface CLI](https://hermes-agent.nousresearch.com/docs/user-guide/cli) et [commandes](https://hermes-agent.nousresearch.com/docs/reference/slash-commands/) distinguent interruption, instruction au prochain point d'outil et message mis en attente. Ne pas présenter toute saisie pendant le travail comme une interruption immédiate.
- [Discord](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/discord) documente les fichiers génériques accessibles à l'agent. Cette capacité ne fixe pas les limites du futur client.
- [API Server](https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server) distingue images en ligne et documents non images, sans upload générique. Ses sessions ne donnent pas automatiquement accès aux conversations appartenant à Discord ou Desktop. Une continuité avec Discord ne fait pas partie des décisions confirmées.
- [Desktop](https://hermes-agent.nousresearch.com/docs/user-guide/desktop) décrit connexion à un backend distant existant et découverte de profils ; [Bot Mode](https://hermes-agent.nousresearch.com/docs/user-guide/bot-mode) distingue le chat persistant d'un bot des sessions ordinaires. Préserver les conversations distinctes demandées : ne pas assimiler `/new` dans un chat canonique à une nouvelle conversation ordinaire sans vérifier sa sémantique.
- [Deliverable Mode](https://hermes-agent.nousresearch.com/docs/user-guide/features/deliverable-mode) documente le retour de fichiers via les gateways compatibles. La récupération mobile reste à vérifier de bout en bout.

La création d'environnements, le travail sur du code et l'évolution des compétences relèvent du Hermes existant. Aucun moteur d'agent ni espace de développement mobile dédié n'est demandé. Pour l'architecture, vérifier un chemin complet : profils, conversations, fichiers aller-retour, événements, arrêt, questions et autorisations, puis notifications.

