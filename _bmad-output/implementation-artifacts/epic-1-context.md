# Epic 1 Context: Connecter l'app à mon Hermes et voir mes profils

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Poser le socle de Hermes Mobile, application Android personnelle (iPhone anticipé) qui sert d'interface distante à l'installation Hermes d'Alanc. À la fin de l'epic, Alanc installe un APK privé, appaire l'app à son serveur par QR code ou URL, s'authentifie une seule fois et voit ses profils Hermes. Serveur injoignable, authentification refusée et capacités manquantes sont signalés chacun de façon distincte. L'epic valide aussi la stack Flutter sur le téléphone réel, met en place le thème, les tokens, la galerie de composants et la CI, et fige le contrat Hermes de l'installation. Cette capture du contrat est la première étape de la porte G1, et toutes les intégrations suivantes en dépendent.

## Stories

- Story 1.1 : Initialiser l'application et la valider sur mon téléphone
- Story 1.2 : Poser le thème système, les tokens et la galerie de composants
- Story 1.3 : Capturer le contrat Hermes de mon installation
- Story 1.4 : Appairer l'app à mon serveur Hermes
- Story 1.5 : M'authentifier une fois et rester connecté
- Story 1.6 : Connaître l'état de la connexion et les fonctions disponibles
- Story 1.7 : Voir et actualiser mes profils Hermes

## Requirements & Constraints

- **Accès distant :** la connexion passe par le réseau Tailscale existant. L'association se fait par QR code ou lien (`hermes-mobile://pair?url=<origine>`), avec une saisie manuelle de secours, et la connexion est mémorisée. En cas d'échec, « serveur inaccessible » et « authentification refusée » sont deux messages différents.
- **Profils :** les profils existants sur Hermes sont listés et sélectionnables, sans recréation ni configuration côté mobile. Chaque profil est distinguable et le profil actif identifiable. Une actualisation fait apparaître un profil ajouté côté Hermes sans réinstaller l'app. Un échec de chargement s'affiche différemment d'une liste vide. Aucun écran d'administration des profils au MVP.
- **Secrets :** Tailscale fournit le réseau, mais l'authentification Hermes reste obligatoire. Aucun secret (mot de passe, jeton) n'apparaît dans les erreurs, logs, diagnostics, URL persistées ou sauvegardes.
- **Compatibilité :** les capacités du serveur sont vérifiées pour chaque fonction et une fonction absente est signalée clairement. Une capacité obligatoire absente n'est jamais contournée : elle est remontée à Alanc et bloque l'acceptation, et seul Alanc peut décider de la retirer.
- **Accessibilité (transverse) :** les parcours se font au toucher avec le clavier affiché, le texte agrandi (200 %) et le lecteur d'écran. Chaque icône d'action a un nom accessible, et aucun état n'est exprimé uniquement par la couleur.
- **Validation réelle :** la stack n'est confirmée que si l'APK compile, s'installe et se lance sur le téléphone Android d'Alanc. Sinon, le travail s'arrête et le choix de stack revient à Alanc. Aucune simulation locale ne vaut validation.

## Technical Decisions

