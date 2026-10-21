# Epic 2 Context: Converser avec un profil et retrouver mes conversations

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

À l'ouverture normale de l'app, Alanc trouve une nouvelle conversation prête sur le profil par défaut fourni par Hermes. Il écrit ou colle de longs textes, envoie sa demande en sachant si elle a été acceptée, lit la réponse progressivement avec mise en forme et code, puis retrouve et reprend les conversations de chaque profil. Quitter l'app, perdre le réseau ou redessiner l'écran ne perd jamais un brouillon et ne relance jamais une exécution en double. L'epic requiert la porte G1 pour toute intégration serveur ; l'interface et les brouillons sur fixtures peuvent avancer avant.

## Stories

- Story 2.1 : Préparer une demande sur une nouvelle conversation
- Story 2.2 : Envoyer ma demande sans risque de double exécution
- Story 2.3 : Lire la réponse en direct avec mise en forme et code
- Story 2.4 : Retrouver mon travail après une coupure ou un retour dans l'app
- Story 2.5 : Choisir le profil de ma nouvelle conversation
- Story 2.6 : Retrouver et reprendre mes conversations par profil

## Requirements & Constraints

- **Accueil :** ouverture normale → nouvelle conversation sur le profil par défaut, sans créer de fil vide ni de session Hermes avant le premier envoi. Un retour temporaire dans l'app conserve l'écran en cours. L'ouverture depuis une notification relève de l'Epic 5.
- **Profils et historique :** sélectionner un profil existant, retrouver ses conversations, en créer une nouvelle. Changer de profil ne mélange ni messages ni fichiers entre conversations ; le profil d'un fil existant ne change jamais.
- **Texte :** longs textes et collage acceptés sans troncature, sans commande `/` pour les actions courantes. Réponses avec emojis, mise en forme et code, affichées progressivement. Les limites serveur ou modèle sont expliquées sans perte du brouillon.
- **Fiabilité :** une coupure ne masque pas un échec, ne perd pas un brouillon et ne provoque jamais silencieusement une nouvelle exécution. Une demande au résultat incertain n'est pas renvoyée automatiquement. Quitter l'app n'annule pas le travail accepté par le serveur.
- **Accessibilité :** parcours utilisables au toucher avec clavier affiché, texte agrandi 200 % et lecteur d'écran ; noms accessibles sur champ et boutons ; aucun état par la seule couleur.
- **G1 non validée :** aucune intégration serveur (création de session, envoi, historique) avant vérification des prérequis sur l'installation réelle ; une capacité absente est signalée, jamais contournée.

## Technical Decisions

- **Propriétaires :** `ConnectionRepository` reste seul auteur des connexions, profils, profil sélectionné et de la socket. `ConversationRepository` seul auteur de la projection distante (`TimelineProjection`) et ne crée jamais de session. `OutboxRepository` seul auteur des brouillons, pièces sortantes, de `ensureSession(DraftKey)` (sérialisé par brouillon) et des opérations locales. ViewModels `ChangeNotifier` : commandes + lecture de projections ; vues sans réseau ni écriture persistante.
- **Identités :** `DraftKey` local, distinct de la session ; association `DraftKey → SessionKey` persistée avant soumission. `OperationKey` local distinct de l'identité d'exécution serveur. Données distantes clés par `ConnectionKey + ProfileKey + SessionKey`, opaques et sensibles à la casse. Aucun profil par défaut inventé : défaut Hermes (`is_default`) ou dernier choix explicite.
- **Soumission :** opération persistée (cible, contenu exact, références fichiers) avant envoi ; pipeline nommé `ensureSession` → pièces → suivi notification (non bloquant) → soumission. Résultat incertain → `unknown`, brouillon conservé, aucun renvoi ; répétition seulement si l'idempotence est une capacité détectée (un ID JSON-RPC n'en est pas une). Un seul envoi à la fois par session ; saisie conservée pendant le travail. Seule la version acceptée du brouillon est retirée.
- **Projection :** mapping déclaratif `contracts/` événements → états/terminaux/`ActivityKind`. Mutations sérialisées par session ; projection et curseur écrits atomiquement ; curseur `(epoch, seq)` seulement si détecté, sinon snapshot complet. Doublons écartés ; trou/troncature/nouvel epoch → snapshot. Rapprochement local/serveur jamais par le texte (règle fixée en G1). Connexion et travail sont deux états distincts.
- **États :** acceptation locale `draft`, `preparing`, `sending`, `accepted`, `unknown`, `failed` ; travail distant `queued`, `running`, `succeeded`, `failed`, `stopped`, `unknown` ; connexion `connecté`, `resynchronisation`, `hors ligne`.
- **Navigation :** table unique de routes typées (`/c/<ConnectionKey>/<ProfileKey>/<SessionKey>`, `/draft/<DraftKey>`) ; un seul `resolveLaunchTarget()` décide : notification, puis restauration, puis accueil.
- **Stockage :** un seul SQLite, tables préfixées par repository (`outbox_*`, `conversation_*`), migrations en ajout seul et testées. Aucun secret ni contenu conversationnel dans les logs (codes `domaine.code`).
- **Hermes :** backend Desktop `hermes serve` sur `:9119`, REST pour les ressources, JSON-RPC `/api/ws` ; seul l'adaptateur connaît les formats Hermes. Un fil n'est jamais réparti entre plusieurs transports. Ne jamais modifier le profil actif global du dashboard.

## UX & Interaction Patterns

- **Saisie et envoi :** longs textes et collage, utilisable clavier affiché ; brouillon jamais perdu ; pendant le travail, la saisie est conservée et non soumise.
- **Message :** rendu Markdown (pas `flutter_markdown`), emojis, blocs de code lisibles, réponse progressive ; états envoi, travail, fin, erreur, inconnu/non synchronisé.
- **Historique :** conversations d'un profil distinguables ; historique vide et reprise traités.
- **Indépendance rendu/état :** changer la composition du fil conserve conversations, brouillons et état ; aucun appel rejoué par un nouveau rendu. Les maquettes `mockups/*.html` sont une référence visuelle.
- Vocabulaire quotidien (Profil, Conversation), libellés dans le fichier de contenu, valeurs visuelles via les tokens ; chaque composant présent dans la galerie (clair, sombre, texte agrandi, mouvement réduit).

## Cross-Story Dependencies

- Dépend de l'Epic 1 : profil par défaut et dernier choix explicite (1.7), états de connexion et capacités (1.6), socket unique (1.5), contrat figé (1.3).
- 2.1 pose `OutboxRepository`, `DraftKey`, la route `/draft/<DraftKey>` et `resolveLaunchTarget()` ; 2.2 y ajoute `ensureSession` et la soumission (requiert G1 : création de session, envoi, règle de rapprochement).
- 2.3 et 2.4 s'appuient sur la projection de 2.2 ; 2.5 et 2.6 réutilisent le brouillon de 2.1 et la sélection de profil de 1.7.
- Epic 3 (activité, arrêt), Epic 4 (pièces dans le pipeline) et Epic 5 (route de notification dans `resolveLaunchTarget`) étendent les points posés ici.
