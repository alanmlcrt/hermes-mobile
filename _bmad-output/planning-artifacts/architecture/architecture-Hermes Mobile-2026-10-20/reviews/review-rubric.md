# Revue rubrique — ARCHITECTURE-SPINE.md (Hermes Mobile, 2026-10-20)

**Périmètre :** spine à l'altitude initiative, jugé contre le PRD final (FR-1..10, FR-12, NFR-1..4), le memlog et `integration-evidence.md`. Revue en lecture seule, spine non modifié.

## Verdict

Spine solide sur le cœur client : autorité serveur, identités, réconciliation, idempotence, pièces jointes et séparation réseau/auth. Les AD-1 à AD-8 ferment bien les points de divergence de la couche mobile. Le spine reste pourtant faible sur la frontière **mobile ↔ observateur de notification**. Il contient une contradiction d'ordre entre AD-9 et la porte G3 sur le chemin d'envoi. L'enveloppe opérationnelle (livraison et mise à jour de l'APK, supervision de l'observateur, secrets serveur, sauvegarde Android) reste partiellement muette. On relève aussi un peu de graine UX dans AD-10. Aucun FR obligatoire n'est oublié.

Bilan : **1 critique, 4 élevés, 6 moyens, 5 faibles.**

---

## Critique

### C-1 — AD-9 impose « suivi acquitté avant soumission » alors que G3 bloque l'observateur

- **Constat :** AD-9 exige que le suivi soit acquitté par l'observateur *avant* la soumission du prompt. Or l'observateur n'existe qu'après G3 (`server/notifier/` « seulement après G3 ») et les stories d'envoi (FR-4, AD-5) font partie du socle indépendant. Deux agents vont diverger. L'un bloquera l'envoi tant qu'aucun observateur ne répond. L'autre enverra sans suivi, et FR-9 sera silencieusement perdu pour ces tours. Le spine ne dit pas non plus ce qui se passe à l'exécution si l'observateur est arrêté ou injoignable : faut-il bloquer l'envoi, ou envoyer sans notification ?
- **Correctif proposé :** ajouter à AD-9 une règle explicite. Par exemple : « L'enregistrement du suivi est une étape *best-effort* découplée de l'envoi. Si l'observateur est absent, injoignable ou non déployé, la soumission continue. Le fil marque alors le tour comme `notification non suivie`, et ce marquage est visible. On n'attend jamais l'observateur sans fin, et on ne renvoie jamais le prompt à cause de lui. » Ajouter aussi à AD-2 un propriétaire (`NotificationRepository` ou `ConnectionRepository`) pour l'état de suivi par tour. Si l'on retient l'inverse (blocage), le dire, et sortir l'envoi du « socle indépendant » de G4.

## Élevé

### H-1 — Authentification et contrat mobile → observateur non décidés

- **Constat :** AD-8 décide l'authentification auprès de *Hermes* seulement. Le diagramme montre une flèche « Suivi durable authentifié proposé » vers l'observateur, une seconde origine. Rien ne dit quel credential le mobile présente, ni comment l'observateur l'émet ou le valide, ni s'il réutilise le jeton Hermes. Rien non plus sur l'enregistrement et la rotation du token FCM côté serveur. « Après G3 : endpoints observateur » diffère le schéma, mais pas le *modèle de confiance*. Un agent mobile et un agent serveur peuvent donc construire deux schémas d'auth incompatibles.
- **Correctif proposé :** ajouter une règle à AD-8 ou AD-9. Exemple : « L'observateur est une origine distincte dans le tailnet. Il accepte uniquement [le jeton Hermes vérifié auprès de Hermes | un secret d'appairage propre stocké dans le stockage sécurisé]. Le token push n'est jamais un credential. » Garder le schéma d'endpoint dans `contracts/` après G3.

### H-2 — Source de rattrapage de l'observateur ambiguë face à AD-1 et AD-7

