---
status: final
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-Hermes-Mobile-2026-10-20/prd.md
  - _bmad-output/planning-artifacts/prds/prd-Hermes-Mobile-2026-10-20/addendum.md
  - _bmad-output/planning-artifacts/architecture/architecture-Hermes Mobile-2026-10-20/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/architecture/architecture-Hermes Mobile-2026-10-20/integration-evidence.md
  - _bmad-output/planning-artifacts/ux-designs/ux-Hermes Mobile-2026-10-20/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-Hermes Mobile-2026-10-20/EXPERIENCE.md
  - _bmad-output/planning-artifacts/ux-designs/ux-Hermes Mobile-2026-10-20/ui-evolution-requirements.md
decisions:
  - "2026-10-20 : FR-13 et FR-14 inclus dans le découpage (Alanc), stories conditionnées à la porte G4 et aux capacités Hermes détectées."
  - "2026-10-20 : voix, routines, groupes d'agents et diffusion publique exclus du MVP ; l'import Discord est retiré du projet (Alanc)."
---

# Hermes Mobile - Epic Breakdown

## Overview

Ce document découpe en epics et stories implémentables les exigences du PRD, du contrat UX (DESIGN.md + EXPERIENCE.md) et de l'architecture de Hermes Mobile.

## Requirements Inventory

### Functional Requirements

FR1 : Accès distant — Alanc connecte l'application à son serveur Hermes par le réseau Tailscale existant. Association initiale par QR code ou lien (`hermes-mobile://pair?url=<origine>`), avec saisie manuelle de secours ; la connexion est mémorisée. Un échec indique distinctement serveur inaccessible ou authentification refusée.
FR2 : Accueil — À une ouverture normale, une nouvelle conversation est préparée avec le profil par défaut, sans enregistrer de fil vide avant le premier envoi. Un retour temporaire dans l'app conserve le travail en cours. Une notification de fin ouvre la conversation concernée.
FR3 : Profils et historique — Alanc sélectionne un profil existant, retrouve ses conversations et en crée une nouvelle. Changer de profil ne mélange ni messages ni fichiers entre conversations.
FR4 : Échanges texte — Alanc saisit et colle de longs textes, lit des réponses avec emojis, mise en forme et code, sans commandes `/` pour les actions courantes. La réponse apparaît progressivement ; les limites serveur ou modèle sont expliquées sans perte du brouillon. Taille de texte de référence à fixer.
FR5 : Préparation des pièces jointes — Alanc joint photos, captures, PDF, documents bureautiques et autres fichiers à une demande. Il vérifie la liste, voit l'aperçu des images et retire un fichier avant l'envoi. Les limites effectives de type, nombre et taille sont indiquées avant l'envoi.
FR6 : Transmission des pièces jointes — Les fichiers acceptés sont transmis à la bonne conversation et restent identifiables dans son historique. L'état d'envoi et les échecs sont visibles ; un échec n'est jamais présenté comme un fichier reçu par Hermes. Le traitement sémantique des images dépend du modèle et doit être explicite.
FR7 : Actions dépliables — L'application montre une synthèse de l'activité et permet d'en déplier les détails fournis par Hermes (outils, commandes CLI, sorties, erreurs disponibles). Aucun contenu interne non exposé n'est inventé.
FR8 : Travail distant — Quitter l'app n'annule pas le travail accepté par le serveur. À la reconnexion, messages et état d'exécution sont retrouvés ; une demande au résultat incertain n'est pas renvoyée automatiquement.
FR9 : Notification de fin — Alanc est averti de la fin d'un travail hors de l'app ; la notification ouvre la conversation. Le résultat distingue réussite, erreur et arrêt confirmé, les trois déclenchant une notification. Comportement app fermée à vérifier sur téléphone réel.
FR10 : Profils disponibles — Les profils existants sur Hermes sont listés et sélectionnables sans les recréer ni saisir leur configuration. La liste distingue les profils et identifie celui de la conversation. Une actualisation retrouve un profil ajouté côté Hermes ; un échec de chargement est distingué d'une liste vide.
FR12 : Arrêter le travail — Alanc demande l'arrêt de l'exécution en cours depuis la conversation, sans commande `/`. L'interface distingue demande d'arrêt envoyée et arrêt confirmé par Hermes ; une perte réseau ne vaut pas confirmation. Arrêter n'annule pas les effets déjà produits.
FR13 : Répondre et autoriser [inclus, conditionné à G4] — Quand Hermes attend une précision ou une autorisation, la demande apparaît dans la conversation et Alanc y répond depuis l'app. L'autorisation présente la demande réellement émise par Hermes ; aucune politique d'approbation inventée. La prise en compte immédiate ou différée d'une intervention pendant l'exécution est explicite.
FR14 : Récupérer les résultats [inclus, conditionné à G4] — Les fichiers rendus accessibles par Hermes sont identifiables dans la conversation, ouvrables ou téléchargeables selon leur format. L'interface distingue un résultat disponible d'un simple chemin serveur inaccessible depuis le téléphone.

