---
title: 'Story 2.4 — Retrouver mon travail après une coupure ou un retour dans l''app'
type: 'feature'
created: '2026-10-21'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '23bbfe0c7ed74cce369842637a7abd831609005a'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/recherche-contrat-epic-2.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Après une coupure, un passage en arrière-plan ou une relance, le fil reste « non synchronisé », les événements manqués sont perdus et une opération `unknown` le reste même quand Hermes l'a reçue.

**Approach:** À chaque nouvelle socket (et au retour au premier plan), `ConversationRepository` resynchronise les conversations affichées ou actives : reprise de la session, rejeu depuis le curseur `(epoch, seq)` quand c'est sûr, sinon snapshot complet par l'historique ; les opérations `unknown` sont tranchées par position des lignes serveur, jamais par texte ni par renvoi.

## Boundaries & Constraints

**Always:**
- Reprise : `OutboxRepository` reste seul à appeler `session.create`/`session.resume` ; il expose une reprise (`resume`) qui rend runtime, `running`, `inflight`, `queued` et lie le runtime à `ConversationRepository` (comme `ensureSession`). Pendant la resynchronisation la connexion affiche `resynchronisation`, distincte de l'état du travail.
- Rejeu par curseur seulement si `replay_epoch` de `gateway.ready` égale l'epoch enregistrée **et** si la liaison runtime n'a pas changé de numérotation ; sinon snapshot. `session.events.since {session_id, last_seen}` : événements `seq` ≤ curseur écartés ; `truncated:true`, trou de `seq` ou epoch différente → snapshot.
- Snapshot = `session.history` (lignes `display_kind:"hidden"` ignorées) reconstruit en projection : lignes utilisateur/assistant avec `row_id`, état du travail depuis `running`/`inflight` de la reprise (partiel assistant affiché comme en cours), puis curseur remis sur la `latest_seq` connue ou vide. Écriture atomique projection + curseur.
- Événements d'une ancienne génération de socket ou d'un ancien runtime : écartés (déjà en place, à garder).
- Rapprochement d'une opération `unknown` : l'opération enregistre, avant soumission, le plus grand `row_id` utilisateur connu de la session (`row_watermark`, migration en ajout seul). Après snapshot : la plus ancienne ligne utilisateur de `row_id` > watermark non liée à une autre opération → opération `accepted` (liaison par position), brouillon traité comme une acceptation (révision). Aucune telle ligne, `running` faux, `inflight` et `queued` vides → `failed` (non reçue), brouillon intact, renvoi manuel permis. Sinon reste `unknown`, affichée comme telle. Jamais de renvoi automatique.
- Retour au premier plan : si la connexion n'est pas `connecté`, déclencher `reconnect()` ; le travail côté serveur n'est jamais annulé par l'app (`close_on_disconnect:false` déjà posé).
- Fixtures synthétiques du contrat pour `session.events.since` (nominal, tronqué), `session.history`, `session.resume` en cours.

**Never:**
- Aucun renvoi de `prompt.submit`, aucune comparaison de texte, aucun texte de conversation dans les logs.
- Pas de liste de conversations ni de route `/c/...` (2.6) ; pas de notification (Epic 5).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Coupure après acceptation | tour accepté, socket perdue, reconnexion même epoch | `events.since` rejoue la fin, réponse complète, aucun submit | N/A |
| Doublon au rejeu | événements `seq` déjà appliqués | Ignorés | N/A |
| Tronqué / trou | `truncated:true` ou saut de `seq` | Snapshot `session.history` | N/A |
| Redémarrage Hermes | nouvelle `replay_epoch` | Snapshot | N/A |
| Tour toujours en cours | reprise `running:true`, `inflight.assistant` partiel | Fil « en cours » avec le partiel ; envoi bloqué | N/A |
| Unknown reçu | ligne utilisateur `row_id` > watermark | Opération `accepted`, pas de renvoi | N/A |
| Unknown non reçu | aucune ligne, rien en cours/en file | `failed`, brouillon intact | Message « non reçue, vous pouvez renvoyer » |
| Indémontrable | historique indisponible (erreur RPC) | Reste `unknown` | Message inchangé |
| Retour premier plan | app au premier plan, lien `hors ligne` | `reconnect()` puis resynchronisation | N/A |

</frozen-after-approval>

## Code Map

