# Epic 6 Context: Répondre à Hermes et récupérer ses résultats

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Permettre à Alanc de répondre aux questions et autorisations de Hermes depuis le fil, de récupérer les fichiers produits et de clore le MVP par un essai réel. L'epic dépend de G4 et des capacités exposées : une capacité obligatoire absente est remontée, jamais simulée.

## Stories

- Story 6.1 : Trancher les interventions et résultats sur mon installation
- Story 6.2 : Répondre à une question de Hermes
- Story 6.3 : Autoriser ou refuser une action demandée par Hermes
- Story 6.4 : Récupérer les fichiers produits par Hermes
- Story 6.5 : Valider le MVP par un essai réel

## Requirements & Constraints

- **G4 et contrat.** 6.1 consigne dans `contracts/` méthodes, événements, fixtures et capacités des interventions et résultats. FR13/FR14 sont retenus ou retirés explicitement ; les états d'attente ne s'activent que si exposés.
- **Questions.** Afficher la question émise avec un libellé. La réponse est persistée comme opération visant la demande, sans renvoi automatique si l'issue est incertaine ; l'app indique une prise en compte immédiate ou différée. Une question traitée ou expirée n'est plus proposée ; une ancienne réponse n'est jamais rejouée.
- **Autorisations.** Afficher le contenu émis (action, commande, cible), sans reformulation ni politique inventée. « Autoriser »/« Refuser » persistent et envoient la décision à la demande visée ; l'état n'évolue qu'à la confirmation de Hermes, une perte réseau laissant l'issue inconnue. `approvals.mode` (`manual`, `smart`, `off`) se lit et se change pour le profil courant (`config.set` avec `profile`), puis se relit ; aucun défaut n'est imposé et `off` est signalé.
- **Résultats.** Seuls les fichiers écrits par Hermes pendant le tour (`write_file`, chemin absolu) sont des résultats ; un chemin cité dans le texte ne l'est pas. Nom, type et taille si connue ; un chemin serveur inaccessible est distinct d'un résultat disponible.
- **Téléchargement.** Accès authentifié (profil, session) ; stockage séparé des pièces jointes ; ouverture par l'application du format. Aucune exécution automatique ni credential vers une autre origine. Un échec est réessayable, jamais présenté comme récupéré.
- **Qualité et acceptation.** Une coupure ne masque pas un échec, ne perd pas de brouillon et ne relance pas une exécution (NFR2). L'essai couvre le corpus de 4.1 et les parcours du MVP, y compris les volets exposés ; aucune duplication ni perte de brouillon. Un contrôle indisponible bloque l'acceptation, sauf décision d'Alanc (NFR4).

## Technical Decisions

- **Autorité et propriétaires (AD-1/2).** Hermes possède l'exécution et la politique d'approbation ; le mobile transmet des intentions et affiche les preuves. `ConversationRepository` projette, `OutboxRepository` persiste les opérations.
- **Identité et projection (AD-3/4).** Toute donnée porte `ConnectionKey + ProfileKey + SessionKey` ; un résultat reste lié à son profil et sa session. Le mapping événements → états/`ActivityKind` vit dans `contracts/` ; mutations sérialisées, projection et curseur atomiques, doublons et anciens événements écartés, snapshot si nécessaire.
- **Opérations (AD-5).** Persister cible et contenu avant envoi ; issue incertaine → `unknown`, sans renvoi. Rejouer seulement si l'idempotence est démontrée. Viser la demande précise ; seul le serveur fournit un terminal.
- **Fichiers et accès (AD-6/8).** Octets dans un emplacement privé distinct de `attachments/<DraftKey>/`, disponibles après accès authentifié résolu. Aucun fichier exécuté, aucun chemin du téléphone envoyé, aucune credential vers une autre origine.
- **Intégration (AD-7).** `hermes serve` sur 9119 : REST et JSON-RPC `/api/ws`. Capacités détectées à la connexion ; seul l'adaptateur connaît les formats. `approval.pending`, `approval.respond`, `clarify.*` restent à confirmer.

## UX & Interaction Patterns

- Les interventions sont des composants du fil, avec le contenu émis et une action de réponse ou décision ; l'attente est portée par un libellé.
- Une décision reste « en attente de confirmation » tant que Hermes n'a pas répondu ; aucun succès optimiste. Une issue inconnue est dite telle et ne propose un nouvel essai que s'il est sûr.
- « Autoriser »/« Refuser » ont des noms accessibles distincts et des cibles d'au moins 44 px ; le texte agrandi ne tronque rien. `off` est signalé. Un résultat est une carte de fichier avec téléchargement puis ouverture ; progression, échec et nouvelle tentative sont explicites. La palette de secours est vérifiée en clair/sombre et figée.

## Cross-Story Dependencies

- 6.1 conditionne 6.2 à 6.4 : sans contrat ni décision G4, ces fonctions ne sont pas activées ; si FR13/FR14 sont retirés, états et composants sont désactivés.
- 6.2/6.3 réutilisent projection et opérations d'Epic 2/3, ainsi que la détection de capacités d'Epic 1.
- 6.4 réutilise l'accès authentifié et le cloisonnement des pièces jointes d'Epic 1/4 ; le repérage dépend de `write_file`.
- 6.5 dépend du MVP : accueil/profils, historique, arrêt, corpus, notification après fermeture (Epic 5, G3). G3 est ouverte ; la notification de 6.5 exige une décision d'Alanc.
