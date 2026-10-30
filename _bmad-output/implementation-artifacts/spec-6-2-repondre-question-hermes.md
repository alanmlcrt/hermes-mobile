---
title: 'Story 6.2 — Répondre à une question de Hermes'
type: 'feature'
created: '2026-10-30'
status: 'ready-for-dev'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/contracts/README.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Quand Hermes pose une question (`clarify`), l'app ne la reçoit jamais : elle ne déclare pas `client.capabilities {server_requests: true}`, et une requête serveur → client (`id` `srq-…`, `method` ≠ `event`) tombe aujourd'hui dans le vide. L'agent attend alors 300 s pour rien.

**Approach:** Déclarer la capacité à chaque connexion, faire passer les `clarify` (en direct et via `open_requests`) dans la projection comme une carte « question » avec l'état `waitingInput`, persister la réponse d'Alanc comme opération indexée par l'id de requête, puis envoyer une seule trame `{id, result: {answers, outcome: "submitted"}}`.

## Boundaries & Constraints

**Always:**
- La question et les choix sont affichés tels qu'émis, suffixe « (Recommended) » compris. L'état est dit par un libellé, pas seulement par une couleur.
- La réponse est enregistrée en base avant que la trame parte. Clé : l'id `srq-…`. Une deuxième réponse au même id n'est jamais envoyée automatiquement.
- Toute autre requête serveur (`approval`, `sudo`, `secret`…) reçoit tout de suite une réponse d'erreur JSON-RPC (méthode non prise en charge). L'agent garde ainsi le comportement d'avant la capacité, sans attendre son délai, jusqu'à la 6.3.
- La prise en compte est immédiate (mesure 6.1). La confirmation, c'est le `tool.complete` de l'outil `clarify` dans la même session.
- Aucun texte de question ou de réponse dans les journaux de diagnostic.

**Never:**
- Pas de `clarify.lock` (verrouillage question par question). Pas de bouton « ignorer » ni de réponse vide : chaque question exige une réponse non vide. Stopper le travail (3.5) reste la sortie.
- Pas de traitement des autorisations (6.3), ni de modification du plugin de notifications.

**Décisions d'Alanc (2026-10-30) :**
- La réponse se saisit dans la carte question : choix et champ propres. Le composeur reste celui des messages ordinaires. Un message envoyé pendant l'attente part en `prompt.submit`, redirigé dans le tour en cours.
- Pas de notification de question app fermée dans cette story : c'est reporté (`deferred-work.md`), et une question non vue expire côté Hermes.
- La spec reste entière malgré sa taille (~2 400 tokens).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Question en direct | trame `clarify` (fixture `clarify-request.json`) | carte question dans le tour en cours, état `waitingInput`, libellé « Hermes attend ta réponse » | — |
| Réponse | Alanc choisit ou tape, puis valide | ligne en base, puis trame `clarify-answer.json` ; carte « Réponse envoyée » → « Réponse prise en compte » au `tool.complete` du clarify ; état revient à `running` | écriture socket impossible → « Issue inconnue », pas de renvoi |
| Choix multiple | `multi_select: true` | plusieurs choix cochables ; réponse = choix joints par « , » (texte libre ajouté en dernier) | — |
| Expirée / annulée | événement `request.cancel {id, method, reason}` | carte fermée « Question expirée » ou « Question annulée », plus de saisie | — |
| Reconnexion, encore ouverte | `open_requests` contient l'id | carte rouverte ; si une réponse locale existe, mention « réponse précédente non reçue », Alanc peut répondre à nouveau à la main | — |
| Reconnexion, close | id absent de `open_requests` | carte fermée, sans renvoi de la réponse locale | — |
| Requête inconnue | `method: "approval"` | trame d'erreur immédiate, rien dans le fil | — |

</frozen-after-approval>

## Code Map

