# Epic 6 Context: Répondre à Hermes et récupérer ses résultats

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Quand Hermes pose une question ou demande une autorisation, la demande apparaît dans la conversation et Alanc y répond depuis son téléphone ; les fichiers que Hermes écrit pendant un tour s'ouvrent ou se téléchargent depuis le fil. L'epic clôt le MVP par un essai d'acceptation réel sur le téléphone et l'installation d'Alanc. La porte G4 est fermée (2026-10-30) : FR13 et FR14 sont retenus et les capacités nécessaires (`server_requests`, `clarify`, `approval`, `steer`, `result_download`) ont été mesurées présentes sur l'installation réelle.

## Stories

- Story 6.1 : Trancher les interventions et résultats sur mon installation (jouée, G4 fermée)
- Story 6.2 : Répondre à une question de Hermes
- Story 6.3 : Autoriser ou refuser une action demandée par Hermes
- Story 6.4 : Récupérer les fichiers produits par Hermes
- Story 6.5 : Valider le MVP par un essai réel

## Requirements & Constraints

- La question ou l'autorisation affichée est celle réellement émise par Hermes, sans reformulation trompeuse ; l'app n'invente aucune politique d'approbation ni décision automatique.
- La prise en compte d'une intervention (immédiate ou différée) est explicite pour l'utilisateur. Mesuré : réponse à `clarify` et message envoyé pendant un tour sont pris en compte immédiatement.
- Une réponse ou une décision est persistée comme opération avant envoi ; résultat incertain → issue inconnue, jamais de renvoi automatique ; une question traitée, expirée ou annulée n'est plus proposée et une ancienne réponse n'est jamais rejouée.
- L'état d'une autorisation n'est mis à jour qu'à la confirmation de Hermes.
- Mode d'autorisation par profil (`manual`, `smart`, `off`) : affiché et modifiable profil par profil, valeur affichée = valeur relue sur Hermes après confirmation, aucun mode imposé par l'app ; le passage en `off` est signalé comme désactivant toute demande.
- Un fichier résultat = fichier écrit par Hermes pendant le tour (`write_file`, chemin absolu). Un chemin seulement cité dans le texte n'est pas un résultat et doit apparaître comme non récupérable depuis le téléphone.
- Résultat identifiable (nom, type, taille si connue) ; téléchargement authentifié pour son profil et sa session ; échec signalé avec possibilité de réessayer, jamais présenté comme récupéré ; aucun fichier exécuté automatiquement ; aucune credential envoyée à une autre origine.
- Essai d'acceptation (6.5) sur installation réelle, aucune simulation locale ne vaut validation : nouvelle conversation par défaut, profils affichés, deux profils avec reprise d'historique, long texte, image et document reçus, détail d'une action, fin notifiée app quittée, arrêt confirmé, réponse à une question et, si exposées, décision d'autorisation et récupération d'un résultat. Indicateur : aucune duplication d'exécution ni perte de brouillon. Parcours essentiels refaits au lecteur d'écran, texte agrandi et clavier affiché. Une capacité obligatoire non démontrée bloque l'acceptation sauf décision explicite d'Alanc.
- Aucun secret, texte de conversation ni chemin dans les journaux de diagnostic.

## Technical Decisions

- **Activation obligatoire** : Hermes n'envoie questions et autorisations qu'au client qui a déclaré une fois par connexion `client.capabilities {server_requests: true}`. L'app actuelle ne l'envoie pas ; sans cela l'agent attend jusqu'à son délai (300 s pour clarify).
- **Requêtes serveur → client** JSON-RPC (`id` = `srq-<12 hex>`, champ `method`, sans `result`), confinées à l'adaptateur Hermes.
  - `clarify` : params `session_id`, `questions[]` (`qid`, `question`, `choices?`, `multi_select`). Réponse `{id, result: {answers: {qid: texte}, outcome: "submitted"}}` ; sans `answers` = annulation. Un choix peut être suffixé « (Recommended) » par le serveur : l'afficher tel quel.
  - `approval` : params `request_id`, `command` (déjà expurgée par le serveur), `description`, `pattern_key(s)`, `choices` (`once`, `session`, `always`, `deny`), `allow_session`, `allow_permanent`. Réponse `{choice}`. Un refus produit `tool.complete` avec `result.status = "blocked"` et `user_summary`.
- **Reconnexion** (documentaire, non mesuré) : les requêtes sans réponse reviennent dans `open_requests` de `session.resume` / `session.events.since` ; expiration/annulation émet `request.cancel {id, method, reason}` ; une réponse à un id fermé est ignorée ; `approval.pending` relit les autorisations en attente.
- **Message pendant le travail** : `prompt.submit` pendant un tour répond `redirected` (injecté dans le tour en cours).
- **Mode d'autorisation** : `config.get` / `config.set approvals.mode` avec `profile` (mesuré sans effet sur le profil par défaut). Tous les profils sont en `smart` : la plupart des commandes sont auto-approuvées ; une demande n'arrive qu'en `manual` ou si le juge smart hésite. Les commandes `BLOCKED (hardline)` ne sont jamais proposées.
- **Résultats** : aucun événement « résultat disponible » ; repérage par l'app via `tool.complete` de `write_file` (`args.path` absolu). Téléchargement `GET /api/fs/download?path=&profile=&session_id=` (bearer), renvoyé en `attachment` avec nom et type ; chemin absent = 404. Stockage dans un emplacement séparé de `attachments/<DraftKey>/`.
- **États** : `waitingInput` et `waitingApproval` de la famille « travail distant » sont désormais activables (retenus et exposés). Ils restent distincts des états de connexion et d'acceptation locale ; un terminal vient toujours du serveur.
- Projection, opérations et propriétaires uniques suivent les règles existantes (`ConversationRepository`, `OutboxRepository`, mutations sérialisées par session) ; fixtures de référence dans `contracts/fixtures/` (`client-capabilities.json`, `clarify-*.json`, `approval-*.json`, `prompt-submit-redirected.json`, `result-file-written.json`).

## UX & Interaction Patterns

- Composant Intervention : question ou autorisation dans le fil, état exprimé par libellé et pas seulement par couleur, réponse possible sur place.
- Boutons « Autoriser » / « Refuser » : noms accessibles distincts, cibles tactiles suffisantes, utilisables au lecteur d'écran et en texte agrandi.
- Composant Résultat : fichier identifiable dans le fil, ouvrable par l'application adaptée du téléphone ; distinction visible entre résultat disponible et chemin serveur inaccessible. La scène `mockups/exchange-conversation.html` (fichier résultat en fin d'échange) sert de référence visuelle.
- Palette de secours validée et figée (texte et erreur ≥ 5,3:1 ; contours 1,5–1,8:1 acceptés car décoratifs).
- Vocabulaire quotidien, détails techniques non dominants.

## Cross-Story Dependencies

- 6.2 et 6.3 reposent sur l'envoi de `client.capabilities {server_requests: true}` à chaque connexion ; à poser une seule fois dans l'adaptateur (premier des deux à être implémenté).
- 6.4 réutilise l'auth bearer (Epic 1) et la séparation pièces/résultats posée en Epic 4.
- 6.5 dépend de 6.2–6.4 et de tous les epics précédents (notifications Epic 5, corpus de 4.1).
- Epic 8 (salons, « Besoin de toi ») réutilisera les composants d'intervention et d'autorisation de cet epic.
- Contrainte d'essai : ne jamais installer de build debug sur le téléphone d'Alanc (même applicationId, perte de l'appairage) ; utiliser une release avec build number supérieur.
