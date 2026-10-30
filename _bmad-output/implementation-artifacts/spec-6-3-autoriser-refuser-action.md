---
title: 'Story 6.3 — Autoriser ou refuser une action demandée par Hermes'
type: 'feature'
created: '2026-10-30'
status: 'done'
baseline_commit: 'c14fb9008bb7213fba0a9900425d1e018570ef29'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-6-2-repondre-question-hermes.md'
  - '{project-root}/contracts/README.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Depuis la 6.2, toute requête serveur `approval` reçoit aussitôt une erreur `-32601`. Hermes traite cette erreur comme un refus, si bien qu'Alanc ne voit jamais les autorisations demandées. Il ne peut pas non plus voir ni changer le mode d'autorisation (`manual`/`smart`/`off`) d'un profil.

**Approach:** Faire passer `approval` par le même chemin que `clarify`. Elle devient un événement synthétique, puis une carte « autorisation » dans le fil avec l'état `waitingApproval`. La décision est persistée dans `intervention_answers` avant d'envoyer une seule trame `{id, result: {choice}}`. Ajouter aux réglages du profil une section « Autorisations » qui lit le mode par `config.get` et l'écrit par `config.set approvals.mode` avec `profile`.

## Boundaries & Constraints

**Always:**
- La carte affiche tels qu'émis la `description` et la `command`. La commande est en police à chasse fixe, sans troncature trompeuse. L'état est dit par un libellé, pas seulement par une couleur.
- La décision est enregistrée en base avant que la trame parte, avec l'id `srq-…` pour clé. Une issue incertaine reste « inconnue » et rien n'est jamais renvoyé automatiquement. Une carte rouverte par `open_requests` permet une nouvelle décision, prise à la main.
- La confirmation, c'est le `tool.complete` qui suit dans la session, sur un outil autre que `clarify`. `result.status = "blocked"` → « Refusée, la commande n'a pas été lancée ». Tout autre statut → « Autorisée ». Avant ce `tool.complete`, la carte affiche « Décision envoyée ».
- Le mode affiché est la valeur relue par `config.get` après chaque `config.set` réussi. Si la lecture échoue, la section le dit et le changement est désactivé. Un échec de `config.set` laisse l'ancienne valeur et affiche l'erreur. L'app n'écrit jamais de mode d'elle-même.
- Les autres requêtes serveur (`sudo`, `secret`…) reçoivent toujours l'erreur `-32601`.
- Aucun texte de commande ni de description dans les journaux.

**Never:**
- Pas de décision automatique, de mémorisation locale ni de politique propre à l'app.
- Pas de notification d'autorisation quand l'app est fermée (même report que la 6.2). Pas de motif de refus (`/deny <raison>`).
- Pas de nouvelle migration : la décision se range dans `intervention_answers.answers` sous la forme `{"choice": "…"}`.

**Décisions d'Alanc (2026-10-30) :**
- La carte n'offre que « Autoriser » (`once`) et « Refuser » (`deny`). `session` et `always` ne sont jamais proposés ni envoyés, même quand Hermes les permet.
- Passer en `off` demande une confirmation par dialogue avant `config.set`, en plus de l'avertissement sous l'option. Annuler le dialogue ne change rien.
- La 6.3 reste entière (fil + mode), malgré sa taille (~3 000 tokens).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Demande en direct | `approval-request.json` | carte dans le tour en cours, état `waitingApproval`, « Hermes demande ton autorisation » | — |
| Refus | « Refuser » | ligne en base, puis trame `approval-answer.json` (`deny`) ; carte « Décision envoyée », puis « Refusée… » au `tool.complete` bloqué (`approval-denied.json`) ; l'état revient à `running` | écriture socket impossible → « Issue inconnue », pas de renvoi |
| Autorisation | « Autoriser » | trame `{choice: "once"}`, puis « Autorisée » au `tool.complete` non bloqué | idem |
| Expirée / annulée | `request.cancel {method: "approval"}` | carte fermée « Demande expirée » / « Demande annulée » | — |
| Reconnexion | `open_requests` contient / ne contient pas l'id | rouverte (mention « décision précédente non reçue » si une décision locale existe) / fermée sans renvoi | — |
| Hors connexion | lien coupé | boutons désactivés, la carte reste | — |
| Mode lu | `config.get {key: "approvals.mode", profile}` → `{value: "smart"}` | « Hermes juge » sélectionné | lecture impossible → « Mode illisible », pas de changement possible |
| Mode changé | Alanc choisit `manual` | `config.set` puis `config.get` ; la valeur relue s'affiche | refus ou délai dépassé → ancienne valeur + message |
| Passage en `off` | Alanc choisit `off` | avertissement « Hermes ne demandera plus aucune autorisation pour ce profil », puis dialogue de confirmation ; `config.set` seulement si Alanc confirme | annulation → mode inchangé |