Retiré : FR11 (sauvegarde de réglages depuis l'app), identifiant réservé. Hors MVP : écran de consultation ou d'administration des profils.

### NonFunctional Requirements

NFR1 : Mobile et accessibilité — Parcours essentiels utilisables au toucher avec clavier affiché, texte agrandi et lecteur d'écran. Icônes d'action avec libellé accessible ; aucun état exprimé seulement par la couleur.
NFR2 : Fiabilité — Une coupure réseau ne masque pas un échec, ne perd pas un brouillon existant et ne provoque pas silencieusement une nouvelle exécution.
NFR3 : Accès et secrets — Tailscale fournit le réseau ; l'authentification Hermes reste nécessaire. Aucun secret dans les erreurs ou journaux de diagnostic.
NFR4 : Compatibilité — Les capacités du serveur sont vérifiées pour chaque fonction ; une fonction absente est signalée clairement. Une capacité obligatoire non démontrée sur l'installation réelle bloque l'acceptation du MVP ; son retrait ou report exige une décision explicite d'Alanc.
NFR5 : Acceptation réelle — Le MVP est accepté après un essai Android à distance sur l'installation réelle : nouvelle conversation par défaut, profils affichés, échanges avec deux profils et reprise d'historique, long texte, image et document reçus par Hermes, détail d'une action, fin de travail notifiée app quittée, demande d'arrêt confirmée, réponse à une question, et si exposés : autorisation et récupération d'un fichier résultat. Indicateur : aucune duplication d'exécution ni perte de brouillon. Aucune simulation locale ne vaut validation.
NFR6 : Corpus — Avant les tests d'acceptation, Alanc fournit un long texte, une photo ou capture, un PDF et un document bureautique représentatifs ; formats, volumes et limites prises en charge sont consignés.

### Additional Requirements

**Starter et stack (impacte Epic 1 Story 1)**
- Graine : `flutter create --empty --platforms=android,ios hermes_mobile`, Flutter 3.47.x (dernier correctif au bootstrap), Dart fourni. minSdk Android 24. Flutter n'est confirmé que si le bootstrap compile et tourne sur le téléphone Android d'Alanc ; sinon le choix de stack revient à Alanc avant toute autre story.
- Paquets candidats : dynamic_color 2.1.0, sqflite 2.4.4+2, flutter_secure_storage 11.2.0 (`allowBackup=false`), firebase_messaging 17.0.0 + firebase_core ^5.0.0 sous réserve de G3. Pas de `flutter_markdown` (abandonné). Paquets réseau, fichiers, Markdown et routage choisis centralement, épinglés, résolus ensemble et compilés pour Android au bootstrap ; SDK épinglé + lockfile font référence.
- Arborescence : `lib/app` (composition, routes, `resolveLaunchTarget`), `lib/models` (sans Flutter), `lib/data` (repositories, adaptateur, stockage), `lib/features` (vues, ViewModels), `lib/ui` (tokens, thème, composants, catalogue), `contracts/`, `server/hermes-plugin/` (plugin de notifications).

**Architecture applicative**
- MVVM léger : ViewModels `ChangeNotifier`, repositories exposant des `Stream` de snapshots immuables, aucun autre framework d'état, injection explicite au démarrage sans service locator (AD-2).
- Propriétaires uniques : `ConnectionRepository` (connexions, capacités, profils, profil sélectionné, unique socket par connexion), `ConversationRepository` (projection distante, `TimelineProjection`), `OutboxRepository` (brouillons, pièces sortantes, `ensureSession(DraftKey)` sérialisé, opérations envoi/arrêt/suivi notification). Les vues ne font ni réseau ni écriture persistante. Contrôle des imports en CI (AD-2).
- Identités : `ConnectionKey` UUID local stable (URL modifiable sans réindexation), `ProfileKey`, `SessionKey` opaques sensibles à la casse ; `DraftKey` local associé à la session avant soumission ; `OperationKey` local distinct de l'identité d'exécution serveur ; `sessionId` stocké, porté par la notification push. Le profil d'un fil existant ne change jamais. Pas de profil par défaut inventé si la découverte échoue (AD-3).
- Projection : table déclarative événements Hermes → états/terminaux/`ActivityKind` dans `contracts/`, côté mobile, validée par les mêmes fixtures. Mutations sérialisées par session, projection et curseur enregistrés atomiquement. Curseur `(epoch, seq)` seulement si détecté, sinon snapshot complet. Doublons écartés, trou/troncature/nouvel epoch → snapshot, événements anciens écartés. Rapprochement local/serveur jamais par le texte (règle fixée en G1). Connexion et travail sont deux états distincts (AD-4).
- Soumission : opération persistée avant envoi (cible, contenu exact, références fichiers) ; pipeline nommé `ensureSession` → pièces → suivi notification (non bloquant) → soumission. Résultat incertain → `unknown`, brouillon conservé, pas de renvoi. Répétition seulement si idempotence détectée (un ID JSON-RPC n'en est pas une). Un seul envoi à la fois par session ; saisie conservée pendant le travail. Arrêt = opération persistée visant l'exécution observée, jamais rejouée après changement de tour ; `stopRequested` hors projection ; seul le serveur fournit un terminal (AD-5).
- Pièces jointes : copie dans `attachments/<DraftKey>/`, résultats dans un emplacement séparé. Validation contre la limite la plus restrictive (app, proxy, Hermes, modèle). Prompt envoyé seulement après confirmation de toutes les pièces ; upload échoué ou incertain bloque le prompt. Résultat disponible seulement après accès authentifié résolu ; aucun fichier exécuté automatiquement (AD-6).

**Intégration Hermes**
- Point d'entrée unique : backend Desktop `hermes serve` (add-on `WolframRavenwolf/hermes-ha-addon` 1.3.9, option `enable_desktop_backend`, port 9119 à mapper) ; REST pour les ressources, JSON-RPC sur `/api/ws`. Ni ingress `:8123`, ni 8080/8443, ni `/v1/`. Seuls l'adaptateur et le plugin de notifications connaissent les formats Hermes. Un fil n'est jamais réparti entre plusieurs transports (AD-7).
- Référence = tag de release correspondant au build installé, jamais HEAD. Capacités optionnelles (`replay_epoch`, `idempotency_key`, `file.attach`…) détectées à la connexion et enregistrées. Contrat, échanges anonymisés et fixtures figés dans `contracts/` avant les stories d'intégration. Méthode absente, refus d'auth et panne transitoire produisent des erreurs distinctes. Ne pas modifier le profil actif global du dashboard à chaque sélection mobile (AD-7, evidence).
- Auth : login Basic (utilisateur `hermes`, `access_password`) → jeton d'accès 12 h + refresh 30 j ; sockets ouvertes par ticket WS. Le secret serveur change à chaque redémarrage : le mot de passe est gardé en stockage sécurisé et l'app se reconnecte seule quand le refresh échoue (AD-8).
- Réseau : origine `http://<hôte>.ts.net:9119` ; exception `network_security_config` limitée à `ts.net`, refus de tout `http://` hors `*.ts.net`, `https://` accepté. QR contenant seulement l'origine, confirmation de l'origine puis saisie du mot de passe une fois ; script du dépôt pour générer le QR. Secrets sous `<ConnectionKey>/<usage>`, jamais dans URL persistées, notifications, diagnostics ou sauvegardes. Aucun credential envoyé à une autre origine après redirection (AD-8).

**Notifications (G3)**
- Observateur serveur distinct, registre de suivis (`subscriptionId`) et outbox durables, reprise après redémarrage par rattrapage depuis la source Hermes persistante, déduplication par cible/exécution/terminal, point de santé affiché dans l'app (AD-9).
- Suivi = jeton FCM transmis au plugin Hermes (`command.dispatch`) avant soumission, jamais bloquant : tour marqué « notification non suivie » si le plugin est absent (4018). Payload `{outcome, sessionId}` et libellé générique, sans texte, chemin ni secret. FCM HTTP v1, compte de service dans `HERMES_HOME/hermes-mobile/`. Ouverture à froid et à chaud, rotation du token, un seul nouvel essai FCM (AD-9).
- Plugin `on_session_end` par profil, tours `tui` seulement ; sans outbox durable ni rattrapage (perte acceptée si Hermes plante en plein tour). Proposition de changement du 2026-10-29.

**Exploitation**
- Un seul fichier SQLite, tables préfixées par repository propriétaire, migrations en ajout seul et testées ; aucune migration de Hermes (AD-11).
- Environnements isolés : fixtures sans secrets, intégration sur profil de test dédié, usage réel. Clés, bases et destinations push séparées (AD-11).
- Au démarrage, comparaison capacités détectées / exigées avec affichage de l'écart ; revérification après mise à jour de Hermes (AD-11).
- Logs à codes namespacés `domaine.code` et identifiants de corrélation locaux, sans contenu conversationnel ni credentials (AD-11).
- Enveloppe d'erreur partagée : `code` namespacé, `retryable`, `operationKey?` ; texte utilisateur distinct du diagnostic expurgé. Dates UTC ISO 8601, ordre causal fourni par le serveur.
- Navigation : table unique de routes typées (`/c/<ConnectionKey>/<ProfileKey>/<SessionKey>`, `/draft/<DraftKey>`), `resolveLaunchTarget()` : notification, puis restauration, puis accueil.
- APK privé, signé, versionné, installé manuellement ; secrets de signature et FCM hors dépôt. CI : analyse, tests, contrôle des imports, build Android.

**Portes de validation**
- G1 installation : backend Desktop actif, port 9119 mappé, tag installé et capacités détectées, origine joignable depuis le téléphone, login et ticket WS, deux profils, historique, envoi, reprise après redémarrage du backend, arrêt, règle de rapprochement. Bloque les stories d'intégration au-delà de la capture du contrat (qui en est la première) ; l'UI sur fixtures peut avancer.
- G2 fichiers : limites et réception dans le bon fil, corpus d'Alanc.
- G3 notification : plugin installé par profil, jeton app → plugin, filtre `tui`, version FCM, prérequis Android, essais app fermée, coupure réseau, sous-agent, reprise de conversation.
- G4 produit/UX : FR-13/14, interventions en cours, issues notifiées, secours de thème.
- Cas de contrat à tester : IDs similaires sur deux profils ; coupure après acceptation avant réponse ; événement dupliqué/tronqué/ancien ; arrêt après reconnexion ; upload échoué sans prompt ; fin app fermée ; plugin absent pendant un envoi ; changement d'URL sans réindexation.

### UX Design Requirements

UX-DR1 : Tokens sémantiques centralisés — Une source unique pour couleurs par rôle, typographie, espacements, rayons, élévations, tailles d'icônes et paramètres de mouvement. Modifier une valeur à un seul endroit se répercute sur tous les composants concernés ; aucune valeur visuelle dispersée dans les écrans.
UX-DR2 : Thème système — Clair/sombre suivant automatiquement le téléphone ; Dynamic Color Android (API 31+) avec liaisons de rôles canvas=surface, content=onSurface, emphasis=primary, emphasis-content=onPrimary, résolues à l'exécution, jamais en hexadécimal figé. Aucune couleur de marque.
UX-DR3 : Palette de secours — Palette claire/sombre centralisée pour les appareils sans couleurs dynamiques, avec paires de contraste et usage de l'erreur vérifiés (porte G4).
UX-DR4 : Typographie lisible — Hiérarchie de texte adaptée aux longs messages et au code, compatible texte agrandi ; tokens à finaliser.
UX-DR5 : Composant Connexion — Saisie/scan de l'origine, confirmation, mot de passe ; messages distincts « serveur inaccessible » et « authentification refusée » ; états chargement et retour après échec.
UX-DR6 : Composant Choix du profil — Liste des profils distinguables, profil actif identifiable, actualisation ; états chargement, liste vide et erreur distincts.
UX-DR7 : Composant Historique — Conversations d'un profil distinguables, historique vide et reprise traités.
UX-DR8 : Composant Message de conversation — Rendu Markdown (mise en forme, emojis, blocs de code lisibles), réponse progressive ; états envoi, travail, fin, erreur, inconnu/non synchronisé.
UX-DR9 : Composant Saisie et envoi — Longs textes et collage, utilisable clavier affiché, sans commande `/` ; brouillon jamais perdu ; saisie conservée et non soumise pendant le travail.
UX-DR10 : Composant Pièce jointe — Liste, aperçu image, retrait, limites affichées avant envoi ; états sélection, envoi, échec, reçu ; identifiable dans l'historique.
UX-DR11 : Composant Suivi d'activité compact — Ligne d'activité avec petite illustration à côté du libellé (emplacement de référence 64 × 44 px), signe de fin sur les lignes terminées, groupe d'outils repliable, détails dépliables (outils, commandes, sorties, erreurs exposés par Hermes).
UX-DR12 : Catalogue d'illustrations indexé par `ActivityKind` — 17 familles : code, création de fichier, modification de fichier, appel d'outil, recherche web, navigation web, lecture, commande, recherche de fichier, création d'image, analyse d'image, mémoire, délégation, organisation, compétence, planification, préparation de réponse ; plus un fallback générique. Chaque entrée : rendu, paramètres de mouvement, variante immobile. Remplaçable sans toucher au décodage des événements ; jamais indexé par emoji, nom d'outil MCP ou minuterie.
UX-DR13 : Indicateur de préparation — Trois petits points tournants (SVG de référence 24 × 24 px), sans bulle ni grand dessin, pour la préparation de réponse et l'activité inconnue ; aucun détail inventé.
UX-DR14 : Illustration « code » — Châssis d'ordinateur fixe, seules les lignes et le curseur bougent ; traits épais (≈ 3,4 unités dans la maquette).
UX-DR15 : Mouvement — Animations purement illustratives : elles ne décident jamais de l'état ni de la fin d'un outil, ne représentent ni pourcentage ni mesure ; mouvement réduit respecté (figures immobiles, réponse non tapée caractère par caractère) ; arrêt hors écran.
UX-DR16 : Composant Arrêt — Contrôle accessible (nom « Arrêter ») toujours atteignable même indicateur réduit ; distingue « arrêt demandé » et « arrêt confirmé » ; jamais « arrêté » sans confirmation serveur.
UX-DR17 : Composant Intervention (FR-13) — Question ou autorisation réellement émise par Hermes, affichée dans le fil avec réponse possible ; prise en compte immédiate ou différée explicite.
UX-DR18 : Composant Résultat (FR-14) — Fichier résultat identifiable dans le fil (cf. `resume.md` de la scène), ouvrable/téléchargeable ; distinction résultat disponible / chemin serveur inaccessible.
UX-DR19 : Notification de fin — Conversation concernée identifiable, issue (réussite, erreur, arrêt confirmé) ; refus de permission expliqué ; marque visible « notification non suivie » sur un tour.
UX-DR20 : États de connexion — `connecté`, `resynchronisation`, `hors ligne` affichés distinctement des états du travail ; écart de capacités visible.
UX-DR21 : Accessibilité — Noms accessibles pour toutes les icônes d'action, cibles tactiles suffisantes, texte agrandi, lecteur d'écran (ordre de lecture et annonces des changements d'état), aucun état par la seule couleur, dans les deux thèmes.
UX-DR22 : Contenu séparé — Libellés et messages d'interface séparés des dessins et styles ; vocabulaire quotidien (Profil, Conversation), détails techniques non dominants.
UX-DR23 : Galerie de fixtures — Galerie des composants et états représentatifs, données fictives, examinable en clair, sombre, texte agrandi et mouvement réduit, pour comparer les changements visuels.
UX-DR24 : Indépendance rendu/état — Changer la composition du fil conserve conversations, brouillons, fichiers et état du travail ; aucun appel rejoué par un nouveau rendu. Les maquettes (`mockups/simple-conversation.html`, `mockups/exchange-conversation.html`) sont la référence visuelle, pas une logique de production.

### FR Coverage Map

FR1 : Epic 1 — Appairage Tailscale, authentification, erreurs distinctes
FR2 : Epic 2 — Accueil sur nouvelle conversation par défaut (ouverture par notification : Epic 5)
FR3 : Epic 2 — Sélection de profil, historique et conversations cloisonnées
FR4 : Epic 2 — Longs textes, réponse progressive et rendu enrichi
FR5 : Epic 4 — Préparation des pièces jointes et limites
FR6 : Epic 4 — Transmission vérifiée au bon fil
FR7 : Epic 3 — Synthèse d'activité et détails dépliables
FR8 : Epic 2 — Continuité du travail et reprise sans renvoi
FR9 : Epic 5 — Notification de fin app quittée
FR10 : Epic 1 — Découverte et actualisation des profils Hermes
FR12 : Epic 3 — Arrêt demandé / confirmé
FR13 : Epic 6 — Questions et autorisations de Hermes
FR14 : Epic 6 — Récupération des fichiers résultats
NFR1 : Epics 1 à 6 — critère transverse ; galerie et accessibilité posées en Epic 1, mouvement réduit en Epic 3
NFR2 : Epic 2 (envoi, brouillons), repris en Epics 3, 4, 6
NFR3 : Epic 1 (secrets, auth), repris en Epic 5 (payload push)
NFR4 : Epic 1 (détection des capacités), repris par chaque epic d'intégration
NFR5 : Epic 6 — Story finale d'essai d'acceptation réel
NFR6 : Epic 4 — Corpus de test fourni par Alanc

## Epic List

### Epic 1 : Connecter l'app à mon Hermes et voir mes profils
Alanc installe l'APK, appaire l'app à son serveur (QR ou URL), s'authentifie une fois et voit ses profils Hermes ; serveur injoignable, authentification refusée et capacités manquantes sont signalés distinctement. Inclut le bootstrap Flutter validé sur téléphone, les fondations de thème et de galerie, la CI, et la capture du contrat Hermes (début de G1).
**FRs covered:** FR1, FR10 · NFR3, NFR4

### Epic 2 : Converser avec un profil et retrouver mes conversations
À l'ouverture, une nouvelle conversation est prête avec le profil par défaut. Alanc envoie de longs textes, lit les réponses en streaming avec mise en forme et code, retrouve et reprend les conversations de chaque profil. Quitter l'app ou perdre le réseau ne perd ni brouillon ni travail, et rien n'est renvoyé en double. Requiert G1.
**FRs covered:** FR2, FR3, FR4, FR8 · NFR2

### Epic 3 : Suivre le travail de Hermes et l'arrêter
L'activité apparaît en lignes compactes illustrées (catalogue de 17 familles indexé par `ActivityKind`, trois points tournants, ordinateur fixe), avec détails dépliables réellement fournis par Hermes. Alanc demande l'arrêt et distingue arrêt demandé et arrêt confirmé.
**FRs covered:** FR7, FR12 · NFR1

### Epic 4 : Joindre photos et documents à mes demandes
Alanc joint photos, captures, PDF et documents, voit aperçus et limites, retire un fichier, et sait si chaque fichier a réellement été reçu par Hermes dans la bonne conversation. Requiert G2.
**FRs covered:** FR5, FR6 · NFR6

### Epic 5 : Être averti quand Hermes a fini
App quittée, Alanc reçoit une notification de fin (réussite, erreur, arrêt confirmé) qui ouvre la bonne conversation. Inclut le plugin Hermes de notifications, FCM et `resolveLaunchTarget` ; l'observateur des stories 5.1–5.4 est remplacé (proposition du 2026-10-29). Requiert G3.
**FRs covered:** FR9 (et ouverture depuis notification de FR2)

### Epic 6 : Répondre à Hermes et récupérer ses résultats
Les questions et autorisations émises par Hermes apparaissent dans le fil et Alanc y répond ; les fichiers produits s'ouvrent ou se téléchargent depuis la conversation. Se termine par l'essai d'acceptation réel du MVP. Requiert G4 et les capacités exposées.
**FRs covered:** FR13, FR14 · NFR5

## Epic 1 : Connecter l'app à mon Hermes et voir mes profils

Alanc installe l'APK, appaire l'app à son serveur, s'authentifie une fois et voit ses profils Hermes ; serveur injoignable, authentification refusée et capacités manquantes sont signalés distinctement.

### Story 1.1 : Initialiser l'application et la valider sur mon téléphone

En tant qu'Alanc,
Je veux une application Flutter minimale installée et lancée sur mon téléphone Android,
Afin de confirmer la stack avant tout autre développement.

**Critères d'acceptation :**

**Étant donné** un dépôt sans code applicatif
**Quand** le projet est généré par `flutter create --empty --platforms=android,ios hermes_mobile` avec Flutter 3.47.x (dernier correctif) épinglé
**Alors** l'arborescence `lib/app`, `lib/models`, `lib/data`, `lib/features`, `lib/ui`, ainsi que `contracts/` à la racine, existe
**Et** minSdk Android vaut 24 et `android:allowBackup="false"` est défini

**Étant donné** les paquets candidats (dynamic_color 2.1.0, sqflite 2.4.4+2, flutter_secure_storage 11.2.0) et les choix centraux réseau, Markdown, fichiers et routage (sans `flutter_markdown`)
**Quand** ils sont ajoutés
**Alors** ils sont résolus ensemble, le lockfile est commité et un build Android release compile
**Et** firebase_messaging n'est pas ajouté (attente de G3)

**Étant donné** un APK signé et versionné, la clé de signature hors du dépôt
**Quand** Alanc l'installe manuellement sur son téléphone
**Alors** l'application s'ouvre sans erreur
**Et** si l'installation ou le lancement échoue, le travail s'arrête et le choix de stack revient à Alanc

**Étant donné** la CI
**Quand** une modification est poussée
**Alors** elle exécute analyse, tests, contrôle des imports (`lib/models` sans Flutter, vues sans accès `lib/data`) et build Android

### Story 1.2 : Poser le thème système, les tokens et la galerie de composants

En tant qu'Alanc,
Je veux une apparence qui suit le mode clair/sombre et les couleurs de mon téléphone, définie à un seul endroit,
Afin de pouvoir ajuster ou refondre le design sans toucher au fonctionnement.

**Critères d'acceptation :**

**Étant donné** Android 12+ avec couleurs dynamiques
**Quand** l'app démarre en mode clair puis sombre
**Alors** les rôles canvas=surface, content=onSurface, emphasis=primary, emphasis-content=onPrimary sont résolus à l'exécution (UX-DR2), sans couleur hexadécimale dans les composants

**Étant donné** un appareil sans couleurs dynamiques
**Quand** l'app démarre
**Alors** une palette de secours claire/sombre centralisée dans le thème est appliquée (UX-DR3, valeurs provisoires jusqu'à G4)

**Étant donné** la source unique de tokens (couleurs par rôle, typographie, espacements, rayons, élévations, tailles d'icônes, mouvement) (UX-DR1, UX-DR4)
**Quand** une valeur d'espacement ou de rôle est modifiée à un seul endroit
**Alors** tous les composants de la galerie reflètent la modification
**Et** un test empêche les valeurs visuelles littérales hors de `lib/ui`

**Étant donné** la galerie de fixtures (UX-DR23)
**Quand** elle est ouverte en build de développement
**Alors** chaque composant présent s'affiche en clair, sombre, texte agrandi (200 %) et mouvement réduit, avec données fictives
**Et** les libellés proviennent d'un fichier de contenu séparé des styles (UX-DR22)

### Story 1.3 : Capturer le contrat Hermes de mon installation

En tant qu'Alanc,
Je veux que le contrat réel de mon Hermes soit relevé et figé dans le dépôt,
Afin que l'app soit construite sur ce que mon serveur expose vraiment, pas sur HEAD amont.

**Critères d'acceptation :**

**Étant donné** l'add-on `hermes-ha-addon` 1.3.9 avec `enable_desktop_backend` activé et le port 9119 mappé (procédure documentée dans `contracts/README.md`)
**Quand** le tag de release Hermes installé est lu sur l'instance
**Alors** `contracts/` contient ce tag, l'extrait OpenRPC correspondant et la liste des méthodes REST/JSON-RPC utilisées (login, ticket WS, profils, sessions, historique, soumission, événements, interruption, fichiers, approbations)

**Étant donné** des échanges réels depuis le PC puis depuis le téléphone via `http://<hôte>.ts.net:9119`
**Quand** ils sont enregistrés
**Alors** ils sont anonymisés (aucun mot de passe, jeton, contenu personnel) et versionnés comme fixtures
**Et** un test vérifie l'absence de secret dans les fixtures

**Étant donné** les capacités optionnelles (`replay_epoch`, `idempotency_key`, `file.attach`…)
**Quand** le contrat est figé
**Alors** un fichier de capacités indique pour chacune présente/absente/non vérifiée sur l'instance
**Et** toute capacité obligatoire absente est signalée à Alanc (NFR4) au lieu d'être contournée

**Étant donné** la table déclarative événements → états/terminaux/`ActivityKind`
**Quand** elle est créée dans `contracts/`
**Alors** elle couvre les événements observés, avec un type inconnu explicite, et un test la valide contre les fixtures

### Story 1.4 : Appairer l'app à mon serveur Hermes

En tant qu'Alanc,
Je veux indiquer l'adresse de mon serveur en scannant un QR code ou en la saisissant,
Afin de connecter l'app sans rien configurer d'autre.

**Critères d'acceptation :**

**Étant donné** un QR `hermes-mobile://pair?url=<origine>` généré par le script du dépôt
**Quand** Alanc le scanne
**Alors** l'origine est affichée pour confirmation avant toute connexion
**Et** le QR ne contient ni mot de passe ni jeton

**Étant donné** l'écran de connexion (UX-DR5)
**Quand** Alanc saisit une URL manuellement
**Alors** `http://` n'est accepté que pour `*.ts.net`, `https://` toujours, et toute autre URL est refusée avec un message clair
**Et** `network_security_config` n'autorise le clair que pour les sous-domaines `ts.net`

**Étant donné** une origine confirmée
**Quand** la connexion est enregistrée
**Alors** elle reçoit un `ConnectionKey` UUID stable dans la table SQLite `connection_*` (migration ajoutée au registre, testée)
**Et** modifier ensuite l'URL ne change pas le `ConnectionKey`

**Étant donné** un serveur injoignable
**Quand** l'app teste l'origine
**Alors** le message indique « serveur inaccessible », distinct d'un refus d'authentification (FR1)

### Story 1.5 : M'authentifier une fois et rester connecté

En tant qu'Alanc,
Je veux saisir mon mot de passe Hermes une seule fois,
Afin que l'app se reconnecte seule, même après un redémarrage du serveur.

**Critères d'acceptation :**

**Étant donné** une origine appairée
**Quand** Alanc saisit le mot de passe (`access_password`, utilisateur `hermes`)
**Alors** l'app obtient jeton d'accès et refresh, puis ouvre `/api/ws` avec un ticket WS
**Et** le mot de passe et les jetons sont stockés dans le stockage sécurisé sous `<ConnectionKey>/<usage>`

**Étant donné** un mot de passe incorrect
**Quand** le login est refusé
**Alors** le message indique « authentification refusée », distinct de « serveur inaccessible » (FR1)

**Étant donné** un backend redémarré (jetons invalidés)
**Quand** le refresh échoue
**Alors** l'app se reconnecte avec le mot de passe stocké, sans le redemander
**Et** une seule socket existe par connexion, ouverte par `ConnectionRepository`

**Étant donné** les erreurs, logs (`domaine.code`) et diagnostics
**Quand** une authentification échoue ou une redirection pointe vers une autre origine
**Alors** aucun secret n'apparaît dans les messages, logs ou URL persistées (NFR3)
**Et** aucune credential n'est envoyée à l'autre origine

### Story 1.6 : Connaître l'état de la connexion et les fonctions disponibles

En tant qu'Alanc,
Je veux voir si l'app est connectée et si mon serveur offre toutes les fonctions nécessaires,
Afin de ne jamais subir un échec silencieux.

**Critères d'acceptation :**

**Étant donné** une connexion authentifiée
**Quand** l'app se connecte
**Alors** `ConnectionRepository` détecte et enregistre les capacités du serveur, puis les compare à la liste exigée de `contracts/`
**Et** tout écart est affiché à Alanc avec la fonction concernée (NFR4, AD-11)

**Étant donné** une méthode absente, un refus d'authentification et une panne transitoire
**Quand** chacun survient
**Alors** ils produisent trois erreurs distinctes dans l'enveloppe partagée (`code` namespacé, `retryable`, `operationKey?`)

**Étant donné** l'indicateur de connexion (UX-DR20)
**Quand** la socket est ouverte, se reconnecte ou est perdue
**Alors** l'app affiche `connecté`, `resynchronisation` ou `hors ligne`, avec un libellé et pas seulement une couleur (UX-DR21)

### Story 1.7 : Voir et actualiser mes profils Hermes

En tant qu'Alanc,
Je veux retrouver dans l'app les profils existants sur mon Hermes,
Afin de les choisir sans les recréer ni les configurer.

**Critères d'acceptation :**

**Étant donné** une connexion authentifiée
**Quand** la liste des profils est chargée via le contrat figé
**Alors** chaque profil est affiché de façon distinguable et le profil par défaut est celui fourni par Hermes (FR10, UX-DR6)
**Et** le chargement ne modifie pas le profil actif global du dashboard Hermes

**Étant donné** un profil ajouté côté Hermes
**Quand** Alanc actualise la liste
**Alors** le nouveau profil apparaît sans réinstaller l'app

**Étant donné** un échec de chargement
**Quand** la liste ne peut pas être obtenue
**Alors** l'app affiche une erreur distincte d'une liste vide
**Et** aucun profil par défaut n'est inventé : seul le dernier choix explicite enregistré peut être proposé

**Étant donné** le sélecteur de profils
**Quand** il est utilisé au lecteur d'écran
**Alors** chaque profil et le profil actif sont annoncés avec un nom accessible (NFR1)

## Epic 2 : Converser avec un profil et retrouver mes conversations

À l'ouverture, une nouvelle conversation est prête avec le profil par défaut. Alanc envoie de longs textes, lit les réponses en streaming, retrouve et reprend les conversations de chaque profil, sans perte de brouillon ni double exécution. Requiert la porte G1.

### Story 2.1 : Préparer une demande sur une nouvelle conversation

En tant qu'Alanc,
Je veux trouver à l'ouverture une conversation neuve avec le profil par défaut et y écrire librement,
Afin de commencer une demande immédiatement sans jamais perdre ce que j'ai tapé.

**Critères d'acceptation :**

**Étant donné** une ouverture normale de l'app (sans notification ni restauration)
**Quand** l'écran d'accueil s'affiche
**Alors** `resolveLaunchTarget()` ouvre `/draft/<DraftKey>` sur le profil par défaut fourni par Hermes (FR2)
**Et** aucune session Hermes ni fil vide n'est créé avant le premier envoi

**Étant donné** la zone de saisie (UX-DR9)
**Quand** Alanc saisit ou colle un long texte avec le clavier affiché
**Alors** le texte est accepté sans troncature et sans commande `/`
**Et** le brouillon est persisté par `OutboxRepository` dans une table `outbox_*` (migration ajoutée, testée)

**Étant donné** un brouillon en cours
**Quand** l'app passe en arrière-plan puis revient, ou est tuée puis relancée
**Alors** le brouillon est intact ; un retour temporaire conserve l'écran en cours

**Étant donné** le champ et le bouton d'envoi
**Quand** ils sont utilisés au lecteur d'écran et en texte agrandi
**Alors** ils ont des noms accessibles et restent utilisables (NFR1)

### Story 2.2 : Envoyer ma demande sans risque de double exécution

En tant qu'Alanc,
Je veux envoyer ma demande à Hermes en sachant exactement si elle a été acceptée,
Afin qu'une coupure ne provoque jamais de perte ni d'exécution en double.

**Critères d'acceptation :**

**Étant donné** un brouillon prêt
**Quand** Alanc l'envoie
**Alors** l'opération (cible, contenu exact, `OperationKey`) est persistée avant toute soumission
**Et** le pipeline exécute dans l'ordre les étapes nommées `ensureSession` puis soumission (les étapes pièces et suivi de notification restent des points d'extension vides)

**Étant donné** un premier envoi depuis `/draft/<DraftKey>`
**Quand** `ensureSession(DraftKey)` crée la session (avec `close_on_disconnect=false` si le contrat l'expose)
**Alors** l'association `DraftKey` → `SessionKey` est persistée avant la soumission
**Et** deux appels concurrents pour le même brouillon ne créent qu'une session

**Étant donné** une soumission dont la réponse est perdue (timeout, coupure)
**Quand** le résultat est incertain
**Alors** l'opération passe à `unknown`, le brouillon est conservé et rien n'est renvoyé automatiquement (NFR2)
**Et** une répétition n'est possible que si l'idempotence de la méthode est détectée dans les capacités

**Étant donné** une soumission acceptée
**Quand** Hermes confirme
**Alors** seule la version acceptée du brouillon est retirée, jamais une saisie plus récente
**Et** le rapprochement local/serveur suit la règle fixée en G1, jamais une comparaison de texte

**Étant donné** un travail en cours dans la session
**Quand** Alanc tape un nouveau message
**Alors** la saisie est conservée mais non soumise ; un seul envoi à la fois par session

### Story 2.3 : Lire la réponse en direct avec mise en forme et code

En tant qu'Alanc,
Je veux voir la réponse de Hermes s'écrire progressivement, avec emojis, mise en forme et blocs de code lisibles,
Afin de suivre et lire confortablement le résultat de ma demande.

**Critères d'acceptation :**

**Étant donné** une session avec un travail accepté
**Quand** des événements arrivent sur `/api/ws`
**Alors** `ConversationRepository` les applique via la table de mapping de `contracts/` et publie une `TimelineProjection` immuable
**Et** les mutations sont sérialisées par session et la projection est enregistrée avec son curseur en une seule écriture

**Étant donné** le composant message (UX-DR8)
**Quand** une réponse contient Markdown, emojis et blocs de code
**Alors** ils sont rendus lisiblement, le code avec défilement horizontal, en clair, sombre et texte agrandi
**Et** sous mouvement réduit la réponse n'est pas tapée caractère par caractère (UX-DR15)

**Étant donné** les états du travail distant
**Quand** la projection évolue
**Alors** le fil distingue envoi, travail en cours, fin, erreur et état inconnu/non synchronisé, par libellé et pas seulement par couleur
**Et** une fin de socket, un silence ou une animation ne sont jamais interprétés comme une fin de travail (AD-4)

**Étant donné** une limite du serveur ou du modèle (taille, quota, refus)
**Quand** Hermes la signale
**Alors** l'app l'explique en termes simples et le brouillon reste intact (FR4)

**Étant donné** un événement d'activité dans le fil
**Quand** l'Epic 3 n'est pas encore livré
**Alors** il s'affiche sous forme générique sans détail inventé

**Étant donné** un changement de composition du fil
**Quand** le rendu est reconstruit
**Alors** aucun appel n'est rejoué et l'état est conservé (UX-DR24)

### Story 2.4 : Retrouver mon travail après une coupure ou un retour dans l'app

En tant qu'Alanc,
Je veux que le travail continue quand je quitte l'app et que je retrouve son état exact à mon retour,
Afin de ne jamais perdre une réponse ni relancer une demande par erreur.

**Critères d'acceptation :**

**Étant donné** un travail accepté par Hermes
**Quand** Alanc quitte l'app ou perd le réseau
**Alors** le travail continue côté serveur (FR8) et l'état de connexion passe à `hors ligne` puis `resynchronisation`

**Étant donné** une reconnexion et la capacité `(epoch, seq)` détectée
**Quand** le replay reprend depuis le curseur
**Alors** les doublons sont écartés, et un trou, une troncature ou un nouvel epoch déclenchent un snapshot complet
**Et** sans cette capacité, la reprise se fait toujours par snapshot complet

**Étant donné** des événements d'une ancienne connexion ou session
**Quand** ils arrivent en retard
**Alors** ils sont écartés

**Étant donné** une opération restée `unknown`
**Quand** le snapshot montre qu'elle a été acceptée ou non
**Alors** l'état est mis à jour sans renvoi automatique ; si l'issue reste indémontrable, elle reste affichée comme inconnue (NFR2)

**Étant donné** les fixtures du contrat
**Quand** les tests rejouent « coupure après acceptation avant réponse » et « événement dupliqué, tronqué ou ancien »
**Alors** aucune double exécution ni perte de brouillon n'est observée

### Story 2.5 : Choisir le profil de ma nouvelle conversation

En tant qu'Alanc,
Je veux choisir avec quel profil Hermes je démarre une conversation,
Afin d'adresser chaque demande au bon agent.

**Critères d'acceptation :**

**Étant donné** un brouillon de nouvelle conversation
**Quand** Alanc sélectionne un autre profil dans le sélecteur (UX-DR6)
**Alors** le brouillon est rattaché à ce profil et le profil actif est identifiable à l'écran (FR3)

**Étant donné** une conversation existante
**Quand** Alanc change la sélection de profil
**Alors** le profil de cette conversation ne change jamais ; la sélection s'applique au prochain fil

**Étant donné** le dernier profil choisi explicitement
**Quand** l'app est relancée et Hermes ne fournit pas de défaut
**Alors** ce choix enregistré est proposé, sans profil inventé

### Story 2.6 : Retrouver et reprendre mes conversations par profil

En tant qu'Alanc,
Je veux voir les conversations de chaque profil et en rouvrir une,
Afin de poursuivre un échange sans mélanger les profils.

**Critères d'acceptation :**

**Étant donné** un profil sélectionné
**Quand** Alanc ouvre l'historique (UX-DR7)
**Alors** les conversations de ce profil sont listées de façon distinguable, ordonnées selon l'ordre fourni par le serveur
**Et** un historique vide est affiché comme tel, distinct d'une erreur de chargement

**Étant donné** une conversation de l'historique
**Quand** Alanc l'ouvre
**Alors** la route `/c/<ConnectionKey>/<ProfileKey>/<SessionKey>` affiche ses messages et il peut y poursuivre l'échange

**Étant donné** deux profils dont les sessions ont des identifiants similaires (casse comprise)
**Quand** Alanc passe de l'un à l'autre
**Alors** aucun message ni fichier n'est mélangé entre conversations (FR3, AD-3)

**Étant donné** Alanc dans une conversation
**Quand** il démarre une nouvelle conversation
**Alors** un nouveau brouillon est préparé sans fil vide enregistré

**Étant donné** l'URL de la connexion modifiée
**Quand** l'historique est rechargé
**Alors** les conversations restent rattachées au même `ConnectionKey`, sans réindexation

## Epic 3 : Suivre le travail de Hermes et l'arrêter

L'activité apparaît en lignes compactes illustrées, avec détails dépliables réellement fournis par Hermes. Alanc demande l'arrêt et distingue arrêt demandé et arrêt confirmé.

### Story 3.1 : Voir l'activité de Hermes en lignes compactes

En tant qu'Alanc,
Je veux voir dans le fil ce que Hermes est en train de faire, sous forme de lignes courtes,
Afin de comprendre l'avancement sans lire de sortie technique.

**Critères d'acceptation :**

**Étant donné** des événements d'outil dans la projection
**Quand** le fil s'affiche
**Alors** chaque action apparaît comme une ligne compacte avec un libellé lisible et un emplacement d'illustration à côté (UX-DR11), identifiée par son identité d'action serveur et son `ActivityKind` issu du mapping
**Et** une action terminée porte un signe de fin, exprimé aussi par un libellé accessible (UX-DR21)

**Étant donné** plusieurs actions consécutives
**Quand** le travail passe à la réponse
**Alors** le groupe d'actions se replie en une synthèse, dépliable à la demande

**Étant donné** un type d'événement inconnu du mapping
**Quand** il arrive
**Alors** il est conservé et rendu génériquement, sans libellé ni détail inventé
**Et** aucun raisonnement privé n'est déduit des événements d'outil (AD-4)

### Story 3.2 : Déplier les détails d'une action

En tant qu'Alanc,
Je veux ouvrir une ligne d'activité pour voir l'outil, la commande, la sortie ou l'erreur,
Afin de vérifier précisément ce que Hermes a fait quand j'en ai besoin.

**Critères d'acceptation :**

**Étant donné** une ligne d'activité
**Quand** Alanc la déplie au toucher ou au lecteur d'écran
**Alors** les détails réellement exposés par Hermes (outil, commande CLI, sortie, erreur) s'affichent (FR7)
**Et** un détail non fourni reste absent, jamais remplacé par un contenu supposé

**Étant donné** une sortie longue ou du code
**Quand** elle est affichée
**Alors** elle reste lisible en texte agrandi, avec défilement, sans dominer le fil une fois repliée

**Étant donné** l'état déplié
**Quand** le fil est reconstruit ou reçoit de nouveaux événements
**Alors** l'état déplié est conservé et aucun appel n'est rejoué (UX-DR24)
**Et** le contrôle annonce son état replié/déplié au lecteur d'écran

### Story 3.3 : Reconnaître l'activité grâce aux illustrations animées

En tant qu'Alanc,
Je veux une petite illustration animée adaptée au type d'activité,
Afin de saisir d'un coup d'œil ce que fait Hermes.

**Critères d'acceptation :**

**Étant donné** le catalogue de présentation indexé par `ActivityKind` (UX-DR12)
**Quand** une activité est affichée
**Alors** son illustration provient du catalogue (rendu, paramètres de mouvement issus des tokens, variante immobile), avec un fallback générique
**Et** le catalogue n'est jamais indexé par emoji, nom d'outil MCP ou minuterie

**Étant donné** la préparation de réponse ou une activité inconnue
**Quand** elle est affichée
**Alors** trois petits points tournent (référence 24 × 24 px), sans bulle ni grand dessin (UX-DR13)

**Étant donné** l'activité « code »
**Quand** elle est affichée
**Alors** le châssis de l'ordinateur reste fixe et seuls les lignes et le curseur bougent, traits épais (UX-DR14)

**Étant donné** le mouvement réduit activé, une ligne hors écran ou l'app en arrière-plan
**Quand** l'illustration est rendue
**Alors** elle est immobile ou arrêtée (UX-DR15)
**Et** aucune animation ne modifie l'état ni ne décide qu'un outil est terminé

**Étant donné** l'entrée de catalogue d'une activité
**Quand** son illustration est remplacée
**Alors** seul le catalogue change, sans modification du décodage des événements ni des appels à Hermes (test de non-régression)
**Et** la galerie montre chaque illustration en clair, sombre et mouvement réduit

### Story 3.4 : Compléter le catalogue des familles d'activité

En tant qu'Alanc,
Je veux les illustrations de toutes les familles d'activité de la maquette,
Afin que chaque type de tâche courant soit reconnaissable.

**Critères d'acceptation :**

**Étant donné** les familles de la maquette acceptée (`mockups/simple-conversation.html`)
**Quand** le catalogue est complété
**Alors** il contient, en plus de code et préparation de réponse : création de fichier, modification de fichier, appel d'outil, recherche web, navigation web, lecture, commande, recherche de fichier, création d'image, analyse d'image, mémoire, délégation, organisation, compétence et planification (UX-DR12)
**Et** chaque entrée a une variante immobile et passe par les tokens de mouvement

**Étant donné** la table de mapping de `contracts/`
**Quand** un `ActivityKind` est associé à une famille
**Alors** l'association repose sur un événement fiable du contrat ; les associations non vérifiées tombent sur le fallback générique

**Étant donné** la galerie
**Quand** Alanc l'examine sur son téléphone
**Alors** toutes les familles sont visibles et comparables, en clair, sombre et mouvement réduit

### Story 3.5 : Demander l'arrêt du travail en cours

En tant qu'Alanc,
Je veux arrêter le travail de Hermes depuis la conversation,
Afin de reprendre la main sans commande `/` et en sachant si l'arrêt est effectif.

**Critères d'acceptation :**

**Étant donné** un travail en cours
**Quand** Alanc touche « Arrêter » (UX-DR16)
**Alors** une opération d'arrêt est persistée en visant l'exécution observée, puis envoyée (FR12)
**Et** le fil affiche « arrêt demandé », issu de l'opération et jamais écrit dans la projection

**Étant donné** une demande d'arrêt envoyée
**Quand** Hermes renvoie un terminal `stopped`
**Alors** le fil affiche « arrêt confirmé »
**Et** une perte réseau ou un silence ne vaut jamais confirmation

**Étant donné** un contrôle qui ne peut viser qu'une session
**Quand** le tour visé est terminé et un nouveau tour a commencé
**Alors** l'ancienne demande d'arrêt n'est jamais rejouée sur le nouveau tour

**Étant donné** une reconnexion après une demande d'arrêt
**Quand** la projection est resynchronisée
**Alors** l'état réel (arrêté, terminé, en cours ou inconnu) est affiché sans renvoi automatique (cas de contrat « arrêt après reconnexion »)

**Étant donné** l'indicateur d'activité réduit, le texte agrandi ou le lecteur d'écran
**Quand** un travail est en cours
**Alors** « Arrêter » reste atteignable avec un nom accessible et une cible tactile suffisante
**Et** l'interface rappelle que l'arrêt n'annule pas les actions déjà effectuées

## Epic 4 : Joindre photos et documents à mes demandes

Alanc joint photos, captures, PDF et documents, voit aperçus et limites, retire un fichier, et sait si chaque fichier a réellement été reçu par Hermes dans la bonne conversation. Requiert la porte G2.

### Story 4.1 : Fixer les limites de fichiers sur mon installation

En tant qu'Alanc,
Je veux que les formats et tailles réellement acceptés par mon Hermes soient mesurés avec mes propres fichiers,
Afin que l'app m'annonce des limites vraies et que l'acceptation repose sur mon usage réel.

**Critères d'acceptation :**

**Étant donné** le corpus fourni par Alanc (long texte, photo ou capture, PDF, document bureautique) (NFR6)
**Quand** il est envoyé à Hermes par le transport du contrat (upload REST ou `file.attach`) sur un profil de test dédié
**Alors** la réception est vérifiée côté Hermes, dans la bonne session, au-delà d'un simple aperçu client
**Et** formats et volumes du corpus sont consignés dans `contracts/`

**Étant donné** les limites de l'app, du proxy, de Hermes et du modèle
**Quand** elles sont mesurées
**Alors** `contracts/` enregistre pour chaque type la limite la plus restrictive vérifiée (type, nombre, taille)
**Et** une limite non vérifiée est notée comme telle, sans valeur inventée

**Étant donné** le modèle utilisé par chaque profil de test
**Quand** une image est envoyée
**Alors** le fait qu'il analyse ou non les images est consigné

### Story 4.2 : Joindre des fichiers à une demande

En tant qu'Alanc,
Je veux ajouter des photos, captures, PDF, documents ou autres fichiers à ma demande et les vérifier avant l'envoi,
Afin d'envoyer exactement ce que je veux à Hermes.

**Critères d'acceptation :**

**Étant donné** un brouillon
**Quand** Alanc touche « Joindre » et choisit des fichiers dans la galerie ou le gestionnaire de fichiers
**Alors** leurs octets sont copiés dans `attachments/<DraftKey>/` et listés dans le brouillon (UX-DR10, FR5)
**Et** les images affichent un aperçu, les autres fichiers leur nom, type et taille

**Étant donné** la liste des pièces
**Quand** Alanc retire un fichier
**Alors** il disparaît de la liste et sa copie privée est supprimée

**Étant donné** les limites enregistrées en 4.1
**Quand** Alanc ouvre la sélection ou ajoute un fichier hors limite (type, nombre ou taille)
**Alors** les limites sont indiquées avant l'envoi et le fichier refusé l'est avec la raison
**Et** « autres fichiers » n'affiche aucune promesse de prise en charge non vérifiée

**Étant donné** l'app tuée puis relancée
**Quand** le brouillon est rouvert
**Alors** ses pièces sont toujours présentes

**Étant donné** un refus de permission du téléphone
**Quand** la sélection échoue
**Alors** la raison est expliquée, et chaque action (joindre, retirer) a un nom accessible

### Story 4.3 : Envoyer mes fichiers et savoir s'ils sont reçus

En tant qu'Alanc,
Je veux savoir pour chaque fichier s'il a bien été reçu par Hermes,
Afin de ne jamais croire qu'Hermes a un fichier qu'il n'a pas reçu.

**Critères d'acceptation :**

**Étant donné** un brouillon avec pièces
**Quand** Alanc l'envoie
**Alors** l'étape « pièces » du pipeline téléverse chaque fichier dans le scope connexion/profil/session d'origine et obtient sa référence serveur (AD-6)
**Et** aucun chemin du téléphone n'est transmis au serveur

**Étant donné** le téléversement en cours
**Quand** il progresse, réussit ou échoue
**Alors** chaque pièce affiche son état (envoi, reçu, échec) par libellé et pas seulement par couleur (FR6)

**Étant donné** un téléversement échoué ou incertain
**Quand** le pipeline l'évalue
**Alors** le prompt n'est pas soumis, le brouillon et ses pièces sont conservés, et Alanc peut réessayer ou retirer la pièce
**Et** une pièce échouée n'est jamais présentée comme reçue (cas de contrat « upload échoué sans prompt »)

**Étant donné** toutes les pièces confirmées
**Quand** le prompt est soumis
**Alors** il référence les pièces serveur, et un upload réussi n'est pas présenté comme une analyse par le modèle
**Et** si le modèle du profil n'analyse pas les images, l'app le signale explicitement

### Story 4.4 : Retrouver mes fichiers dans l'historique

En tant qu'Alanc,
Je veux retrouver les fichiers envoyés dans la conversation où je les ai joints,
Afin de savoir plus tard sur quoi Hermes a travaillé.

**Critères d'acceptation :**

**Étant donné** un message envoyé avec pièces
**Quand** Alanc rouvre la conversation, même après redémarrage de l'app
**Alors** chaque pièce est identifiable dans le message (nom, type, aperçu image si disponible)

**Étant donné** deux conversations de profils différents
**Quand** des fichiers sont envoyés dans chacune
**Alors** aucun fichier n'apparaît dans l'autre conversation (FR3, AD-3)

**Étant donné** un message accepté et rapproché avec le serveur
**Quand** les pièces sont confirmées dans l'historique distant
**Alors** les copies locales du brouillon sont nettoyées, jamais avant ce rapprochement
**Et** aucun fichier n'est exécuté automatiquement

## Epic 5 : Être averti quand Hermes a fini

App quittée, Alanc reçoit une notification de fin (réussite, erreur, arrêt confirmé) qui ouvre la bonne conversation. Inclut le plugin Hermes de notifications, FCM et l'ouverture depuis notification. L'observateur serveur des stories 5.1 à 5.4 est remplacé par le plugin (proposition de changement du 2026-10-29). Requiert la porte G3.

### Story 5.1 : Fixer le contrat de suivi et le déploiement de l'observateur

*Remplacée le 2026-10-29 par le plugin Hermes (stories 5.6 à 5.8) ; conservée pour l'historique.*

En tant qu'Alanc,
Je veux que le fonctionnement des notifications soit décidé et vérifiable avant d'être construit,
Afin que le mobile et le serveur s'accordent sur ce qui déclenche une notification.

**Critères d'acceptation :**

**Étant donné** la porte G3
**Quand** le contrat de suivi est rédigé dans `contracts/`
**Alors** il définit le registre (clé `subscriptionId`), l'enregistrement d'un suivi, son rattachement à une exécution confirmée, le payload minimal (identité stable, `subscriptionId`, libellé générique) et le point de santé
**Et** les terminaux notifiés (réussite, erreur, arrêt confirmé) proviennent de la table de mapping partagée et de ses fixtures

**Étant donné** l'installation Home Assistant
**Quand** l'emplacement et le runtime de l'observateur sont choisis
**Alors** le mode de déploiement supervisé avec volume persistant, l'authentification mobile → observateur (credential propre), l'accès en lecture à Hermes et la version FCM (17.x ou 16.x) sont consignés et validés par Alanc
**Et** le projet Firebase et le compte de service sont créés hors du dépôt, séparés par environnement

**Étant donné** les prérequis Android (services Google, permission de notification, optimisation batterie, arrêt forcé)
**Quand** ils sont vérifiés sur le téléphone d'Alanc
**Alors** chaque cas est documenté avec le comportement attendu

### Story 5.2 : Faire tourner l'observateur de fins de travail

*Remplacée le 2026-10-29 par le plugin Hermes (stories 5.6 à 5.8) ; conservée pour l'historique.*

En tant qu'Alanc,
Je veux un petit service sur mon serveur qui détecte les fins de travail de Hermes,
Afin d'être averti même quand mon téléphone n'est pas connecté.

**Critères d'acceptation :**

**Étant donné** `server/notifier/` déployé selon 5.1
**Quand** une exécution suivie atteint un terminal
**Alors** l'observateur l'identifie via le contrat d'intégration et le mapping partagé, et écrit une entrée dans son outbox durable
**Et** il ne soumet ni ne contrôle aucun travail et n'accède à aucune base privée de Hermes (AD-1)

**Étant donné** un redémarrage de l'observateur pendant un travail
**Quand** il reprend
**Alors** il rattrape les fins manquées depuis la source Hermes persistante ; une fin indémontrable reste inconnue et n'est pas notifiée comme réussite

**Étant donné** un même terminal observé plusieurs fois
**Quand** l'outbox est alimentée
**Alors** la déduplication par cible, exécution et terminal n'en garde qu'une entrée

**Étant donné** le point de santé
**Quand** il est interrogé avec la credential du mobile
**Alors** il indique l'état de l'observateur ; sans credential il refuse
**Et** les logs ne contiennent ni texte de conversation, ni chemin, ni secret

### Story 5.3 : Recevoir une notification à la fin de mon travail

*Remplacée le 2026-10-29 par le plugin Hermes (stories 5.6 à 5.8) ; conservée pour l'historique.*

En tant qu'Alanc,
Je veux recevoir une notification quand Hermes a terminé, même app fermée,
Afin de ne pas avoir à surveiller l'app.

**Critères d'acceptation :**

**Étant donné** l'app installée avec firebase_messaging
**Quand** Alanc accepte la permission de notification
**Alors** le token FCM est enregistré auprès de l'observateur, avec gestion de sa rotation et de sa révocation

**Étant donné** un envoi de demande
**Quand** le pipeline atteint l'étape « suivi de notification »
**Alors** un `subscriptionId` est enregistré auprès de l'observateur avant la soumission, puis rattaché à l'exécution confirmée sans notifier un ancien terminal
**Et** si l'observateur est absent ou en échec, l'envoi continue et le tour affiche « notification non suivie » (UX-DR19)

**Étant donné** un terminal réussite, erreur ou arrêt confirmé
**Quand** l'observateur traite son outbox
**Alors** il envoie via FCM HTTP v1 un payload minimal sans texte, chemin ni secret, avec retries bornés (FR9)
**Et** Android affiche la notification app fermée, avec une issue générique distinguant réussite, erreur et arrêt

**Étant donné** une permission refusée ou des prérequis Google absents
**Quand** Alanc ouvre l'app
**Alors** l'app explique pourquoi les notifications ne peuvent pas arriver, et affiche la santé de l'observateur (UX-DR20)

### Story 5.4 : Ouvrir la bonne conversation depuis une notification

*Le routage reste ; sa clé passe de `subscriptionId` à `sessionId` (story 5.7, 2026-10-29).*

En tant qu'Alanc,
Je veux qu'un toucher sur la notification m'amène directement à la conversation concernée,
Afin de lire le résultat sans chercher.

**Critères d'acceptation :**

**Étant donné** une notification reçue app fermée ou en arrière-plan
**Quand** Alanc la touche
**Alors** `resolveLaunchTarget()` donne priorité à la notification, puis à la restauration, puis à l'accueil, et ouvre `/c/<ConnectionKey>/<ProfileKey>/<SessionKey>` (FR2, FR9)

**Étant donné** la conversation ouverte depuis une notification
**Quand** elle s'affiche
**Alors** l'app se réauthentifie si nécessaire et recharge l'état depuis Hermes ; la notification n'est qu'un indice, jamais l'autorité sur l'état

**Étant donné** une notification visant une conversation ou connexion qui n'existe plus localement
**Quand** Alanc la touche
**Alors** l'app l'explique et ouvre l'accueil, sans réaffecter le résultat au fil affiché

### Story 5.6 : Recevoir mes notifications par le plugin Hermes

En tant qu'Alanc,
Je veux que Hermes envoie lui-même la notification de fin,
Afin de n'avoir rien d'autre à installer qu'un plugin.

**Critères d'acceptation :**

**Étant donné** le plugin `hermes-mobile-notify` installé sur un profil
**Quand** un tour lancé depuis l'app (`platform: tui`) se termine
**Alors** une notification FCM générique part en arrière-plan sans retarder le tour, avec `data: {outcome, sessionId}`, sans texte, chemin ni secret (FR9)
**Et** les tours de sous-agents, de cron ou d'autres plateformes ne notifient pas

**Étant donné** l'app qui envoie un message
**Quand** elle dispose d'un jeton FCM
**Alors** elle le transmet par `command.dispatch hermes-mobile-token` sans bloquer l'envoi

**Étant donné** FCM qui répond `UNREGISTERED`
**Quand** le plugin le constate
**Alors** il oublie le jeton jusqu'au prochain envoi de l'app
**Et** une erreur réseau donne lieu à un seul nouvel essai

**Étant donné** le dépôt
**Quand** la CI tourne
**Alors** l'auto-vérification du plugin s'exécute, et `contracts/notification-tracking.json` ne décrit plus que le payload (titres, canal, `outcome`, `sessionId`)

**Étant donné** la procédure d'installation
**Quand** Alanc l'applique à un profil
**Alors** elle tient en : copier le plugin, copier la clé, activer, redémarrer

### Story 5.7 : Basculer l'app sur le plugin

En tant qu'Alanc,
Je veux que l'app ne dépende plus de l'observateur,
Afin de ne plus rien configurer par profil.

**Critères d'acceptation :**

**Étant donné** une notification du plugin
**Quand** Alanc la touche, app à froid, à chaud ou depuis les récents
**Alors** la conversation `sessionId` du bon profil s'ouvre (FR2, FR9)
**Et** une session inconnue localement ouvre l'accueil avec une explication

**Étant donné** une notification reçue app ouverte
**Quand** elle arrive
**Alors** elle est traitée avec `{outcome, sessionId}`

**Étant donné** l'envoi d'un message
**Quand** `command.dispatch` répond 4018
**Alors** le tour affiche « notification non suivie » sans bloquer l'envoi (UX-DR19)

**Étant donné** les réglages du profil
**Quand** Alanc les ouvre
**Alors** il n'y a plus d'URL ni de bearer d'observateur ; les explications permission et arrêt forcé restent

**Étant donné** la base locale
**Quand** l'app migre
**Alors** une migration ajoutée supprime `notification_subscriptions`, `notification_settings` et le secret `observerBearer`, sans modifier les migrations existantes

### Story 5.8 : Retirer l'observateur

En tant qu'Alanc,
Je veux que l'add-on Notifier et son code disparaissent,
Afin de n'avoir qu'un seul chemin à maintenir.

**Critères d'acceptation :**

**Étant donné** le dépôt
**Quand** le retrait est fait
**Alors** `server/notifier/`, `repository.yaml`, les étapes CI du notifier, `contracts/notification-deployment.json`, la section 5.1 de `contracts/README.md` et les mentions de `README.md` n'existent plus

**Étant donné** Home Assistant et Tailscale
**Quand** Alanc suit la procédure de la proposition de changement (section 6)
**Alors** l'add-on est désinstallé, son dépôt retiré, `/share/hermes-notifier/` supprimé et le service `svc:hermes-notifier` n'existe plus

**Étant donné** `deferred-work.md`
**Quand** le retrait est fait
**Alors** les reports propres à l'observateur sont clos

### Story 5.5 : Valider les notifications sur mon téléphone

*Critères réécrits le 2026-10-29 pour le plugin ; jouée après 5.8.*

En tant qu'Alanc,
Je veux que les notifications soient éprouvées dans les situations réelles,
Afin de pouvoir compter dessus au quotidien.

**Critères d'acceptation :**

**Étant donné** le téléphone d'Alanc et le plugin installé
**Quand** sont joués : app fermée, coupure réseau pendant le travail, arrêt, délégation à un sous-agent, conversation reprise, `/new`
**Alors** chaque fin de tour de l'app est notifiée au moins une fois, sans doublon de sous-agent, et le toucher ouvre la bonne conversation

**Étant donné** un profil sans plugin
**Quand** Alanc envoie un message
**Alors** « notification non suivie » s'affiche sans bloquer l'envoi

**Étant donné** un redémarrage de Hermes pendant un travail
**Quand** il est joué
**Alors** le résultat est consigné ; une notification perdue est acceptée et expliquée

**Étant donné** l'arrêt forcé de l'app dans les réglages Android et la permission refusée
**Quand** ils sont testés
**Alors** leur comportement distinct est constaté et expliqué dans l'app

**Étant donné** les résultats
**Quand** ils sont consignés
**Alors** la porte G3 est déclarée franchie ou les écarts sont remontés à Alanc ; aucune simulation ne remplace ces essais

## Epic 6 : Répondre à Hermes et récupérer ses résultats

Les questions et autorisations émises par Hermes apparaissent dans le fil et Alanc y répond ; les fichiers produits s'ouvrent ou se téléchargent depuis la conversation. Se termine par l'essai d'acceptation réel du MVP. Requiert la porte G4.

### Story 6.1 : Trancher les interventions et résultats sur mon installation

En tant qu'Alanc,
Je veux savoir précisément ce que mon Hermes expose pour les questions, autorisations, messages pendant le travail et fichiers résultats,
Afin de décider en connaissance de cause du comportement de l'app.

**Critères d'acceptation :**

**Étant donné** le contrat figé en 1.3
**Quand** questions, approbations, instructions pendant le travail et accès aux fichiers résultats sont essayés sur un profil de test
**Alors** `contracts/` consigne pour chacun les méthodes, événements, fixtures anonymisées et capacités détectées
**Et** la prise en compte immédiate ou différée d'une intervention pendant l'exécution est documentée

**Étant donné** ces constats
**Quand** Alanc tranche la porte G4
**Alors** ses décisions sont consignées : FR13 et FR14 retenus ou retirés explicitement, états `waitingInput`/`waitingApproval` activés seulement s'ils sont retenus et exposés, issues notifiées confirmées
**Et** une capacité obligatoire absente lui est remontée (NFR4), jamais contournée

**Étant donné** la palette de secours provisoire de 1.2
**Quand** ses contrastes et l'usage de l'erreur sont vérifiés en clair et sombre
**Alors** les valeurs sont validées par Alanc et figées dans le thème (UX-DR3)

### Story 6.2 : Répondre à une question de Hermes

En tant qu'Alanc,
Je veux voir dans la conversation quand Hermes attend une précision et lui répondre,
Afin de débloquer son travail depuis mon téléphone.

**Critères d'acceptation :**

**Étant donné** un événement d'attente de réponse exposé par Hermes
**Quand** il est projeté
**Alors** le fil affiche l'état `waitingInput` et la question réellement émise, par libellé et pas seulement par couleur (FR13, UX-DR17)

**Étant donné** la question affichée
**Quand** Alanc répond
**Alors** la réponse est persistée comme opération puis envoyée vers la demande visée, sans renvoi automatique si le résultat est incertain
**Et** l'app indique si la réponse est prise en compte immédiatement ou au prochain point du travail, selon le contrat

**Étant donné** une question déjà traitée ou expirée
**Quand** la projection est resynchronisée
**Alors** la question n'est plus proposée et une ancienne réponse n'est jamais rejouée

### Story 6.3 : Autoriser ou refuser une action demandée par Hermes

En tant qu'Alanc,
Je veux voir la demande d'autorisation exacte de Hermes et l'accepter ou la refuser,
Afin de garder le contrôle des actions sensibles.

**Critères d'acceptation :**

**Étant donné** une demande d'approbation émise par Hermes
**Quand** elle est projetée
**Alors** le fil affiche l'état `waitingApproval` et le contenu réellement émis (action, commande, cible) sans reformulation trompeuse (FR13, UX-DR17)
**Et** l'app n'invente aucune politique d'approbation ni décision automatique

**Étant donné** la demande affichée
**Quand** Alanc touche « Autoriser » ou « Refuser »
**Alors** la décision est persistée puis envoyée à la demande visée, et l'état n'est mis à jour qu'à la confirmation de Hermes
**Et** une perte réseau laisse l'issue inconnue, sans renvoi automatique

**Étant donné** les boutons de décision
**Quand** ils sont utilisés au lecteur d'écran et en texte agrandi
**Alors** ils ont des noms accessibles distincts et des cibles tactiles suffisantes

### Story 6.4 : Récupérer les fichiers produits par Hermes

En tant qu'Alanc,
Je veux ouvrir ou télécharger depuis la conversation les fichiers que Hermes a produits,
Afin d'utiliser ses résultats directement sur mon téléphone.

**Critères d'acceptation :**

**Étant donné** un fichier résultat rendu accessible par Hermes
**Quand** il apparaît dans la conversation
**Alors** il est identifiable (nom, type, taille si connue) comme résultat disponible (FR14, UX-DR18)

**Étant donné** une simple mention de chemin serveur sans accès authentifié résolu
**Quand** elle est affichée
**Alors** elle est présentée comme non récupérable depuis le téléphone, distincte d'un résultat disponible

**Étant donné** un résultat disponible
**Quand** Alanc le télécharge
**Alors** l'accès est authentifié pour son profil et sa session, le fichier est stocké dans l'emplacement des résultats séparé des pièces jointes, et il peut être ouvert par l'application adaptée du téléphone selon son format
**Et** aucun fichier n'est exécuté automatiquement et aucune credential n'est envoyée à une autre origine

**Étant donné** un téléchargement échoué
**Quand** l'échec survient
**Alors** l'app l'indique et permet de réessayer, sans présenter le fichier comme récupéré

### Story 6.5 : Valider le MVP par un essai réel

En tant qu'Alanc,
Je veux dérouler l'essai d'acceptation sur mon téléphone et mon installation réelle,
Afin de déclarer le MVP accepté sur des preuves et non sur des simulations.

**Critères d'acceptation :**

**Étant donné** l'installation réelle, le téléphone d'Alanc et le corpus de 4.1
**Quand** l'essai est déroulé
**Alors** sont constatés : nouvelle conversation par défaut, profils affichés sans configuration, échanges avec deux profils et reprise de leur historique, long texte, image et document reçus par Hermes, détail d'une action, fin d'un travail notifiée après avoir quitté l'app (NFR5)
**Et** une demande d'arrêt confirmée par le serveur, une réponse à une question de Hermes et, si exposées, une décision d'autorisation et la récupération d'un fichier résultat

**Étant donné** l'ensemble des essais
**Quand** l'indicateur de contrôle est relevé
**Alors** aucune duplication d'exécution ni perte de brouillon n'a été observée

**Étant donné** les parcours essentiels
**Quand** ils sont refaits au lecteur d'écran, en texte agrandi et clavier affiché
**Alors** ils restent utilisables (NFR1)

**Étant donné** un contrôle indisponible ou une capacité obligatoire non démontrée
**Quand** le rapport d'essai est rédigé
**Alors** il est expliqué et bloque l'acceptation, sauf décision explicite d'Alanc de retrait ou de report (NFR4)
