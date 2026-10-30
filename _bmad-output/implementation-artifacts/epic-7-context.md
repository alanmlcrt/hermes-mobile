# Epic 7 Context: Ranger et retrouver mes conversations

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Permettre à Alanc de ranger ses conversations Hermes et de retrouver un fil par son titre ou son contenu, tout en conservant une liste réutilisable par les futurs salons. Cet epic est post-MVP et suit l’epic 6. Son périmètre provient de `EPIC-7-REFERENCE.md`, extrait de travail copié le 30 octobre 2026 depuis l’autre checkout ; il reste provisoire et n’est pas intégré au plan de `master`. Les contraintes ci-dessous sont complétées par le PRD, l’architecture et les documents UX présents dans les planning-artifacts. Le plan partagé ne doit pas être remplacé par cet extrait.

## Stories

- Story 7.1: Vérifier le rangement et la recherche sur mon installation
- Story 7.2: Renommer une conversation
- Story 7.3: Épingler et marquer non lu
- Story 7.4: Masquer et retrouver des conversations
- Story 7.5: Supprimer une conversation
- Story 7.6: Rechercher une conversation

## Requirements & Constraints

Hermes reste l’autorité sur les profils, les conversations et leur historique distant. Le téléphone ne crée ni moteur d’agent ni administration parallèle et n’accède jamais directement aux bases privées de Hermes. Le titre, le masquage et la suppression doivent passer par les capacités réellement exposées ; l’épingle et le marqueur non lu appartiennent au téléphone, avec une identité complète connexion/profil/session.

Les noms `session.title`, `session.set_hidden`, `session.archive` et `session.delete` sont des pistes à vérifier, pas des contrats validés. Les paramètres, réponses, erreurs, capacités détectées, effets sur les listes et visibilité depuis un autre client doivent être consignés avec des échanges anonymisés dans `contracts/`. La présence ou l’absence d’une recherche serveur doit être constatée. Un comportement observé, une lecture du source et une hypothèse doivent rester distinguables. Une méthode absente désactive la fonction correspondante avec une explication ; aucun contournement n’est inventé.

Les essais avec effets utilisent exclusivement un profil et des conversations dédiés. Worktrees, serveur et appareil ne constituent pas des environnements isolés : préserver les données et essais de l’epic 6 et séparer ports et données locales lorsque nécessaire. Une installation inaccessible permet de préparer les essais, mais interdit de valider la story par simulation. Les secrets et contenus personnels restent absents des fixtures, journaux et diagnostics.

Une coupure conserve les saisies et expose les résultats incertains. Une mutation n’est pas rejouée automatiquement sans preuve d’idempotence pour la méthode et la version concernées. La suppression doit tenir compte du travail distant et des envois non résolus ; le nettoyage local dépend d’une confirmation serveur. Les profils restent identifiés et leurs messages, fichiers et états ne sont jamais mélangés.

## Technical Decisions

L’architecture impose un adaptateur Hermes unique et des contrats partagés hors Flutter. Le backend Desktop officiel, lancé par `hermes serve`, constitue le point d’entrée : REST pour les ressources et JSON-RPC sur `/api/ws`. Le build installé et ses capacités font référence ; ni un schéma amont ni `info.version` seul ne prouvent la disponibilité d’une fonction.

Les vues affichent, les ViewModels transmettent les intentions, les repositories possèdent l’état et les services gèrent réseau et plateforme. `ConnectionRepository` possède connexions, capacités, profils et socket ; `ConversationRepository` possède la projection distante ; `OutboxRepository` possède brouillons, pièces sortantes et opérations locales. Les mutations sont sérialisées par session. Le stockage mobile utilise SQLite avec migrations en ajout seul, sans migration de Hermes.

Les données portent `ConnectionKey + ProfileKey + SessionKey` ; la connexion a une identité locale stable indépendante de son URL et les identifiants Hermes restent opaques, sensibles à la casse. L’authentification Hermes reste distincte de Tailscale. Une méthode absente, un refus d’authentification et une panne transitoire constituent des erreurs différentes. Les notifications sont des indices pour recharger l’état authentifié, jamais une preuve d’état distante.

## UX & Interaction Patterns

La conversation reste centrale, avec des actions courantes accessibles sans commande `/`. Les états sont lisibles au toucher, avec texte agrandi et lecteur d’écran ; épingle et non-lu ont un repère autre que la seule couleur et une annonce accessible. Le thème et les tokens sémantiques restent centralisés.

L’interface distingue liste vide, recherche sans résultat et erreur de chargement. Le rangement présente les conséquences partagées avec Hermes et distingue le masquage réversible de la suppression définitive. La recherche indique sa couverture réelle, notamment le contenu déjà chargé sur le téléphone lorsque la recherche serveur est absente. Une recherche multi-profils conserve des groupes identifiables.

## Cross-Story Dependencies

L’investigation 7.1 précède les fonctions dépendant des méthodes serveur. Les fonctions locales peuvent être préparées si elles ne supposent aucune capacité non démontrée. Les marqueurs de fin de tour, les protections contre suppression pendant un travail et la navigation depuis notification dépendent des contrats d’exécution et d’intervention ; vérifier leur compatibilité avec l’epic 6 avant de les implémenter.

L’epic 6 doit être intégré avant l’epic 7. Les travaux de cette branche restent indépendants de son checkout ; après mise à jour de la base, réconcilier adaptateur, repositories, migrations, routes et documents communs puis vérifier l’ensemble. Aucune fusion ni publication automatique n’est prévue pour démarrer l’investigation.
