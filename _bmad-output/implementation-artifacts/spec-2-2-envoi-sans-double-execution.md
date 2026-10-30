---
title: 'Story 2.2 — Envoyer ma demande sans risque de double exécution'
type: 'feature'
created: '2026-10-21'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '3cd369681e41669b493b4c966ce6619ebb8ed714'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/recherche-contrat-epic-2.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Le bouton « Envoyer » est désactivé : aucune demande ne part, et un envoi naïf pourrait doubler une exécution après une coupure.

**Approach:** `OutboxRepository` persiste une opération (`OperationKey`, cible, texte exact, révision du brouillon) puis exécute le pipeline nommé `ensureSession` → pièces (vide) → suivi notification (vide) → soumission, via un canal JSON-RPC exposé par `ConnectionRepository` (seul propriétaire de la socket). Résultat incertain → `unknown`, sans renvoi.

## Boundaries & Constraints

**Always:**
- Dialecte legacy du contrat `9e01b44` : `session.create {profile, close_on_disconnect:false, idempotency_key}` puis `prompt.submit {session_id, text}`. Clé d'idempotence = `<ProfileKey>/<DraftKey>`, persistée avant l'appel. `stored_session_id` persisté sur le brouillon avant la soumission ; le `session_id` runtime reste en mémoire (par époque de socket) et se récupère par `session.resume {session_id: stored, profile}` s'il manque ou si Hermes répond `4001`.
- `ensureSession(DraftKey)` sérialisé par brouillon : deux appels concurrents → une seule `session.create`.
- États d'opération : `preparing`, `sending`, `accepted`, `unknown`, `failed`. Réponse `streaming|queued|steered|redirected` → `accepted` (+ `user_row_id` si fourni). Erreur JSON-RPC reçue → `failed` (refus certain, renvoi manuel permis). Timeout, socket perdue après écriture de la trame → `unknown`. Socket absente avant écriture → `failed` retryable.
- Aucune répétition automatique. Après `unknown`, le brouillon reste intact, un message explique de vérifier la conversation ; un nouvel envoi n'est qu'une action explicite.
- Acceptée : vider le brouillon seulement si sa révision égale celle de l'opération. Rapprochement par `user_row_id` / identifiants, jamais par texte.
- Un seul envoi à la fois par session : bouton désactivé pendant `preparing|sending` et pendant un tour en cours (`message.start` → `message.complete` sur le `session_id` runtime) ; la saisie reste éditable et enregistrée.
- Capacité `conversation` (requise) : présente sur `gateway.ready` sans `session_authority:true` ; absente sinon → envoi désactivé avec explication. Connexion non `connecté` → envoi désactivé avec libellé.
- Après acceptation, l'écran reste sur `/draft/<DraftKey>` (fil complet : 2.3) ; l'accueil suivant ouvre un nouveau brouillon sans session.

**Never:**
- Aucun renvoi automatique de `prompt.submit`, aucune comparaison de texte avec le serveur, aucun texte de conversation ni secret dans logs/erreurs.
- Pas de projection de fil ni d'historique (2.3, 2.6), pas de reprise par `events.since` (2.4), pas de dialecte canonique.
- Ne pas modifier les migrations existantes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Premier envoi | Brouillon sans session | Opération persistée, puis `session.create`, `stored_session_id` persisté, puis `prompt.submit` ; `accepted` | N/A |
| Envois concurrents | 2 `ensureSession` simultanés | Une seule `session.create` | N/A |
| Réponse perdue | Socket coupée après trame `prompt.submit` | `unknown`, brouillon intact, aucun 2e `prompt.submit` | Message « résultat incertain » |
| Refus Hermes | Erreur `4009`/`4090`/`5035` | `failed`, brouillon intact | Message simple par code |
| Runtime perdu | `4001` sur `prompt.submit` | `session.resume` puis un seul nouveau `prompt.submit` | Si échec : `failed` |
| Saisie pendant envoi | Texte modifié pendant `sending` | Acceptation : saisie récente conservée | N/A |
| Dialecte canonique | `session_authority:true` | Envoi désactivé, capacité absente affichée | Aucun appel |

</frozen-after-approval>

## Code Map

- `lib/data/connection_repository.dart` -- socket unique, `_epoch`, `_lostSocket`, gestion `gateway.ready` (l. ~280-350) : ajouter le canal (`call(method, params, timeout)` avec ids `r<n>`, table des appels en attente échouée en incertain à la perte de socket ; flux `events` des trames `method:"event"` avec `session_id`, `type`, `payload`, `seq`, époque).
- `lib/data/hermes_adapter.dart` -- seul à connaître les formats Hermes : y placer la traduction trames ↔ modèles et codes d'erreur.
- `lib/data/outbox_repository.dart`, `lib/data/storage/migrations.dart` -- brouillons (story 2.1) ; migration 4 : colonnes brouillon (`revision`, `stored_session_id`, `idempotency_key`), table `outbox_operations`, index unique partiel « nouveau brouillon » `WHERE stored_session_id IS NULL` à la place de l'ancien.
- `lib/models/draft.dart`, `lib/models/app_error.dart` -- contrat `OutboxGateway` à étendre (`send`, flux d'état d'envoi par brouillon), enveloppe d'erreur.
- `lib/features/conversation/*`, `lib/ui/components/composer.dart`, `lib/ui/content.dart` -- activer `onSend`, afficher l'état d'envoi et les raisons de désactivation.
- `contracts/openrpc.json`, `contracts/event-mapping.json`, `contracts/fixtures/` -- schémas et fixtures synthétiques à compléter (`session.create`, `prompt.submit`, erreurs, `message.start/complete`).
- `test/support/connection_fakes.dart` (`FakeSocket`, `Harness`) -- fakes réseau à étendre pour scripter les réponses RPC.

