---
title: 'Story 2.3 — Lire la réponse en direct avec mise en forme et code'
type: 'feature'
created: '2026-10-21'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'c8677ce5cc121845bcf09a24e03caae4cccdebd2'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/recherche-contrat-epic-2.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Après l'envoi (2.2), rien n'affiche la demande ni la réponse de Hermes : Alanc ne voit ni le texte qui arrive, ni la fin, ni une erreur.

**Approach:** Un `ConversationRepository` (seul auteur de la projection) applique les événements `/api/ws` d'une session via la table déclarative `contracts/event-mapping.json`, publie une `TimelineProjection` immuable et l'enregistre avec son curseur en une seule écriture. L'écran de conversation rend le fil (Markdown, emojis, code) au-dessus du composer, fixé en bas.

## Boundaries & Constraints

**Always:**
- Projection clé par (`ConnectionKey`, `ProfileKey`, `stored_session_id`). `OutboxRepository` signale à `ConversationRepository` la liaison runtime ↔ stored (après `ensureSession`, avec la génération de socket) et chaque opération acceptée (texte exact, `OperationKey`, `user_row_id?`) ; `ConversationRepository` ne crée jamais de session ni d'opération.
- Événements filtrés par `session_id` runtime **et** génération de socket ; mutations sérialisées par session ; projection + curseur (`replay_epoch`, `seq`) écrits dans une seule ligne `conversation_timelines` (migration 5, ajout seul). Événement dont `seq` ≤ curseur : ignoré.
- Mapping lu depuis `contracts/event-mapping.json` (déclaré en asset, décodé en Dart pur) : chaque type → effet (`turnStart`, `textDelta`, `interim`, `terminal`, `activity`, `ignore`) ; pour `message.complete`, `payload.status` `complete|error|interrupted` → `succeeded|failed|stopped`. Type absent → fallback `unknown` : ligne d'activité générique, jamais de détail inventé. `tool.start`/`tool.complete` → activité générique.
- États du travail affichés par libellé (et icône), jamais par la seule couleur : envoi (`sending`), en cours (`running`), fin (`succeeded`), erreur (`failed`), arrêté (`stopped`), inconnu/non synchronisé (`unknown`). Fin de socket, silence ou animation ne terminent jamais un tour : à la perte de socket un tour `running` devient « non synchronisé » sans terminal.
- Rapprochement : bulle utilisateur locale liée par `user_row_id` (réponse de soumission ou `persisted_turn` par position dans le tour), jamais par texte.
- Message : `flutter_markdown_plus` (déjà dépendance), emojis, blocs de code avec défilement horizontal et police à chasse fixe via tokens ; lisible en clair, sombre, texte 200 %. Aucune frappe simulée caractère par caractère ; sous mouvement réduit, aucune animation d'apparition.
- Erreur de tour (`status:error`, `error`/`error_surface` du payload, événement `error`) : message simple en français via `Content` ; brouillon intact. Aucun texte de conversation dans les logs.
- Composant message et ligne d'activité dans la galerie (états représentatifs). Libellés dans `Content`, styles via tokens.
- Reconstruire le rendu ne rejoue aucun appel : le ViewModel est possédé par la page (comme 2.1).

**Never:**
- Pas de `session.history`, `session.events.since`, ni reprise après coupure (2.4) ; pas d'historique (2.6) ; pas d'illustrations d'activité (Epic 3).
- Pas de `flutter_markdown`, pas de nouvelle dépendance sans nécessité démontrée.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Tour nominal | accepté, `message.start`, deltas, `message.complete{status:complete}` | Bulle utilisateur puis réponse progressive, état « Terminé » | N/A |
| Delta nul | `message.delta{text:null}` | Ignoré | N/A |
| Doublon | même `seq` reçu deux fois | Appliqué une fois | N/A |
| Autre session/génération | événement d'un autre runtime ou ancienne socket | Ignoré | N/A |
| Erreur de tour | `message.complete{status:error}` | État « Erreur » + explication | Brouillon intact |
| Interrompu | `status:interrupted` | État « Arrêté » | N/A |
| Socket perdue en cours | tour `running`, perte de socket | « Non synchronisé », pas de terminal | N/A |
| Type inconnu | `tool.start` / `foo.bar` | Ligne d'activité générique | N/A |
| Relance | projection enregistrée | Fil relu depuis SQLite à l'ouverture | N/A |

</frozen-after-approval>

## Code Map