- **Constat :** AD-9 exige un « rattrapage par source Hermes persistante ». AD-1 interdit au *mobile* l'accès aux bases privées Hermes, et AD-7 interdit de répartir *un fil* entre transports. Aucun AD n'interdit explicitement à l'observateur de lire la base SQLite de Hermes ou ses fichiers de session dans le conteneur de l'add-on. Comme ils tournent sur le même hôte, la tentation est forte. Un agent serveur pourrait lire la base directement, et l'observateur divergerait alors de la projection mobile (AD-4).
- **Correctif proposé :** étendre AD-1 : « Ni le mobile ni l'observateur n'accèdent aux stockages privés de Hermes. L'observateur consomme le même contrat que l'adaptateur (`session.events.since` / `session.history` ou équivalent figé en G1), via le même normaliseur (AD-4). » AD-4 dit déjà « tous consommateurs et observateur » dans le memlog : le reporter dans la règle du spine.

### H-3 — Supervision de l'observateur absente (panne silencieuse de FR-9)

- **Constat :** AD-11 prévoit un observateur « supervisé séparément avec volume persistant », mais aucun signal de santé n'est défini. Rien ne dit comment Alanc ou le mobile sait que l'observateur est arrêté, que le token FCM est révoqué, ou que l'outbox s'accumule. La « rupture silencieuse » que AD-11 veut prévenir revient ici précisément pour FR-9.
- **Correctif proposé :** ajouter à AD-11 : « L'observateur expose un état de santé authentifié (vivant, dernier rattrapage réussi, taille de l'outbox, échecs fournisseur). Le mobile l'affiche dans Connexion et marque `notifications indisponibles` sans le confondre avec l'état Hermes. » Ajouter aussi une politique de redémarrage du superviseur.

### H-4 — Enveloppe opérationnelle incomplète : distribution et mise à jour de l'APK, secrets serveur, CI

- **Constat :** les points suivants restent muets, sans être ni décidés, ni différés, ni posés comme questions ouvertes :
  - **Canal de distribution et mise à jour** de l'APK privé (sideload manuel, Firebase App Distribution, Obtainium, etc.). Il conditionne pourtant le cycle « mise à jour backend → revérifier compatibilité ».
  - **Compatibilité de versions client ↔ contrat**. Rien ne dit comment un client ancien détecte un serveur mis à jour : version de contrat négociée, ou refus explicite.
  - **Secrets de l'observateur** : compte de service FCM / credentials Firebase sur l'hôte Home Assistant. Leur stockage et leur rotation ne sont pas couverts, AD-11 ne traitant que les secrets de signature.
  - **Build et CI** : où l'APK est construit et signé, et quels contrôles (tests de fixtures, lint de frontières) bloquent un merge. Rien n'est dit.
- **Correctif proposé :** ajouter une ligne « Exploitation » dans Conventions ou compléter AD-11 :
  - canal de distribution choisi, ou explicitement [ASSUMPTION] « sideload manuel » ;
  - la version du contrat (`contracts/`) est lue au démarrage, et un écart non supporté bloque les mutations avec un message explicite ;
  - les secrets de l'observateur passent par la configuration secrète de l'add-on/hôte, jamais par le dépôt ni le volume de données ;
  - une CI minimale (même locale) exécute analyse, tests de fixtures et contrôle des frontières avant toute story d'intégration.

  À défaut de décision, inscrire chaque point dans « Différé » avec un jalon.

## Moyen

### M-1 — Primitive d'état réactif non fixée

- **Constat :** « MVVM avec primitives Flutter, sans framework » laisse ouverts `ChangeNotifier`, `ValueNotifier` et `Stream` / `StreamController`. Les repositories et ViewModels écrits par des agents différents seront incompatibles : un VM écoute un `Stream`, un autre attend un `Listenable`.
- **Correctif proposé :** une ligne dans Conventions. Exemple : « Repositories : `Stream<Projection>` immuable (ou `ValueListenable`). ViewModels : `ChangeNotifier`. Vues : `ListenableBuilder`. Aucun `setState` porteur d'état métier. »

### M-2 — Cycle de vie de la WebSocket et propriété du socket non définis