- **Stack :** la graine est générée par `flutter create --empty --platforms=android,ios hermes_mobile`, avec Flutter 3.47.x (dernier correctif) épinglé et le Dart fourni. minSdk 24, `allowBackup=false`. Paquets retenus : dynamic_color 2.1.0, sqflite 2.4.4+2, flutter_secure_storage 11.2.0. Les paquets réseau, Markdown, fichiers et routage sont choisis centralement, épinglés, résolus ensemble et compilés au bootstrap. Ne pas utiliser `flutter_markdown` (abandonné). firebase_messaging n'est pas ajouté avant G3. Le SDK épinglé et le lockfile commité font référence.
- **Arborescence :** `lib/app` (composition, routes, `resolveLaunchTarget`), `lib/models` (sans Flutter), `lib/data` (repositories, adaptateur, stockage), `lib/features` (vues, ViewModels), `lib/ui` (tokens, thème, composants, catalogue), `contracts/` à la racine.
- **MVVM léger :** les ViewModels sont des `ChangeNotifier` et les repositories exposent des `Stream` de snapshots immuables. Pas d'autre framework d'état. L'injection est explicite au démarrage, sans service locator. Les vues ne font ni appel réseau ni écriture persistante. La CI contrôle les imports : `lib/models` n'importe pas Flutter et les vues n'accèdent pas à `lib/data`.
- **`ConnectionRepository` :** seul auteur des connexions, des capacités, de la liste des profils, du profil sélectionné et de l'unique socket par connexion. Aucun autre module n'ouvre de socket.
- **Identités :** `ConnectionKey` est un UUID local stable, et l'URL n'en est qu'un attribut modifiable sans réindexation. `ProfileKey` et `SessionKey` sont opaques et sensibles à la casse. Si la découverte des profils échoue, aucun profil par défaut n'est inventé : le défaut vient de Hermes ou du dernier choix explicite enregistré.
- **Point d'entrée Hermes :** le backend Desktop `hermes serve` de l'add-on `WolframRavenwolf/hermes-ha-addon` 1.3.9 (option `enable_desktop_backend`, port 9119 à mapper). Les ressources passent par REST, la conversation par JSON-RPC sur `/api/ws`. Le mobile n'utilise ni l'ingress `:8123`, ni les ports 8080/8443, ni `/v1/`. Seul l'adaptateur connaît les formats Hermes. Charger les profils ne doit jamais modifier le profil actif global du dashboard.
- **Contrat :** la référence est le tag de release correspondant au build installé, jamais HEAD amont. `contracts/` contient ce tag, l'extrait OpenRPC, les méthodes utilisées, des fixtures anonymisées vérifiées par un test anti-secret, et un fichier de capacités (présente/absente/non vérifiée pour `replay_epoch`, `idempotency_key`, `file.attach`, etc.). Il contient aussi la table déclarative événements → états/terminaux/`ActivityKind`, avec un type inconnu explicite et validée contre les fixtures. Cette table est partagée avec le futur observateur serveur.
- **Authentification :** login Basic (utilisateur `hermes`, `access_password`) qui donne un jeton d'accès (12 h) et un refresh (30 j). La socket s'ouvre avec un ticket WS. Le secret serveur change à chaque redémarrage du backend : le mot de passe est donc gardé en stockage sécurisé, et l'app se reconnecte seule quand le refresh échoue. Les secrets sont rangés sous `<ConnectionKey>/<usage>`. Une redirection vers une autre origine ne reçoit jamais de credentials.
- **Réseau :** l'origine est `http://<hôte>.ts.net:9119`. `http://` n'est accepté que pour `*.ts.net`, avec une exception `network_security_config` limitée à `ts.net`. `https://` est toujours accepté. Le QR ne contient que l'origine, l'app la fait confirmer, puis le mot de passe est saisi une fois. Un script du dépôt génère le QR.
- **Erreurs et logs :** enveloppe partagée avec `code` namespacé, `retryable` et `operationKey?`. Le texte destiné à l'utilisateur est distinct du diagnostic expurgé. Méthode absente, refus d'authentification et panne transitoire donnent trois erreurs distinctes. Les logs utilisent des codes `domaine.code` et des identifiants de corrélation locaux, sans contenu conversationnel. Les dates sont en UTC ISO 8601.
- **Stockage :** un seul fichier SQLite. Les tables sont préfixées par leur repository propriétaire (`connection_*`), avec un registre de migrations en ajout seul et testées. Aucun secret en SQLite.
- **Capacités au démarrage :** l'app compare les capacités détectées à la liste exigée dans `contracts/` et affiche l'écart.
- **Livraison :** APK privé, signé et versionné, installé manuellement. Les clés de signature restent hors du dépôt. La CI exécute l'analyse, les tests, le contrôle des imports et le build Android.

## UX & Interaction Patterns

- **Thème :** clair/sombre selon le téléphone. Dynamic Color Android (API 31+) avec les rôles canvas=surface, content=onSurface, emphasis=primary et emphasis-content=onPrimary, résolus à l'exécution et jamais en hexadécimal figé. Pas de couleur de marque. Une palette de secours claire/sombre est centralisée dans le thème (valeurs provisoires jusqu'à G4).
- **Tokens :** une source unique dans `lib/ui` pour les couleurs par rôle, la typographie, les espacements, les rayons, les élévations, les tailles d'icônes et le mouvement. Un test interdit les valeurs visuelles littérales hors de `lib/ui`. Les tokens typographiques ne sont pas encore finalisés : il faut privilégier la lisibilité des longs textes et du code.
- **Galerie de fixtures (build de développement) :** chaque composant s'y affiche avec des données fictives, en clair, sombre, texte agrandi 200 % et mouvement réduit. Les libellés viennent d'un fichier de contenu séparé des styles. Le vocabulaire est celui du quotidien (Profil, Conversation) et les détails techniques ne dominent pas.
- **Connexion :** scan ou saisie de l'origine, confirmation, puis mot de passe. Messages distincts « serveur inaccessible » et « authentification refusée », avec des états de chargement et de retour après échec.
- **Indicateur de connexion :** `connecté`, `resynchronisation` et `hors ligne`, toujours avec un libellé et pas seulement une couleur. Cet indicateur est distinct de l'état du travail. Un écart de capacités est affiché avec la fonction concernée.
- **Choix du profil :** profils distinguables et profil actif identifiable, avec actualisation. Les états chargement, liste vide et erreur sont distincts. Au lecteur d'écran, chaque profil et le profil actif sont annoncés avec un nom accessible.
- La présentation (navigation, disposition) reste ouverte. Les maquettes `mockups/*.html` sont une référence visuelle, pas une logique de production.

## Cross-Story Dependencies

- 1.1 bloque tout le reste : si elle échoue sur le téléphone, le choix de stack revient à Alanc.
- 1.2 fournit les tokens, le thème et la galerie utilisés par les écrans de 1.4 à 1.7 et par les epics suivants.
- 1.3 ouvre la porte G1 : les stories 1.4 à 1.7 et toutes les intégrations des Epics 2 à 6 s'appuient sur le contrat figé. Les autres vérifications de G1 (deux profils, historique, envoi, reprise, arrêt, règle de rapprochement) conditionnent l'Epic 2. L'UI sur fixtures peut avancer sans attendre G1.
- Les stories 1.4 (appairage, `ConnectionKey`), 1.5 (authentification, socket unique), 1.6 (capacités, erreurs, état de connexion) et 1.7 (profils) sont séquentielles.
- Epic 2 réutilise le profil par défaut fourni par Hermes et le dernier choix explicite enregistré (1.7), ainsi que les états de connexion (1.6). La table de mapping de 1.3 alimente aussi l'Epic 3 (catalogue `ActivityKind`) et l'observateur de l'Epic 5.