- `lib/data/outbox_repository.dart` -- `_ensure` (liaison runtime/génération), `_accept` (opération acceptée) : notifier `ConversationRepository` ; `status()`/`_onEvent` gardent la logique de tour en cours d'AD-5.
- `lib/data/connection_repository.dart` -- flux `events` (`GatewayEvent` : `sessionId`, `type`, `payload`, `seq`, `generation`) et `gateway.ready` (`replay_epoch`) ; perte de socket via changement de génération / `link`.
- `lib/data/hermes_adapter.dart` (`HermesRpc`) -- seul endroit qui lit les champs Hermes (`text`, `status`, `persisted_turn`, `error`).
- `contracts/event-mapping.json`, `test/contracts_test.dart`, `contracts/fixtures/message-*.json` -- table à enrichir et valider contre les fixtures (`message.delta`, `message.interim`, `error`, `tool.start`).
- `lib/data/storage/migrations.dart` -- migration 5 `conversation_timelines`.
- `lib/features/conversation/draft_view.dart`, `draft_view_model.dart` -- écran actuel : y ajouter le fil au-dessus du composer.
- `lib/ui/components/`, `lib/ui/tokens.dart`, `lib/ui/content.dart`, `lib/ui/gallery.dart` -- composants message/activité, tokens code (police, fond), libellés.
- `test/send_flow_test.dart`, `test/support/connection_fakes.dart` -- harness RPC/événements à réutiliser.

## Tasks & Acceptance

**Execution:**
- [x] `contracts/event-mapping.json`, `pubspec.yaml` (asset), `lib/data/event_mapping.dart` -- table enrichie + décodeur pur testé contre toutes les fixtures.
- [x] `lib/models/timeline.dart` -- `TimelineProjection` immuable, items (utilisateur, réponse, activité), état du travail.
- [x] `lib/data/conversation_repository.dart`, `lib/data/storage/migrations.dart` -- application sérialisée, déduplication, écriture atomique projection+curseur, relecture.
- [x] `lib/data/outbox_repository.dart`, `lib/app/bootstrap.dart`, `lib/app/routes.dart` -- liaison runtime et opérations acceptées, injection explicite.
- [x] `lib/ui/components/message_bubble.dart`, `activity_line.dart`, `lib/ui/*` -- rendu Markdown/code, états libellés, galerie.
- [x] `lib/features/conversation/*` -- fil dans l'écran, annonces des changements d'état (région live).
- [x] `test/*` -- matrice I/O, migration 4→5, rendu (code défilant, 200 %, sombre, mouvement réduit), rebuild sans appel.

**Acceptance Criteria:**
- Given une réponse avec titres, listes, emoji et bloc de code long, when elle s'affiche à 200 % en sombre, then elle est lisible sans débordement et le code défile horizontalement.
- Given le fil affiché, when l'écran est reconstruit (rotation, thème), then aucun appel RPC n'est émis et le fil est identique.

## Implementation Notes

## Spec Change Log

- Revue 1 — constat : l'Intent plaçait le fil « sous le composer » (erreur de rédaction ; le Code Map disait « au-dessus »). Amendé : fil au-dessus, composer fixé en bas, liste paresseuse avec défilement vers le plus récent. Évite un écran de conversation à l'envers. KEEP : tout le reste de l'implémentation (réducteur, mapping, persistance, composants).

## Review Triage Log

| # | Source | Constat | Verdict | Preuve / route |
|---|--------|---------|---------|----------------|
| 1 | worker, blind | Fil sous le composer | medium | Erreur de spec ; amendée (Change Log). patch |
| 2 | blind, edge | Échec d'écriture : cache et curseur divergent ; erreurs du réducteur avalées | medium | `_enqueue` met `_cache` à jour avant `_write`, `catchError` vide. patch |
| 3 | blind | Réécriture complète de la projection à chaque delta | medium | `INSERT OR REPLACE` du JSON entier par événement. patch (coalescence) |
| 4 | blind, edge | Bulle perdue si la relecture du brouillon échoue après acceptation | medium | `catchError((_) => null)` sur la relecture. patch |
| 5 | blind | Images Markdown chargées depuis le réseau | medium | `MarkdownBody` sans `imageBuilder`. patch |
| 6 | edge | Chaîne de `dispose` interrompue par une erreur | low | `.then` saute la suite. patch (correction directe) |
| 7 | gap | `interim`, epoch/curseur, texte final, premier envoi, erreur de tour : non testés | medium | Gaps vérifiés. patch |
| 8 | blind, edge | `unknown` jamais résolu ; rejeu après nouveau runtime | medium | Reprise et rejeu = story 2.4 (spec rédigée). defer |
| 9 | blind, edge | Appariement positionnel des tours fragile (autre client) | low | Session pilotée par un seul client au MVP. defer |
| 10 | blind | `_finish` ignore le texte final avec plusieurs segments | maybe-false | Le texte final après `interim` peut ne couvrir que le dernier segment ; à trancher sur trames réelles. rejeté (low) |
| 11 | blind | Asset de mapping invalide bloque l'app ; flood d'activités | low | Asset versionné et testé ; volume limité. rejeté |
| 12 | edge | Delta tardif, terminal dupliqué, `error` vide, dispose tardif, erreur VM transitoire | low/false | `seq` dédoublonne ; cas non observés. rejeté |
| 13 | blind | Police `monospace` hors Android, `pubspec` | false | Dépendance déjà déclarée ; Android d'abord. rejeté |

## Verification

**Commands:**
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat analyze` -- expected: aucun problème
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat test` -- expected: tous verts
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat build apk --debug` -- expected: build réussi