- **Constat :** `ConnectionRepository` possède la connexion et `ConversationRepository` la projection. Le spine ne dit pas qui ouvre et ferme le socket JSON-RPC. Il ne dit pas non plus si un socket unique multiplexe plusieurs sessions, ni ce qui se passe quand l'app passe en arrière-plan ou revient au premier plan. Des agents risquent d'ouvrir un socket par écran ou par session.
- **Correctif proposé :** ajouter à AD-2 ou AD-7 : « Un seul transport WS par connexion, possédé par `ConnectionRepository`. Les abonnements de session sont routés vers `ConversationRepository`. Fermeture à la mise en arrière-plan, puis snapshot et reprise (AD-4) au retour. Aucun maintien de socket en arrière-plan pour FR-9. »

### M-3 — Source du « profil par défaut » non fixée

- **Constat :** FR-2 et la convention Accueil utilisent un « profil par défaut ». AD-3 interdit d'en inventer un en cas d'échec, mais ne dit pas *qui* le désigne : un drapeau Hermes, une préférence locale, ou le premier de la liste. Deux stories (Accueil, Profils) peuvent diverger.
- **Correctif proposé :** « Le profil par défaut est celui désigné par Hermes s'il l'expose, à vérifier en G1. Sinon, c'est une préférence locale explicite, choisie par Alanc et possédée par `ConnectionRepository`. Jamais un ordre de liste. »

### M-4 — Sauvegarde Android et contenu conversationnel au repos

