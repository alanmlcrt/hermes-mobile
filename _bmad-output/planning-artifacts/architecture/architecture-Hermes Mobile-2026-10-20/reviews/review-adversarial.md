# Revue adversariale — ARCHITECTURE-SPINE.md (Hermes Mobile, 2026-10-20)

**Lentille :** deux unités d'un niveau inférieur (épopées/fonctionnalités confiées à des agents IA séparés) qui respectent chaque AD à la lettre et produisent pourtant du code incompatible. Chaque paire est un trou ; un correctif (nouvel AD ou convention resserrée) est proposé.
**Périmètre :** lecture seule du spine ; `.memlog.md` pour le contexte. Ne sont listés que les trous que le spine ne ferme pas déjà.

**Verdict :** le spine verrouille bien l'autorité serveur, l'idempotence et la réconciliation, mais il nomme des *propriétaires de repositories* sans nommer les *propriétaires des entités qui passent entre eux* (création de session, pièces, intention d'arrêt, profils, frise fusionnée) ni les *formats partagés hors code Dart* (schéma SQLite, routes de navigation, contrat observateur). Six trous sont de gravité haute ; ils casseront dès que deux agents travailleront en parallèle.

Échelle : **Haute** = incompatibilité garantie ou données corrompues/mal routées ; **Moyenne** = divergence probable, réparable par refactor ; **Basse** = friction.

---

## T1 — Deux créateurs de session pour un même brouillon — **Haute**

- **Unité A :** Pièces jointes (FR-5/6). AD-6 exige des références serveur « dans le scope d'origine » avant le prompt ; la convention Accueil dit « session créée au premier besoin d'envoi/staging ». L'agent crée donc la session au premier fichier ajouté, depuis son propre flux de staging (via `DraftRepository`, propriétaire des « envois locaux »).
- **Unité B :** Conversation/envoi (FR-4). Même convention : session créée au premier envoi. L'agent appelle `session.create` dans `ConversationRepository`, seul auteur de la « projection distante » — une session est bien distante.
- **Pourquoi les deux sont conformes :** AD-2 attribue la projection distante à `ConversationRepository` et les envois locaux à `DraftRepository` sans dire qui *crée* la session ; AD-3 exige seulement que l'association `DraftKey → SessionKey` soit persistée avant soumission, sans dire par qui.
- **Divergence :** un brouillon avec pièce puis texte crée deux sessions (pièces dans S1, prompt dans S2) — exactement la « fuite entre fils » qu'AD-6 interdit — ou deux écritures concurrentes de l'association.
- **Correctif (nouvel AD-12 « Matérialisation de session ») :** une seule opération `ensureSession(DraftKey) → SessionKey`, détenue par `DraftRepository`, sérialisée par `DraftKey`, idempotente localement (relit l'association persistée avant tout `session.create`), avec une `OperationKey` de type `createSession` soumise à AD-5 (résultat incertain = `unknown`, pas de recréation automatique). Pièces et envoi ne l'appellent que par elle. `ConversationRepository` ne crée jamais de session ; il commence la projection quand l'association est publiée.

## T2 — Deux propriétaires de l'entité « pièce jointe » — **Haute**

- **Unité A :** Pièces jointes crée un `AttachmentRepository` (copie privée, état `copying/uploading/uploaded/failed/unknown`, référence serveur), conformément à AD-6.
- **Unité B :** Envoi persiste dans l'opération de `DraftRepository` « contenu exact et références de fichiers » (AD-5) et considère la pièce comme champ du brouillon (convention Brouillons : « conserver les pièces jusqu'au rapprochement »).
- **Pourquoi les deux sont conformes :** AD-2 énumère trois repositories ; aucun n'est désigné pour les pièces, et rien n'interdit d'en créer un quatrième.
- **Divergence :** deux tables, deux statuts d'upload ; le blocage « upload échoué ou incertain bloque le prompt » est évalué sur une source pendant que l'autre est mise à jour ; la suppression de la copie privée (après acceptation ? après rapprochement ? à l'abandon du brouillon ?) est faite par l'un pendant que l'autre la référence encore.
- **Correctif :** amender AD-2 : `DraftRepository` est seul auteur des pièces sortantes (copie, statut, référence serveur, nettoyage) ; l'épopée fichiers fournit un service d'upload sans état persistant appelé par lui. Ajouter une convention « Pièces » : clé `AttachmentKey` locale liée à `DraftKey` ; disposition disque `app_private/attachments/<connectionKey>/<draftKey>/<attachmentKey>` ; suppression uniquement par `DraftRepository` après acceptation confirmée de l'opération qui les référence ou abandon explicite du brouillon. Les fichiers *résultats* téléchargés (AD-6) ont un emplacement distinct en cache, clé `profil/session/ressource`, purgeables, jamais mélangés.

## T3 — Schéma et migrations SQLite fragmentés — **Haute**

- **Unité A :** Brouillons ouvre `drafts.db` (sqflite) version 1→2 avec sa migration.
- **Unité B :** Conversation ajoute la table de projection + curseur dans « la » base, en incrémentant aussi `version` 1→2 avec une autre migration.
- **Pourquoi les deux sont conformes :** la convention dit « SQLite pour brouillons, opérations et projection », « migrations versionnées », « testées avant suppression » ; elle ne dit ni une base ou plusieurs, ni qui détient le numéro de version.
- **Divergence :** avec une base unique, deux branches livrent chacune un `onUpgrade` vers v2 différent → l'une n'est jamais appliquée sur un appareil déjà migré. Avec plusieurs bases, AD-4/AD-5 exigent des écritures atomiques qui traversent brouillon/opération et projection (accepter un envoi = retirer la version du brouillon + marquer l'opération + attendre le message) : impossible de façon atomique entre fichiers.
- **Correctif :** convention « Stockage local » resserrée : un seul fichier SQLite, ouvert par une couche `data/storage/` unique ; registre de migrations ordonné et append-only (`migrations/NNNN_<unité>_<sujet>`), numéro attribué à la fusion, jamais modifié après publication ; chaque table préfixée par son repository propriétaire, seule ce repository y écrit ; transactions traversantes exposées uniquement par une API du stockage, pas par SQL brut dans les repositories. Test de migration depuis chaque version publiée.

## T4 — Grammaire de navigation / lien profond non définie — **Haute**

- **Unité A :** Notification (AD-9) reçoit « identifiant opaque de destination » et, à l'ouverture, navigue vers `/session/<id>` après recharge.
- **Unité B :** Conversation/historique définit `/c/<profileId>/<sessionId>` et un état d'accueil en mémoire ; l'accueil (convention Accueil) affiche un nouveau brouillon par défaut.
- **Pourquoi les deux sont conformes :** le routage est différé « au bootstrap » (package choisi centralement) mais seule la *bibliothèque* est centralisée, pas les *routes* ; AD-3 donne le triplet de clés sans dire comment il est sérialisé dans une route ; « la cible de notification prévaut sur l'accueil » sans format de cible.
- **Divergence :** l'ouverture à froid depuis une notification arrive sur une route inexistante ou sur une route qui ignore le profil, donc résout la mauvaise session si deux profils ont des IDs similaires (cas listé dans les vérifications). L'accueil peut aussi écraser la cible si les deux unités tranchent l'ordre d'initialisation différemment.
- **Correctif :** nouvelle convention « Routes » dans `app/` : table unique de routes typées (`HomeDraft(draftKey?)`, `Session(connectionKey, profileKey, sessionKey)`, `Settings/Connection`…), sérialisation unique (encodage URL des IDs opaques, sensibles à la casse), une seule fonction `resolveLaunchTarget()` qui décide notification > restauration > accueil, et qui seule lit l'intent de lancement. Le payload push contient un identifiant opaque que *seul* `resolveLaunchTarget` traduit (après auth) en route typée ; aucune fonctionnalité ne construit de chaîne de route à la main.

## T5 — Identité de l'observateur et `ConnectionKey` inconnue côté serveur — **Haute**

- **Unité A :** Observateur serveur (AD-9) déduplique « par cible + exécution + terminal » et met dans le payload un identifiant opaque = `profileId:sessionId` hashé, puisqu'il ne connaît que les IDs Hermes.
- **Unité B :** Mobile (AD-3) indexe toutes les données distantes par `ConnectionKey + ProfileKey + SessionKey`, où `ConnectionKey` est un UUID local généré à l'association.
- **Pourquoi les deux sont conformes :** AD-3 ne définit pas `ConnectionKey` (UUID local ? origine normalisée ? identité du serveur ?) ; AD-9 dit « identité stable » sans préciser son espace de noms.
- **Divergence :** le mobile ne peut pas retrouver la connexion à partir du payload si plusieurs connexions existent (ou après ré-association : nouvelle `ConnectionKey`, anciens suivis orphelins). Si une autre unité choisit l'origine URL comme `ConnectionKey`, passer de l'ingress à Tailscale Serve (prévu par G1) ré-indexe toute la base locale et casse brouillons et curseurs.
- **Correctif :** resserrer AD-3 : `ConnectionKey` = UUID local stable, jamais dérivé de l'URL (l'URL est un attribut modifiable de la connexion) ; si Hermes expose un identifiant d'instance, il est stocké comme attribut et vérifié à la reconnexion (mismatch = connexion distincte, pas fusion). Resserrer AD-9 : l'enregistrement d'un suivi envoie un `subscriptionId` généré par le mobile, lié à `ConnectionKey` côté mobile ; le payload ne porte que ce `subscriptionId` + `terminalId` stable. Le registre observateur est indexé par `subscriptionId`, la déduplication reste `(subscriptionId, executionId, terminal)`.

## T6 — Deux normaliseurs de terminal (Dart et observateur) — **Haute**

- **Unité A :** Mobile implémente le normaliseur AD-4 dans `models/` (Dart sans Flutter, « défini une seule fois »).
- **Unité B :** Observateur (runtime non choisi, probablement Python comme Hermes) implémente son propre mapping événement Hermes → `succeeded/failed/stopped/unknown`.
- **Pourquoi les deux sont conformes :** AD-2 impose « une seule définition » mais seulement pour le mobile ; AD-4 impose « contrat commun testé par fixtures » sans dire que l'observateur doit passer les mêmes fixtures ni où vit la table de correspondance.
- **Divergence :** la notification annonce « terminé » alors que l'app, rouverte, affiche `unknown` (ou l'inverse) — exactement l'« état contradictoire entre fil et notification » qu'AD-2 dit empêcher. Une mise à jour Hermes ajoutant un type d'événement est absorbée d'un côté seulement.
- **Correctif :** dans `contracts/`, une table de correspondance déclarative (JSON/YAML) événements Hermes → états de travail et terminaux, avec un corpus de fixtures `entrée → état attendu` ; mobile et observateur la chargent ou la génèrent, et leurs CI exécutent les mêmes fixtures. Toute modification de la table est un changement de contrat à propriétaire unique (même règle que « Après G1 »).

## T7 — Pipeline d'envoi sans point d'extension pour le suivi de notification — **Moyenne**

- **Unité A :** Envoi (AD-5) : persister l'opération → `prompt.submit`. Livré avant G3.
- **Unité B :** Notification (AD-9) : « suivi acquitté avant soumission ». Livré après G3, doit insérer une étape dans un pipeline qu'il ne possède pas.
- **Pourquoi les deux sont conformes :** AD-9 impose l'ordre mais pas qui l'orchestre ni la politique d'échec ; AD-5 ne prévoit pas d'étape préalable.
- **Divergence :** soit l'unité B ajoute un appel dans la ViewModel (contourne le repository), soit elle bloque l'envoi quand l'observateur est absent ou la permission refusée (alors que FR-4 doit fonctionner sans push), soit elle enregistre le suivi après coup (perte de terminaux rapides).
- **Correctif :** dans AD-5, définir le pipeline d'envoi possédé par `DraftRepository` avec des étapes nommées et ordonnées : `persist → ensureSession → attachmentsReady → preSubmitHooks → submit → reconcile`. Le hook de suivi est enregistré à la composition ; politique figée : échec/absence d'observateur = envoi autorisé, indicateur « notification non garantie » sur l'opération, jamais de blocage ni de nouvel essai du prompt.

## T8 — Propriétaire non désigné de `stopRequested` et des intentions de contrôle — **Moyenne**

- **Unité A :** Arrêt (FR-12) garde `stopRequested` dans l'état mémoire de la ViewModel du fil.
- **Unité B :** Conversation fusionne un drapeau `stopRequested` dans la projection de `ConversationRepository` pour l'afficher dans le catalogue d'activité.
- **Pourquoi les deux sont conformes :** les conventions disent que `stopRequested` est « une intention distincte » mais AD-2 ne lui donne pas de propriétaire ; la projection distante n'est pas censée contenir d'état local.
- **Divergence :** après redémarrage ou recomposition du fil (cas listé dans les vérifications), l'un perd l'intention et réaffiche un bouton Arrêter actif, l'autre la conserve et la croise avec une nouvelle exécution (arrêt du tour suivant visuellement attribué). Un snapshot (AD-4) écrase le drapeau injecté dans la projection.
- **Correctif :** les intentions de contrôle sont des opérations AD-5 (`OperationKey`, type `stop`, cible = identité d'exécution observée ou `(session, epoch, seq)` si absente), persistées par `DraftRepository` (ou un `ControlRepository` explicitement nommé), jamais écrites dans la projection. La vue combine projection + opérations via le composeur de T9. Une opération `stop` expire dès qu'un terminal ou une nouvelle exécution est observé.

## T9 — Fusion frise locale / projection sans règle d'appariement — **Moyenne**

- **Unité A :** ViewModel du fil affiche messages en envoi (depuis `DraftRepository`) + projection serveur, et retire l'élément local quand un message utilisateur apparaît dans la projection.
- **Unité B :** Ouverture depuis notification / historique recharge uniquement la projection, et `DraftRepository` retire le brouillon « accepté » sur réponse de `prompt.submit`.
- **Pourquoi les deux sont conformes :** AD-5 interdit l'appariement par texte, mais rien ne définit comment une `OperationKey` est rapprochée d'un message serveur ; aucune règle ne dit où se fait la fusion.
- **Divergence :** doublon visible (local + serveur), ou disparition du message pendant la fenêtre entre acceptation et écho serveur ; les deux écrans d'un même fil divergent.
- **Correctif :** un seul composeur `TimelineProjection(sessionKey)` dans la couche data (lecture seule des deux repositories), réutilisé par tous les écrans. Règle d'appariement fixée dans le contrat G1 : identifiant de message/ tour retourné par l'admission, ou identifiant client transmis si Hermes le renvoie ; à défaut, l'élément local reste visible marqué `accepted` jusqu'au prochain snapshot qui contient un message utilisateur postérieur au curseur d'admission, jamais par texte.

## T10 — Profils : catalogue et sélection sans propriétaire — **Moyenne**

- **Unité A :** Connexion range `profiles.list` dans `ConnectionRepository` (« connexion et capacités »).
- **Unité B :** Accueil/historique range les profils dans `ConversationRepository` (données distantes), et stocke le « profil par défaut » en préférence locale à sa façon.
- **Pourquoi les deux sont conformes :** FR-2/3/10 sont assignés à trois repositories dans la table de couverture sans répartition ; AD-3 interdit d'*inventer* un profil par défaut mais ne dit pas qui mémorise le choix de l'utilisateur.
- **Divergence :** deux listes, deux rafraîchissements, sélection lue à deux endroits ; un nouveau brouillon s'ouvre sur un profil différent selon l'écran d'entrée. Profil supprimé côté serveur : l'un le garde, l'autre le retire.
- **Correctif :** amender AD-2 : `ConnectionRepository` possède le catalogue de profils (par connexion) et la sélection courante ; `DraftRepository` fige le profil dans la `DraftKey` à la création du brouillon. Préciser dans la convention Brouillons : changer de profil sur un brouillon *non matérialisé* (sans session ni pièce) le re-clé ; après matérialisation, ouvre un nouveau brouillon et laisse l'ancien intact. Une seule « nouvelle conversation » non matérialisée par `(connexion, profil)`.

## T11 — Abonnements WebSocket multiples sur une même session — **Moyenne**

- **Unité A :** ViewModel du fil s'abonne aux événements de sa session (via repository) à l'ouverture.
- **Unité B :** Indicateur d'activité de la liste d'historique ou de l'accueil s'abonne aussi pour afficher « en cours ».
- **Pourquoi les deux sont conformes :** AD-4 sérialise les *mutations* par session mais ne dit pas qui ouvre/ferme les flux ni s'il en existe un seul ; AD-7 impose seulement un adaptateur unique.
- **Divergence :** deux appels `session.events.since` avec curseurs différents, deux flux qui alimentent la même projection (le dédoublonnage protège la donnée, pas la charge ni l'ordre des resynchronisations), fermeture du flux par un écran alors que l'autre l'utilise.
- **Correctif :** `ConversationRepository` détient un registre d'abonnements par `SessionKey` avec compteur de références ; les ViewModels demandent `watch(sessionKey)` et reçoivent la projection, jamais un flux brut. Après reconnexion, le repository seul relance la reprise depuis le curseur persisté.

## T12 — Vocabulaire d'activité : traduction côté adaptateur ou côté catalogue — **Moyenne**

- **Unité A :** Adaptateur Hermes (AD-7, seul à connaître les noms Hermes) mappe les outils vers une énumération `ActivityKind` qu'il définit.
- **Unité B :** Catalogue UI (AD-10, « interchangeable par activité structurée ») définit ses propres catégories visuelles et fait un `switch` sur le nom d'outil reçu dans `type`.
- **Pourquoi les deux sont conformes :** la convention Activité dit « type structuré » sans dire qui définit l'ensemble fermé ; « le catalogue visuel n'impose pas 17 types serveur » laisse le choix ouvert.
- **Divergence :** des noms Hermes fuient dans `ui/` (violation d'esprit d'AD-7 mais pas de lettre), ou deux énumérations à maintenir ; un nouvel outil tombe en `unknown` d'un côté et en catégorie spécifique de l'autre.
- **Correctif :** `models/` définit une énumération fermée `ActivityKind` (+ `unknown`) et l'adaptateur est seul à mapper Hermes → `ActivityKind` (table dans `contracts/`, voir T6) ; le catalogue mappe exclusivement `ActivityKind` → visuel et n'a jamais accès au nom d'outil brut sauf comme libellé de détail.

## T13 — Codes d'erreur sans espace de noms — **Basse**

- **Unités A/B :** Connexion et Fichiers définissent chacun `code: "timeout"` / `"too_large"` avec des sens différents (transport vs limite proxy), tous deux dans l'enveloppe partagée.
- **Pourquoi conforme :** la convention Erreurs fixe la forme de l'enveloppe, pas le registre des codes.
- **Divergence :** texte utilisateur et décisions (`retryable`) basés sur un code ambigu ; diagnostics inexploitables.
- **Correctif :** registre unique `models/error_codes` avec préfixe de domaine (`conn.*`, `auth.*`, `file.*`, `send.*`, `notify.*`), un code = un sens ; la distinction d'AD-7 (méthode absente / refus d'auth / panne transitoire) y figure comme codes obligatoires.

## T14 — Clés du stockage sécurisé — **Basse**

- **Unités A/B :** Auth stocke `token` ; Notification stocke `fcm_token` et son `subscriptionId` aussi dans le stockage sécurisé, sans préfixe connexion.
- **Pourquoi conforme :** AD-8 dit « secrets dans le stockage sécurisé » sans schéma de clés.
- **Divergence :** collisions lors d'une seconde connexion, suppression partielle à la révocation (l'auth efface ses secrets, les suivis restent liés à une connexion morte).
- **Correctif :** convention : clés `"<connectionKey>/<domaine>/<nom>"`, accès via un seul `SecretStore` ; la révocation/suppression d'une connexion est une opération unique qui purge secrets, suivis observateur (désinscription) et données locales de cette `ConnectionKey`.

---

## Synthèse des ajouts proposés

| Ajout | Ferme |
| --- | --- |
| AD-12 Matérialisation de session (`ensureSession` unique dans `DraftRepository`) | T1 |
| AD-2 amendé : propriétaires des pièces sortantes, des profils/sélection, des intentions de contrôle, registre d'abonnements | T2, T8, T10, T11 |
| Convention Stockage : une base, registre de migrations append-only, tables préfixées par propriétaire, disposition disque des pièces/résultats | T2, T3 |
| Convention Routes + `resolveLaunchTarget()` unique | T4 |
| AD-3/AD-9 : `ConnectionKey` = UUID local ; `subscriptionId` mobile dans payload et registre | T5 |
| `contracts/` : table déclarative événements → états/terminaux/`ActivityKind` + fixtures partagées mobile/observateur | T6, T12 |
| AD-5 : pipeline d'envoi à étapes nommées + politique d'échec des hooks | T7 |
| Composeur `TimelineProjection` unique + règle d'appariement fixée par G1 | T9 |
| Registres d'erreurs et de clés secrètes | T13, T14 |