</frozen-after-approval>

## Code Map

- `lib/data/hermes_adapter.dart` (`clarifyRequest`, `unsupportedRequest`, `openRequests`) -- généraliser en `serverRequest()`, qui accepte `clarify` et `approval`. `approval` → événement `server.approval`, payload `{id, description, command, choices, allow_session, allow_permanent}`. Ajouter `approvalAnswer(choice)` et des constantes `configGet` / `configSet` / `approvalsMode`. Ne pas utiliser `pending_approval` de `session.resume` : il n'a pas l'id `srq-…`, alors que `open_requests` l'a.
- `lib/data/connection_repository.dart` (`_serverRequest`, `_documentaryCapabilities`, réponse `client-capabilities`) -- router `approval` ; capacité `approval` présente si listée.
- `lib/models/timeline.dart` -- `WorkState.waitingApproval` ; base commune `InterventionItem` (`requestId`, `state` QuestionState, `previousUnanswered`, `copyWith`) héritée par `QuestionItem` et par le nouvel `ApprovalItem` (clé JSON `'k': 'approve'`, champs émis, `choice?`, `blocked?`). `InterventionGateway` + `decide(key, requestId, choice)`. Nouvelle interface `ApprovalModes` (`Future<String> read(ProfileKey)`, `Future<String> write(ProfileKey, String)`).
- `lib/data/conversation_repository.dart` (`_ask`, `_cancel`, `_clarifyDone`, `_afterQuestions`, `_reconcileQuestions`, `_settle`, fermeture à `_finish`, `case EventEffect.intervention`, :1004) -- travailler sur `InterventionItem`. `server.approval` ouvre un `ApprovalItem`. Un `tool.complete` (hors clarify) confirme le dernier `ApprovalItem` non clos (`blocked` = `result.status == "blocked"`). `_afterQuestions` donne `waitingApproval` si une autorisation est ouverte, sinon `waitingInput`.
- `lib/data/intervention_repository.dart` -- extraire le cœur de `answer` (garde `_inFlight`, insertion `sending`, `respond`, `sent`/`unknown`, retour `open` sur `transport.offline`) et l'appeler depuis `decide`. `markQuestion` sert aux deux types de carte. Implémenter `ApprovalModes` : appel de `gateway.call`, puis relecture.
- `contracts/event-mapping.json` / `event_mapping.dart` -- `server.approval` porte l'effet `intervention`.
- `lib/ui/components/approval_card.dart` (nouveau, sur le modèle de `question_card.dart`), `content.dart`, `work_state_label.dart`, `gallery.dart`, `tokens.dart` si besoin.
- `lib/features/conversation/draft_view.dart` / `draft_view_model.dart` -- branche `ApprovalItem`, `vm.decide`.
- `lib/features/profiles/profile_settings_view.dart` + nouveau `approval_mode_section.dart` (Stateful) -- section entre notifications et apparence. `routes.dart`, `bootstrap.dart` et `main.dart` transmettent `ApprovalModes`. Elle est optionnelle, comme `notifications`.
- Contraintes : `test/architecture_imports_test.dart` (features/models n'importent pas `data/`), `test/visual_literals_test.dart`, `test/contracts_test.dart` (`notTracked`).

## Tasks & Acceptance

**Execution:**
- [x] `contracts/event-mapping.json`, `contracts/README.md`, `test/contracts_test.dart` -- mapping de `server.approval`, paragraphe 6.3, retrait de `approval` de `notTracked` -- contrat.
- [x] `lib/data/hermes_adapter.dart`, `lib/data/connection_repository.dart` -- routage d'`approval`, trame de réponse, constantes de config -- point d'entrée unique.
- [x] `lib/models/timeline.dart` -- `InterventionItem`, `ApprovalItem`, `waitingApproval`, `decide`, `ApprovalModes` -- modèle.
- [x] `lib/data/conversation_repository.dart`, `lib/data/intervention_repository.dart` -- projection, confirmation, réconciliation, décision persistée, modes -- logique.
- [x] `lib/ui/components/approval_card.dart`, `content.dart`, `work_state_label.dart`, `gallery.dart`, `draft_view.dart`, `draft_view_model.dart` -- carte et décision.
- [x] `lib/features/profiles/approval_mode_section.dart`, `profile_settings_view.dart`, `lib/app/routes.dart`, `bootstrap.dart`, `lib/main.dart` -- réglage du mode.
- [x] `test/intervention_test.dart`, `test/resync_test.dart`, `test/draft_flow_test.dart`, `test/gallery_test.dart`, nouveau `test/approval_mode_test.dart` -- chaque ligne de la matrice, avec les fixtures `approval-*` et `request-cancel`.

**Acceptance Criteria:**
- Étant donné une carte d'autorisation, quand elle est lue au lecteur d'écran ou en texte agrandi, alors chaque bouton a un nom accessible distinct (« Autoriser la commande », « Refuser la commande ») et une cible d'au moins 48 dp.
- Étant donné une décision en `sending` au redémarrage, quand l'app se relance, alors elle passe en `unknown` et n'est jamais renvoyée.
- Étant donné deux profils, quand le mode de l'un est changé, alors seul `config.set` avec `profile` égal à sa clé est appelé.
- Étant donné une requête `sudo`, quand elle arrive, alors elle reçoit toujours `-32601` et rien n'apparaît dans le fil.

## Implementation Notes

- `_approvalDone` ne confirme que la dernière autorisation en `sent`/`unknown`, et seulement si le résultat concorde avec le choix envoyé (`deny` ⇔ `result.status = "blocked"`, `once` ⇔ non bloqué) ; sinon la carte ne change pas. Une carte ouverte ou en `sending` n'est jamais touchée par un `tool.complete` (un autre outil peut finir en parallèle) ; elle ne se ferme que par `request.cancel`, la fin du tour ou la réconciliation `open_requests`.
- L'état d'attente reste `waitingApproval` (ou `waitingInput`) tant que la décision n'est pas confirmée ; `markQuestion` ne le recalcule pas. Avec une question et une autorisation ouvertes, `waitingApproval` prime.
- `markQuestion` prend un `choice` facultatif, retenu par `ApprovalItem.choice` au passage en `sending`.
- `ApprovalChoice`, `ApprovalMode` et `ApprovalModes` vivent dans `lib/models/timeline.dart` ; `HermesApprovalModes` (appel `config.set`, puis relecture `config.get`, toujours avec `profile`) dans `lib/data/intervention_repository.dart`. Une valeur hors `manual`/`smart`/`off` est traitée comme illisible.
- Codes d'erreur ajoutés : `approval.closed`, `approval.choice` (`session`/`always` refusés avant toute écriture), `approval_mode.unreadable`, `approval_mode.invalid`. Tout échec d'écriture du mode relance une lecture (valeur de Hermes ou « Mode illisible ») : `RpcError` → « Mode inchangé : Hermes a refusé le changement », autre erreur → « Changement non confirmé par Hermes ». Les options de mode sont annoncées cochées (`MergeSemantics` + `checked`).
- La galerie (`lib/ui/gallery.dart`) importe `features/profiles/approval_mode_section.dart` avec des modes fictifs (trois modes + illisible).
- Couverture : `intervention_test.dart` (17 cas d'autorisation, et le test `-32601` passe sur `sudo`), `resync_test.dart` (snapshot clarify/approval), `draft_flow_test.dart` (3 widgets), `approval_mode_test.dart` (15 cas, dont le branchement dans `ProfileSettingsView`), `gallery_test.dart`, `event_mapping_test.dart`, `contracts_test.dart`.

## Spec Change Log

## Review Triage Log

| # | Source | Constat | Verdict | Preuve / route |
|---|--------|---------|---------|----------------|
| 1 | edge, blind | `_approvalDone` confirme une carte encore en `sending` : un `tool.complete` d'un outil parallèle, arrivé entre `markQuestion(sending)` et `respond`, l'affiche « Autorisée » ; si `respond` lève ensuite `transport.offline`, le retour à `open` est ignoré (carte close), rien n'est parti et Hermes attend | medium | `_send` fait `await markQuestion(sending)` avant `respond`, ce qui laisse passer les événements mis en file → patch : exclure `sending`. |
| 2 | blind, edge | « Refuser » suivi d'un `tool.complete` non bloqué d'un autre outil → « Autorisée » ; le `choice` envoyé n'est jamais comparé au résultat | medium | `_approvalDone` ne lit que `result.status` → patch : ne confirmer que si `blocked` correspond au choix (`deny` ⇔ bloqué), sinon laisser la carte telle quelle. |
| 3 | edge | Carte confirmée avec `blocked == null` affichée « Autorisée » | false | Après #2, toute confirmation fixe `blocked` ; un `confirmed` n'existe pas sans `_approvalDone`. |
| 4 | edge | `command` vide → carte d'autorisation vierge | low | Schéma Hermes : la commande est toujours rendue ; non observé → rejeté. |
| 5 | edge, blind | `choice`/`blocked` impossibles à effacer : un choix périmé survit au retour à `open` | low | Le choix n'est pas affiché ; une nouvelle décision le remplace via `markQuestion(sending, choice)` → rejeté. |
| 6 | edge×2, blind | `config.set` réussi puis relecture en échec → « Mode inchangé » et ancien mode affiché | medium | Contredit l'Always (« si la lecture échoue, la section le dit ») → patch : après un échec, relire ; hors `RpcError`, message « non confirmé ». |
| 7 | blind | `config.set` sans effet : retour silencieux à l'ancienne valeur | low | La valeur affichée est bien la valeur relue (Always) ; ajouter un message ajoute une branche → rejeté. |
| 8 | blind | `RpcError` mappé via `toString()`, chemin non testé | low | `RpcError.toString()` renvoie bien `rpc.$code` ; rien ne casse → rejeté. |
| 9 | blind | `approval` malformée → `-32601` au lieu de `-32602` | low | Même verdict qu'en 6.2 (#6) : schéma garanti → rejeté. |
| 10 | blind | Les boutons ignorent `choices` | low | `choices` est précalculé par Hermes et contient toujours `once`/`deny` (contrat) → rejeté. |
| 11 | blind | Section du mode : hors connexion « Mode illisible », pas de relecture au retour | low | Conforme à la matrice (lecture impossible) ; confort → rejeté. |
| 12 | blind | Options du mode exposées en `selected`, pas `checked` | low | Rencontré à chaque usage au lecteur d'écran ; correction directe (`checked: selected`) → patch. |
| 13 | blind | Pas de test « aucun texte de commande dans les journaux » | low | `_log` ne prend qu'un code ; rien à fuir → rejeté. |
| 14 | blind | README : forme de `config.set` et règles de confirmation absentes | low | Documentation ; le comportement est dans le code et les tests → rejeté. |
| 15 | blind | Cas risqués de confirmation non testés (refus + autre outil, `unknown`, `sending`) | medium | Lacune réelle, liée à #1/#2 → patch avec eux. |
| 16 | blind | La carte n'affiche pas la décision envoyée | low | Même verdict qu'en 6.2 (#7) : confort → rejeté. |
| 17 | gap | `blocked`/`choice` peuvent se perdre à la sérialisation sans qu'aucun test échoue (mutation vérifiée) | medium | Pré-vérifié → patch : relire la ligne `conversation_timelines` après une confirmation refusée. |
| 18 | gap | Branchement de `ApprovalModeSection` dans `ProfileSettingsView` jamais testé | medium | Pré-vérifié → patch : test widget de `ProfileSettingsView` avec un `ApprovalModes` factice. |

## Design Notes

Il n'existe aucun événement « autorisation résolue » : `server_requests.py` n'émet que `request.cancel`, et `tools/approval.py` rien vers le client. La seule preuve de prise en compte est donc la fin de l'outil qui attendait l'autorisation. Si deux outils tournent en parallèle, ce peut être la mauvaise carte qui est confirmée. C'est accepté, comme pour `_clarifyDone` en 6.2 (triage #2). Un choix inconnu vaut `once` côté Hermes, et une absence de choix vaut un refus. L'app n'envoie que `once` ou `deny`.

## Verification

**Commands:**
- `fvm flutter analyze` -- expected: aucun problème
- `fvm flutter test` -- expected: tous les tests passent

**Manual checks (if no CLI):**
- Galerie : carte d'autorisation ouverte, envoyée, autorisée, refusée, expirée, en clair et en sombre ; section « Autorisations » dans ses trois modes et en erreur.