- `lib/models/connection_gateway.dart:39` -- `ConnectionGateway` : ajouter `respond(id, {result | error})`.
- `lib/data/connection_repository.dart:320-459` -- `_openSocket` : envoyer `client.capabilities {server_requests:true}` à côté de `gateway.capabilities` (:368, une fois par socket). Ajouter une branche pour les trames avec `id` chaîne et `method` ≠ `event` hors `_calls` : `clarify` → `GatewayEvent` synthétique `server.clarify` (session `params.session_id`, payload `{id, questions, answers?}`) ; le reste → erreur immédiate. Ajouter `server_requests`/`clarify` à `_documentaryCapabilities` (:51).
- `lib/data/hermes_adapter.dart:398-412, 501-534` -- `resumed` / `since` : lire `open_requests` (schéma `OpenRequestEntry {id, method, params}`) et les rejouer comme les `server.clarify` en direct.
- `lib/models/timeline.dart:8, 129-137, 400` -- `WorkState` + `waitingInput` ; nouvel item `QuestionItem` (clé `'k'` nouvelle, sérialisé avec la projection) ; `Resumed` + `openRequests`.
- `lib/data/conversation_repository.dart:307, 445-559, 722-806` -- `_onEvent` / `_reduce` : ouvrir et fermer la carte (`server.clarify`, `request.cancel`, `tool.complete` name `clarify`). `_resync` réconcilie avec `open_requests`.
- `contracts/event-mapping.json` + `lib/data/event_mapping.dart:7` -- mapper `request.cancel`, sinon il tombe en `unknown` → activité cachée.
- `lib/data/outbox_repository.dart:805, 1200-1219` -- modèle à suivre (insertion transactionnelle avant envoi, `unknown` sans renvoi, `_recover` :591). Ne pas toucher au flux `prompt.submit`.
- `lib/data/storage/migrations.dart:24` -- ajouter une entrée (v17) : table `intervention_answers` (`request_id` PK, clé de conversation, `answers` JSON, `state` sending|sent|confirmed|unknown|closed, `created_at`).
- `lib/features/conversation/draft_view.dart:480-610` (+ `draft_view_model.dart`) -- branche `QuestionItem` dans `block()`.
- `lib/ui/components/` (nouveau `question_card.dart`), `lib/ui/content.dart:185-198`, `lib/ui/components/work_state_label.dart:19-35`, `lib/ui/gallery.dart:151-217` -- carte, textes FR, libellé `waitingInput`, section galerie.
- Contraintes : `test/visual_literals_test.dart` (littéraux visuels seulement dans `tokens.dart`) ; `test/architecture_imports_test.dart` (features/models n'importent pas `data/`).

## Tasks & Acceptance

**Execution:**
- [ ] `contracts/fixtures/request-cancel.json`, `contracts/event-mapping.json`, `contracts/README.md` -- fixture `request.cancel` (format lu dans `server_requests.py` épinglé : événement `request.cancel`, payload `{id, method, reason}`), mapping, ligne README -- couvrir le contrat.
- [ ] `lib/models/connection_gateway.dart`, `lib/data/connection_repository.dart` -- capacité, routage des requêtes serveur, `respond`, refus des autres méthodes -- point d'entrée unique.
- [ ] `lib/data/hermes_adapter.dart`, `lib/models/timeline.dart` -- `open_requests`, `QuestionItem`, `waitingInput` -- modèle.
- [ ] `lib/data/storage/migrations.dart`, nouveau `lib/data/intervention_repository.dart` -- persister puis envoyer, états, `_recover` (sending → unknown) -- pas de rejeu.
- [ ] `lib/data/conversation_repository.dart`, `contracts`-driven `event_mapping.dart` -- projection et réconciliation au resync.
- [ ] `lib/ui/components/question_card.dart`, `content.dart`, `work_state_label.dart`, `gallery.dart`, `draft_view.dart`, `draft_view_model.dart` -- affichage et saisie.
- [ ] `test/connection_repository_test.dart`, `test/conversation_test.dart`, `test/resync_test.dart`, nouveau `test/intervention_test.dart`, `test/draft_flow_test.dart`, `test/gallery_test.dart` -- couvrir chaque ligne de la matrice, avec les fixtures `clarify-*`.

**Acceptance Criteria:**
- Étant donné une connexion ouverte, quand `gateway.ready` arrive, alors une seule trame `client.capabilities {server_requests: true}` est envoyée sur ce socket.
- Étant donné une carte question, quand elle est lue au lecteur d'écran ou en texte agrandi, alors la question, chaque choix et le bouton d'envoi ont des noms accessibles distincts et des cibles tactiles suffisantes.
- Étant donné une réponse en `sending` au redémarrage de l'app, quand l'app se relance, alors elle passe en `unknown` et n'est jamais renvoyée automatiquement.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

Une requête serveur est convertie en `GatewayEvent` synthétique dans `connection_repository`. Elle emprunte ainsi le chemin existant (routage par session et génération de socket, projection), sans nouveau flux parallèle. `open_requests` produit les mêmes événements, et une seule fonction de réduction ouvre ou ferme la carte.

## Verification

**Commands:**
- `fvm flutter analyze` -- expected: aucun problème
- `fvm flutter test` -- expected: tous les tests passent

**Manual checks (if no CLI):**
- Galerie (`lib/main_gallery.dart`) : carte question ouverte, envoyée, prise en compte, expirée, en clair et en sombre.