- **Constat :** AD-8 exclut les *secrets* des sauvegardes. Or SQLite (projection, brouillons) et les pièces privées contiennent du contenu de conversation et des fichiers personnels, que la sauvegarde automatique Android (Google Drive / transfert d'appareil) emporterait par défaut. Le chiffrement au repos n'est pas non plus abordé.
- **Correctif proposé :** ajouter à AD-8 : « `allowBackup=false`, ou règles d'exclusion couvrant base, pièces et préférences sensibles. Le contenu local est un cache récupérable depuis Hermes. » Indiquer [ASSUMPTION] si le chiffrement SQLite est jugé inutile pour un usage personnel.

### M-5 — Règles sans mécanisme de vérification

- **Constat :** plusieurs règles sont énonçables mais ne disent pas comment on les fait respecter. C'est le cas de « modèles sans Flutter », « seul l'adaptateur connaît les noms Hermes », « vues sans appel réseau » et « sans service locator ». Dans une flotte d'agents, une règle non outillée dérive.
- **Correctif proposé :** ajouter une ligne « Frontières » dans Conventions. Exemple : « `lib/models/` n'importe ni `package:flutter` ni `data/`. Seul `lib/data/hermes/` importe les noms de méthodes et formats Hermes. `features/` n'importe pas `data/` sauf les interfaces de repositories. Le tout est vérifié par un test d'imports ou par `custom_lint` en CI. »

### M-6 — Bloat : graine UX et rationnel dans les règles

- **Constat :**
  - AD-10 décrit des dessins précis (« trois petits points tournants sans bulle », « ordinateur fixe avec mouvement interne », « commandes de lecture des maquettes hors produit »). C'est de la spécification UX (DESIGN.md / EXPERIENCE.md), pas un invariant de cohérence. L'invariant utile est : catalogue piloté par activité structurée, animations sans autorité, mouvement réduit respecté, tokens uniques.
  - Le paragraphe d'introduction « Proposition en mode rapide… » et le memlog recopié dans les rationnels (« Prevents » étendus) alourdissent.
  - Le dernier point de « Différé » (voix, routines, Discord, MCP après MVP) relève du périmètre PRD, pas de l'architecture.
  - « Livraison iOS distincte avec environnement Apple » est dupliqué entre AD-11 et Différé.
  - « Vérifications du contrat » est une graine de tests utile, mais relève d'un plan de test.
- **Correctif proposé :**
  - réduire AD-10 à ses invariants et renvoyer les dessins vers DESIGN.md ;
  - remplacer le dernier point de Différé par « Hors périmètre : voir PRD » ;
  - supprimer le doublon iOS d'AD-11 ;
  - déplacer « Vérifications du contrat » vers `contracts/README` ou le plan de test, en gardant une seule phrase de renvoi.

## Faible

### L-1 — Flutter épinglé sans correctif

- **Constat :** `integration-evidence.md` note « dernier correctif non déterminé », mais le tableau fixe `3.47.0`. Un agent pourrait initialiser sur `3.47.0` alors qu'un `3.47.x` corrige des bugs.
- **Correctif proposé :** écrire « 3.47.x (dernier correctif stable au bootstrap, épinglé via FVM / `.fvmrc` ou `flutter --version` consigné) ».

### L-2 — Paquet Markdown : éviter un paquet abandonné

- **Constat :** le choix du rendu Markdown (FR-4) est différé au bootstrap. `flutter_markdown` a été déclaré abandonné (*discontinued*) par l'équipe Flutter en 2025. Un agent qui choisit « le paquet officiel » de mémoire tomberait dessus.
- **Correctif proposé :** dans Différé/bootstrap, ajouter le critère « paquet maintenu (non *discontinued* sur pub.dev), rendu du code et des emojis vérifié ». Un candidat comme `flutter_markdown_plus` est à vérifier au bootstrap.

### L-3 — Compatibilité des versions candidates non résolue

- **Constat :** les versions sont vérifiées une par une, sans `flutter pub get` ni compilation. Les contraintes de `firebase_messaging 17` (minSdk, AGP/Gradle, Kotlin) peuvent entrer en conflit avec le starter.
- **Correctif proposé :** faire de « résolution + build debug Android réussis » la première tâche du bootstrap, avant toute story, et consigner minSdk/targetSdk dans le spine une fois résolus.

### L-4 — Flavors / environnements côté mobile

- **Constat :** des « destinations push séparées » sont exigées, mais rien ne dit comment l'app sépare les projets Firebase de test et personnel (flavors, `google-services.json` par variante).
- **Correctif proposé :** ajouter « une variante Android par environnement push (`dev`, `perso`), sans jamais partager un projet FCM entre elles », ou différer explicitement à G3.

### L-5 — Rafraîchissement des profils (FR-10)

- **Constat :** FR-10 est couvert via AD-3/AD-7, mais aucune règle ne dit qui déclenche l'actualisation. On ne sait pas non plus si un profil disparu côté Hermes rend ses fils locaux orphelins ou les masque.
- **Correctif proposé :** dans AD-3, ajouter : « Un profil absent d'une liste fraîche reste affiché pour ses fils existants comme `indisponible`. Il n'est jamais supprimé localement ni réaffecté. »

---

## Contrôle de la checklist

| Critère | État |
| --- | --- |
| Points de divergence réels fixés | Oui pour le client. Lacunes : frontière observateur (C-1, H-1, H-2), primitive d'état (M-1), socket (M-2), profil par défaut (M-3). |
| Règles applicables et efficaces | Globalement oui. Pas de mécanisme de vérification (M-5). La règle d'AD-9 crée une contradiction (C-1). |
| « Différé » sans risque de divergence | Acceptable : un seul propriétaire, choix central au bootstrap. Ajouter des critères à L-2 et L-3. |
| Technologies vérifiées et actuelles | Oui (vérification datée du 20/10/2026, sources dans evidence). Réserves L-1, L-2, L-3. |
| Couverture FR-1..10, FR-12, NFR | Complète. FR-11 retiré, FR-13/14 bien conditionnés à G4. |
| Dimensions de l'altitude décidées, différées ou ouvertes | Déploiement et environnements partiels. Stratégie de fournisseur (FCM [ASSUMPTION], Tailscale Serve [ASSUMPTION]) correcte. **Exploitation incomplète** : supervision de l'observateur, distribution et mise à jour, CI, secrets serveur, sauvegarde (H-3, H-4, M-4). |
| Bloat | Modéré (M-6). |