## Tasks & Acceptance

**Execution:**
- [x] `lib/data/connection_repository.dart`, `lib/data/hermes_adapter.dart` -- canal RPC + flux d'événements + capacité `conversation` -- propriétaire unique de la socket.
- [x] `lib/data/storage/migrations.dart` -- migration 4 -- ajout seul.
- [x] `lib/models/draft.dart`, `lib/data/outbox_repository.dart` -- opérations, `ensureSession`, pipeline nommé, états, révision -- AD-5.
- [x] `lib/features/conversation/*`, `lib/ui/*` -- envoi actif, états et raisons accessibles (libellés, pas seulement couleur).
- [x] `contracts/fixtures/*`, `test/*` -- matrice I/O complète, migration 3→4, concurrence `ensureSession`, ordre persistance → appel vérifié.

**Acceptance Criteria:**
- Given un brouillon prêt et la connexion `connecté`, when Alanc touche « Envoyer », then l'opération est en base avant toute trame et les étapes s'exécutent dans l'ordre nommé.
- Given un tour en cours, when Alanc tape, then le texte est enregistré mais « Envoyer » reste désactivé avec sa raison annoncée.
- Given TalkBack et texte 200 %, when l'état d'envoi change, then il est annoncé (région live) et lisible sans débordement.

## Implementation Notes

## Spec Change Log

## Review Triage Log

| # | Source | Constat | Verdict | Preuve / route |
|---|--------|---------|---------|----------------|
| 1 | blind, edge | État d'envoi en mémoire : après kill pendant `sending` ou après `unknown`, aucun avertissement, renvoi en double possible | high | `_status` n'est jamais rechargé depuis `outbox_operations`. patch |
| 2 | blind, edge | `turnActive` : session reprise `running:true` non bloquée ; tour sans `message.complete` bloqué | medium | `resumed()` ignore `running` ; seule `message.complete` termine. patch |
| 3 | edge | Génération de socket lue après l'appel dans `_ensure` | low | Reconnexion pendant l'appel → id runtime périmé (rattrapé par 4001). Correction d'une ligne. patch |
| 4 | blind | `return` au lieu de `continue` dans `_onEvent` | low | À vérifier et corriger directement. patch |
| 5 | blind, edge | Statut résiduel masque la raison de blocage | medium | `status` remplace `disabledReason` dans le composer. patch |
| 6 | blind, gap | `Content.sendOffline` inutilisé | low | Suppression directe. patch |
| 7 | gap | Câblage `gateway` du bootstrap non vérifié | medium | Paramètre optionnel : retrait silencieux possible. patch (paramètre requis) |
| 8 | gap | Reconnexion, réponses mal formées, `socket.send` qui lève : non testés | medium | Gaps vérifiés. patch |
| 9 | blind | Renvoi explicite après `unknown` possible | false | Choix de la spec (action explicite) ; la reprise 2.4 rapprochera. rejeté |
| 10 | blind, edge | Détection de capacité par inférence négative | false | Règle de la spec ; seul `session_authority:true` est reconnu comme canonique. rejeté |
| 11 | blind | `idempotency_key` écrite non relue ; `_sentText` résiduel | low | Valeur déterministe recalculée ; `_sentText` réécrit à chaque envoi. rejeté |
| 12 | blind | Croissance non bornée des opérations et brouillons | low | Volumes personnels faibles. rejeté |
| 13 | edge | Réponse tardive après timeout ignorée | low | Reste `unknown` sans renvoi : conforme ; rapprochement en 2.4. defer |
| 14 | edge | Accueil rouvre un brouillon de conversation non vide | low | Choix conservateur tant que l'historique (2.6) n'existe pas. defer |
| 15 | edge | `stored_session_id` mis à jour sur 0 ligne ; `dispose` pendant envoi ; écriture sur socket en fermeture | false | `ensureSession` sérialisé, brouillon existant ; erreurs avalées sans perte. rejeté |
| 16 | blind | RPC codes 4090/5035 non testés, tests à délais courts | low | Messages par code ; risque de fragilité CI non observé (114 verts). rejeté |

## Verification

**Commands:**
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat analyze` -- expected: aucun problème
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat test` -- expected: tous verts
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat build apk --debug` -- expected: build réussi