- `lib/data/conversation_repository.dart` -- `bind`, `accepted`, `_onEvent`, `_onSnapshot` (passage `unknown` à la perte de socket), file par session `_enqueue`, `_read`/`_write` (projection + `replay_epoch` + `seq`) : y ajouter `resync`.
- `lib/data/outbox_repository.dart` -- `ensureSession`/`_ensure` (create/resume, génération capturée avant l'appel), opérations `outbox_operations`, état d'envoi rechargé depuis la base : ajouter `resume` et `row_watermark`, rapprochement des `unknown`.
- `lib/data/connection_repository.dart` -- `gateway.ready` (`replay_epoch`), `socketGeneration`, `LinkState.resyncing`, `reconnect()`.
- `lib/data/hermes_adapter.dart` (`HermesRpc`) -- décodage `session.resume` (`running`, `inflight`, `queued`), `session.history`, `session.events.since`.
- `lib/models/timeline.dart` -- `TimelineProjection` (items, `workState`, `replayEpoch`, `seq`).
- `lib/main.dart` -- point d'entrée pour l'observateur de cycle de vie.
- `contracts/fixtures/`, `test/support/connection_fakes.dart`, `test/send_flow_test.dart` -- fakes RPC à étendre.

## Tasks & Acceptance

**Execution:**
- [x] `lib/data/hermes_adapter.dart`, `contracts/fixtures/*` -- décodeurs et fixtures `events.since`, `history`, `resume` en cours.
- [x] `lib/data/storage/migrations.dart` -- migration `row_watermark` sur `outbox_operations` (ajout seul).
- [x] `lib/data/outbox_repository.dart` -- `resume`, watermark avant soumission, rapprochement `unknown`.
- [x] `lib/data/conversation_repository.dart` -- `resync` : rejeu ou snapshot, atomique, sérialisé par session.
- [x] `lib/main.dart` ou `lib/app/*` -- resynchronisation à chaque nouvelle socket et `reconnect()` au retour au premier plan.
- [x] `test/*` -- matrice I/O complète, dont « coupure après acceptation avant réponse » et « événement dupliqué/tronqué/ancien » sans double `prompt.submit` ni perte de brouillon.

**Acceptance Criteria:**
- Given un travail accepté, when Alanc quitte l'app puis revient, then la connexion passe par `hors ligne` puis `resynchronisation` et le fil retrouve l'état exact sans renvoi.
- Given n'importe quel scénario de la matrice, when les tests comptent les trames, then `prompt.submit` n'est jamais émis par la reprise.

## Implementation Notes

## Spec Change Log

## Review Triage Log

| # | Source | Constat | Verdict | Preuve / route |
|---|--------|---------|---------|----------------|
| 1 | blind, edge, coordinateur | Repère local : ligne étrangère créditée à l'opération, brouillon effacé | high | `maxUserRow` lit la projection locale ; `_commitAccepted` vide le brouillon. patch (appariement non ambigu, texte conservé) |
| 2 | blind | `send.not_received` affirme une certitude | medium | Heuristique (rien vu, rien en cours) ; renvoi manuel risqué. patch (libellé prudent) |
| 3 | blind, edge, gap | Repère nul : opération bloquée, snapshot forcé à chaque fois | medium | `continue` + `hasUnknown`. patch |
| 4 | blind | `_persist` efface `user_row_id` | medium | Écriture inconditionnelle de `null` ; `reconcile` s'appuie sur cette colonne. patch |
| 5 | blind, edge | Curseur du snapshot lu avant l'historique | medium | Événements entre les deux appels réappliqués. patch |
| 6 | blind | Resync d'une génération plus récente ignorée | medium | `_resyncs[key] ??=`. patch |
| 7 | blind, edge | `bind` sous `_resyncing` | maybe-false | À vérifier par l'implémenteur. patch (vérification) |
| 8 | blind, edge | `_fromHistory` : lignes non textuelles, `inflight` sans `running`, terminal perdu, partiel dupliqué | medium | Branches de dérivation d'état. patch |
| 9 | blind, edge | Rafale de resync sur toutes les clés | low | Correction bornée. patch |
| 10 | edge | Libellé « Resynchronisation » jamais affiché pendant la resync | medium | Exigence de la spec non tenue. patch |
| 11 | blind, edge | Socket à demi ouverte au retour au premier plan | medium | Aucune sonde. patch (`gateway.ping`) |
| 12 | gap | Replis de rejeu, appariement positionnel, `reconcile`, gardes de reprise non testés | medium | Gaps vérifiés. patch |
| 13 | edge | `count` > messages, `open_requests`, `_filled` numérique, epoch nulle, écrasement pendant envoi | low | Historique complet au MVP ; interventions = Epic 6. rejeté |
| 14 | blind | Opérateur `?` sur les maps (Dart 3.8) | false | SDK épinglé 3.13.5. rejeté |

## Verification

**Commands:**
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat analyze` -- expected: aucun problème
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat test` -- expected: tous verts
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat build apk --debug` -- expected: build réussi
