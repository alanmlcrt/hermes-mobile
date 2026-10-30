---
title: 'Story 5.2 - Faire tourner l''observateur de fins de travail'
type: 'feature'
created: '2026-10-27'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '838bdacaa38263d74d7c980aed16be147a73925e'
context:
  - '{project-root}/contracts/notification-tracking.json'
  - '{project-root}/contracts/notification-deployment.json'
  - '{project-root}/contracts/event-mapping.json'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Le contrat de suivi et le déploiement sont figés, mais aucun service ne détecte les fins de travail Hermes ni ne tient l'outbox durable ; sans lui, aucune notification ne peut partir même téléphone éteint.

**Approche :** Construire `server/notifier/`, add-on Home Assistant autonome : endpoints authentifiés du contrat, registre et outbox dans `/data`, observation en lecture seule de Hermes par le mapping partagé, rattrapage après redémarrage, déduplication et santé. Aucun FCM réel ; l'intégration reste en dry-run.

## Décisions validées par Alanc (2026-10-27)

- **Langage :** Python 3.13 + SQLite, dépendances épinglées, mapping partagé relu depuis les contrats.
- **Déploiement :** 5.2 rend l'add-on déployable et prouve localement ; l'installation sur Home Assistant et l'essai réel restent en 5.5.
- **Bearer :** hash SHA-256 salé et sel dans les options, CLI de génération ; aucun token en clair dans le conteneur.
- **Outbox :** dispatcher dry-run inclus ; aucun push FCM réel avant 5.3.

## Boundaries & Constraints

**Always:** Le mapping `contracts/event-mapping.json` est la seule source des terminaux ; un statut absent ou inconnu ne notifie jamais. Le terminal est rapproché par `session_id` + `persisted_turn.user_row_id` ; `executionId` = `base64url(session_id + ':' + user_row_id)`. Le rattrapage reprend par `session.events.since` et le curseur `last_seen` ; `truncated` ou un changement d'`epoch` impose `session.history`, et une fin indémontrable reste inconnue. Le premier terminal gagne ; la déduplication est `(subscriptionId, executionId, terminal)` et une exécution ne garde qu'une entrée. Lecture seule : seules les méthodes et routes autorisées par `notification-deployment.json` ; ni soumission, ni arrêt, ni création, ni titre, ni pièce jointe, ni base privée. Endpoints, statuts, erreurs bornées, bearer, santé et journaux suivent le contrat. `/data` est le seul stockage persistant ; la purge borne chaque état. Environnements isolés ; `personal` refuse de démarrer sans Firebase/FCM et G3 reste ouverte.

**Never:** Envoyer un vrai push FCM (5.3), modifier `lib/`, les contrats canoniques ou le mobile, publier un port hôte, exposer hors tailnet, stocker un token en clair, journaliser un payload, un contenu, un identifiant ou un token, promettre « exactement une fois », lire une base Hermes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Enregistrement | bearer + `subscriptionId` opaque + token | 200/201, état `registered`, token chiffré | 400 si format invalide, 401 sans bearer |
| Enregistrement doublon | même `subscriptionId` | 200, token mis à jour | jamais 409 |
| Attache | abonnement `registered` + session/profil/exécution | 202, watcher démarré | 404 inconnu, 410 expiré/révoqué, 400 conflit d'exécution |
| Terminal suivi | `message.complete` avec `persisted_turn.user_row_id` | une entrée outbox `pending`, dédup écrite | doublon ignoré, ancien terminal ignoré |
| Terminaux concurrents | deux terminaux pour une exécution | premier gagne | tardif ignoré |
| Erreur de session | `error` sans identité | `failed` si une seule exécution attachée non pourvue d'outbox | 0 ou >1 : ignoré |
| Redémarrage | curseur `last_seen` | rejeu depuis le curseur | `truncated`/epoch : historique, pas de faux succès |
| Rétention | TTL dépassé | suppression + compteur | aucune entrée éternelle |
| Santé | bearer valide | état, raisons avec seuil, compteurs, version, `checkedAt` | 401 sans bearer, aucun identifiant |

</frozen-after-approval>

## Code Map

- `contracts/notification-tracking.json` — endpoints l.302-419, erreurs l.442-467, journaux l.468-490, retries l.491-533, rattrapage l.535-565, rétention l.557-566, santé l.567-631, payload l.226-301, dédup l.205-225. Source des valeurs, aucun doublon en code.
- `contracts/notification-deployment.json` — runtime l.242-300, auth l.302-324, accès Hermes l.325-359, FCM/dry-run l.360-419, environnements l.476-509. Allowlist RPC/REST et packaging.
- `contracts/event-mapping.json` l.47-65 — `message.complete` (`statusMap`) et `error` (`workState`), seuls terminaux.
- `contracts/openrpc.json` — schémas `SessionEventsSinceParams/Result`, `SessionResumeParams/Result`, `SessionHistoryParams/Result`, `MessageCompletePayload`, `PersistedTurn`, `PromptSubmitResult`, `TranscriptMessage`.
- `contracts/fixtures/message-complete.json`, `message-complete-interrupted.json`, `error.json` — fixtures partagées ; réutiliser, ne pas modifier.
- `lib/data/hermes_adapter.dart` l.240-346 — login `password-login`, refresh, `/api/profiles`, `/api/auth/ws-ticket`, sous-protocoles WS ; reproduire le dialecte, ne pas importer.
- `lib/data/connection_repository.dart` l.305-392 — `gateway.ready`, `replay_epoch`, envoi `gateway.capabilities` ; même séquence.
- `lib/data/conversation_repository.dart` l.442-556 — ordre `session.resume` → `session.events.since` → `session.history` si rejeu non sûr.
- `lib/data/event_mapping.dart` l.43-56 — sémantique du mapping, statut inconnu jamais présumé réussi.
- `lib/models/timeline.dart` l.8 — `WorkState.succeeded/failed/stopped` = issues notifiables.
- `test/notification_contract_test.dart` — invariants 5.1 à ne pas casser ; `contracts/` non modifié.
- `_bmad-output/implementation-artifacts/spec-5-1-contrat-suivi-deploiement-observateur.md` l.76-155 — AC 5.2, token, corrélation, `error`, rattrapage, rétention, santé.
- `.github/workflows/ci.yml` l.40-47 — modèle du job Python ; ajouter les tests notifier.
- `server/notifier/` — nouveau paquet, tests, add-on `config.yaml`, `Dockerfile`, `run.sh`, `vendor/contracts/` généré.
- À ne pas modifier : `lib/`, `test/` Dart, `contracts/` canoniques, `pubspec.yaml`, Android/iOS.

## Tasks & Acceptance

**Execution:**
- [x] `server/notifier/sync_contracts.py` + `server/notifier/vendor/contracts/` — copie byte-identique de `event-mapping.json`, `notification-tracking.json` et `notification-deployment.json`, mode `--check` — image autonome sans dérive.
- [x] `server/notifier/hermes_notifier/contracts.py` — charger/valider les contrats, résoudre un terminal par `statusMap`/`workState` sans succès par défaut, exposer TTL, seuils et libellés — source unique.
- [x] `server/notifier/hermes_notifier/config.py` + `credential.py` — options/env, isolation des environnements, refus de `personal` sans FCM, hash salé et comparaison constante, CLI de génération — auth hash-only.
- [x] `server/notifier/hermes_notifier/store.py` + `retention.py` — SQLite `/data`, registre, attachement, outbox, dédup, curseurs, compteurs, migrations, TTL et purge — durabilité et dédup.
- [x] `server/notifier/hermes_notifier/api.py` + `health.py` + `logs.py` — endpoints exacts, bearer, erreurs bornées, rate limit, santé à seuils, journaux `domaine.code` — conformité.
- [x] `server/notifier/hermes_notifier/hermes/rpc.py` — login/refresh/ticket WS, `gateway.ready`, allowlist RPC, JSON-RPC, timeouts et reconnexion — lecture seule.
- [x] `server/notifier/hermes_notifier/hermes/observer.py` — `session.resume` (`omit_messages`, repli), `events.since`, curseur, `truncated`/epoch, matching terminal, règle `error` unique, écriture outbox — cœur de la story.
- [x] `server/notifier/hermes_notifier/outbox.py` + `payload.py` — dispatcher dry-run, message `notification + data` dérivé du contrat, retries bornés, abandon à 48 h, compteurs — prouve l’outbox sans FCM réel.
- [x] `server/notifier/hermes_notifier/service.py` + `__main__.py` — orchestration, reprise au démarrage, SIGTERM, réveil sur attache — runtime.
- [x] `server/notifier/config.yaml`, `server/notifier/Dockerfile`, `server/notifier/run.sh`, `server/notifier/requirements.txt`, `server/notifier/requirements-dev.txt`, `repository.yaml` — add-on HA sans port hôte, watchdog TCP 8787, `/data`, image Python épinglée — déployable.
- [x] `server/notifier/tests/` — faux Hermes HTTP+WS, fixtures avec `persisted_turn`, tests mapping/store/api/observer/rétention/redaction/packaging/dérive — preuves.
- [x] `server/notifier/README.md` + `DOCS.md` — installation, options, génération du bearer, Tailscale Serve, dry-run, limites — opérabilité.
- [x] `.github/workflows/ci.yml` + `.gitignore` — tests notifier et `--check` en CI, artefacts Python ignorés — non-régression.
- [x] `_bmad-output/implementation-artifacts/story-5-2-verification/implementation-report.md` — changements, décisions, commandes, résultats, limites — preuve.

**Acceptance Criteria:**
- Given un abonnement enregistré et attaché et un terminal correspondant au mapping partagé, when l’observateur le traite, then une seule entrée outbox est créée pour `(subscriptionId, executionId)` avec le terminal attendu, la déduplication est écrite, et les compteurs la reflètent (`outboxPending` tant qu’elle est en attente, puis `delivered`).
- Given un redémarrage, when l’observateur reprend, then `session.events.since` repart de `last_seen` ; `truncated` ou un changement d’epoch déclenche `session.history` et aucun succès n’est notifié sans preuve terminale.
- Given des terminaux doublons, tardifs ou antérieurs à l’exécution, when ils sont traités, then les doublons et anciens terminaux sont ignorés et une exécution garde son premier terminal.
- Given un `error` de session avec zéro ou plus d’une exécution attachée non pourvue d’outbox, when il est traité, then aucune notification n’est mise en file ; avec exactement une, une entrée `failed` l’est.
- Given le packaging de l’add-on, when il est inspecté, then aucun port hôte n’est publié, le watchdog sonde 8787, `/data` est le seul chemin persistant et `personal` refuse de démarrer sans Firebase.
- Given une requête de santé authentifiée, when l’observateur est sain ou dégradé, then la réponse porte état, raisons avec seuil, compteurs, version et `checkedAt`, sans identifiant ni contenu ; sans bearer, 401.
- Given un scénario complet, when les journaux sont scannés, then aucun `subscriptionId`, `executionId`, `sessionId`, profil, token ou contenu n’apparaît.
- Given le dépôt, when `python -m unittest`, `sync_contracts.py --check`, `flutter analyze` et `flutter test` s’exécutent, then tout passe.

## Implementation Notes

## Spec Change Log

## Review Triage Log

Trois couches : aveugle (B1–B23), cas limites (E1–E16), vérification (V1–V9, X1–X2).
« Corrigé » signifie que le code, les tests ou le packaging ne produisent plus le
résultat décrit ; « documenté » renvoie à `DOCS.md`/`README.md` ; « reporté »
renvoie à `deferred-work.md`.

| # | Constat | Verdict | Preuve | Route |
|---|---|---|---|---|
| B1 | Troncature/epoch : les terminaux de la fenêtre rejouée sont perdus | corrigé | `_catch_up` recharge `session.history` puis traite les `events` présents ; `test_troncature_recharge_l_historique_et_exploite_le_terminal` et `test_changement_d_epoch_recharge_l_historique_et_exploite_le_terminal` exigent l'entrée outbox. | patch |
| B2 | `maxReplayEvents` n'est jamais lu | corrigé | `max_replay_events` borne chaque lot ; au-delà, le rejeu reprend au dernier `seq` traité (`observer.py` l.414-507) ; `test_rejeu_borne_par_max_replay_events` couvre 1005 événements. | patch |
| B3 | `_resume` traite toute erreur JSON-RPC comme une session morte | corrigé | Seul `-32004` produit `_SessionGone` ; les autres erreurs passent par `_rpc_error` et restent retryables (`observer.py` l.375-387). | patch |
| B4 | Aucune veille reconstruite après redémarrage si l'outbox est en attente | corrigé | `_reconcile` ajoute aussi `watch_executions()` (`observer.py` l.213-219) ; `test_veille_reconstruite_avec_outbox_en_attente`. | patch |
| B5 | Le thread du dispatcher peut mourir sur `_delay()` | corrigé | `_delay()` est appelé dans le `try` ; une erreur SQLite planifie un balayage et alimente `storage-error` (`outbox.py` l.125-147). | patch |
| B6 | `Service` ne redémarre pas et `api.stop()` peut bloquer | corrigé | `Service.start()` reconstruit les composants et efface `_stop` ; `api.stop()` n'appelle `shutdown()` que si le thread vit (`api.py` l.129-141) ; `test_stop_puis_start_reconstruit_les_composants`, `test_run_s_arrete_sur_stop`. | patch |
| B7 | La sonde de santé confond trafic d'événements et vivacité | documenté | La sonde reste globale ; un `next_event` sans événement compte comme succès (`observer.py` l.547-552) et DOCS §5.1 expose la limite (une veille bloquée peut être masquée). | docs |
| B8 | `storage-error` ne se lève jamais | corrigé | `record_storage_success()` efface l'erreur et `snapshot()` l'appelle après une lecture réussie (`health.py`) ; `test_erreur_stockage_puis_retour_a_ok`. | patch |
| B9 | Les erreurs de stockage fuient des codes hors contrat | corrigé | `error_body()` replie tout code inconnu sur `unavailable`/`internal` (`api.py` l.143-156) ; `test_erreur_stockage_devient_unavailable` ; DOCS §5.0. | patch |
| B10 | Les défauts de l'add-on violent son schéma ; sel trop court accepté | corrigé | Le schéma accepte une valeur vide par défaut et `_validate_hash` borne le sel à 64-128 caractères (`config.py` l.222-231) ; `test_schema_accepte_les_defauts_vides`, `test_hash_et_sel_valides`. | patch |
| B11 | Un token légal de 4096 octets rend tout payload indélivrable | corrigé | Le budget `maxBytes` est mesuré hors token FCM (routage) et le token reste borné par l'API (`payload.py` l.89-97) ; `test_payload_contractuel_sans_identite`. | patch |
| B12 | Un placeholder inconnu produit un `KeyError` brut | corrigé | Les erreurs de `str.format` deviennent `PayloadInvalid("payload.template")` (`payload.py` l.74-79). | patch |
| B13 | Aucun chemin supporté pour `fcm_service_account` | reporté | `/data` reste le seul volume en 5.2 ; DOCS §4 et §14 expliquent le refus ; entrée ajoutée à `deferred-work.md` pour 5.3/5.5. | deferred |
| B14 | DOCS sous-estime les retries | documenté | DOCS §6 décrit 5 backoffs puis 300 s jusqu'à 48 h et la politique `afterMaxAttempts`. | docs |
| B15 | DOCS sans table des erreurs ni catalogue de journaux | documenté | DOCS §5.0 liste les sept codes HTTP et §9 le catalogue complet des codes émis. | docs |
| B16 | DOCS sans procédures opérateur | documenté | DOCS §3.3, §5.5-5.7 couvrent rotation bearer, 429/horloge, rotation FCM, réutilisation d'identifiant et exemple `executionId`. | docs |
| B17 | La réserve de lecture seule n'est pas exposée | documenté | DOCS §1 et §14 exposent `session.resume` et son impact (reconstruction possible d'une session locale Hermes). | docs |
| B18 | CI sans porte de build pour l'image | corrigé | CI construit l'image, exécute `--version`, charge les contrats et vérifie `/run.sh` exécutable ; lint/typage/coverage restent hors périmètre 5.2. | patch |
| B19 | Les chemins d'échec du CLI et du redémarrage ne sont pas testés | corrigé | `test_service.py` couvre `--version`, `--check`, `run()`/stop et stop→start ; `test_sync_detecte_derive_et_absence` couvre dérive et absence. | patch |
| B20 | `storage.pruned` compte les curseurs restants | corrigé | `_delete_orphan_cursors()` renvoie le `rowcount` supprimé (`store.py` l.967-971) ; `PruneResult.total()` ne gonfle plus. | patch |
| B21 | Les tombstones expirent avant le comportement documenté | documenté | DOCS §5.4 et §8 alignent le tombstone sur `expiredTtlSeconds` (1 jour), puis `404` ; `store.prune` purge la ligne. | docs |
| B22 | 401/429 invisibles dans `api.refused` ; pas de `WWW-Authenticate` | corrigé | Les deux refus journalisent `api.refused` et le 401 porte `WWW-Authenticate: Bearer` (`api.py` l.268-298). | patch |
| B23 | Le test de rédaction contourne les regex | corrigé | Le test n'ajoute plus `Bearer abc.def.ghi` aux valeurs connues ; seules les expressions régulières doivent le masquer (`test_logs.py`). | patch |
| E1 | Ré-attache d'une exécution expirée sans veille | corrigé | `Store.attach` réactive une exécution `expired` de même cible et remet l'abonnement `attached` (`store.py` l.521-534) ; `test_reattach_reactivates_expired_execution`. | patch |
| E2 | Deux abonnements ne peuvent pas suivre la même ligne | reporté | Décision 5.2 : une exécution par abonnement ; second attachement `400`, documenté (DOCS §5.3, README) et reporté dans `deferred-work.md`. | deferred |
| E3 | Un watcher oisif dégrade la santé au bout de 60 s | corrigé | `next_event` sans événement appelle `record_hermes_success()` (`observer.py` l.547-552). | patch |
| E4 | Une erreur SQLite brute tue le thread observateur | corrigé | `active_executions`/`watch_executions` sont enveloppés, journalisent `storage.error` et la boucle continue (`observer.py` l.195-202, 694-712). | patch |
| E5 | `next_outbox_attempt_at` hors du `try` tue le dispatcher | corrigé | Même correctif que B5 : `_delay()` est dans le `try` et retombe sur le balayage (`outbox.py` l.125-147). | patch |
| E6 | Une erreur transitoire de `events.since` fait perdre les terminaux | corrigé | Les timeouts/5xx sont retryés ; seules les méthodes absentes (`-32601`/`hermes.not_found`) replient sur `session.history` (`observer.py` l.424-437) ; `test_since_absent_replie_sur_historique`, `test_since_non_retryable_expire`. | patch |
| E7 | Une erreur non retryable boucle indéfiniment | corrigé | Les échecs non retryables sont bornés puis `_expire_key` (`observer.py` l.274-281) ; `test_session_disparue_expire_apres_max_attempts`. | patch |
| E8 | Un port d'origine non numérique passe `--check` | corrigé | `_validate_origin` force `parsed.port` et convertit `ValueError` en `config.origin_invalid` (`config.py` l.207-217) ; `test_origine_stricte`. | patch |
| E9 | Un hash non ASCII fait planter la vérification CLI | corrigé | `verify()` refuse un hash non ASCII avant `hmac.compare_digest` (`credential.py` l.53-64). | patch |
| E10 | Un template invalide est retenté jusqu'à 48 h | corrigé | Même correctif que B12 : `PayloadInvalid("payload.template")` immédiat. | patch |
| E11 | `Content-Length` interdit sur une réponse 204 | corrigé | `_send` n'émet `Content-Length` que hors 204/304 (`api.py` l.380-385) ; les révocations restent sans corps. | patch |
| E12 | Une déconnexion client produit une seconde réponse 500 | corrigé | `_send` absorbe `OSError`, ferme la connexion et ne réessaie pas (`api.py` l.391-396). | patch |
| E13 | Les enregistrements dry-run croissent sans borne | corrigé | `DryRunTransport._records` est un `deque(maxlen=1000)` (`outbox.py` l.66). | patch |
| E14 | La purge gonfle `total()` avec les curseurs conservés | corrigé | Même correctif que B20 : seul le `rowcount` supprimé est compté. | patch |
| E15 | Un terminal antérieur à l'attache de la même ligne serait notifié | rejeté | Le rapprochement exige l'`executionId` dérivé de `sessionId + user_row_id` et ignore les autres lignes ; Hermes ne documente pas de rejeu antérieur à l'attache dans `SessionEventsSinceParams`. Aucun changement 5.2 ; à rouvrir si le dialecte réel le démontre. | none |
| E16 | La sonde santé renvoie 500 si SQLite échoue | corrigé | `snapshot()` capture `StorageError`, renvoie `degraded`/`storage-error` et se lève à la lecture suivante (`health.py`) ; `test_erreur_stockage_puis_retour_a_ok`, `test_api` santé. | patch |
| V1 | `run()`/`main()`/`__main__` jamais exécutés | corrigé | `test_service.py` couvre `--version`, `--check`, `run()`/stop et stop→start. | patch |
| V2 | `/v1/health` ne reflète pas le `HealthState` partagé | corrigé | `test_sante_reflete_l_observateur` attache une veille, force l'ancienneté et obtient `degraded`/`hermes-unreachable` via l'API du service. | patch |
| V3 | La purge au démarrage n'est jamais assertée | corrigé | `test_demarrage_purge_les_etats_perimes` sème un abonnement expiré et vérifie `expired` après `Service.start()`. | patch |
| V4 | La disparition de session n'est pas testée | corrigé | `test_session_disparue_expire_apres_max_attempts` couvre `_SessionGone` → `_expire_key`. | patch |
| V5 | Le cas epoch absent/manquant n'est pas testé | corrigé | `test_curseur_sans_epoch_recharge_l_historique` et `test_epoch_absent_declenche_l_historique` forcent le refetch. | patch |
| V6 | Le repli sur historique après échec de `events.since` n'est pas testé | corrigé | `test_since_absent_replie_sur_historique` et `test_since_non_retryable_expire` couvrent le repli et la borne. | patch |
| V7 | Le build et le démarrage Docker ne sont pas vérifiés | corrigé | CI : `docker build`, `--version`, `Contracts.load()`, `/run.sh` exécutable ; `test_ci_build_et_smoke_docker` verrouille la présence des étapes. | patch |
| V8 | Port du watchdog et port par défaut non reliés | corrigé | `test_watchdog_et_port_par_defaut` parse 8787 depuis `config.yaml` et compare `Config.load(...).port`. | patch |
| V9 | Les routes et codes n'adoptent pas les accesseurs du contrat | corrigé | `test_api_suit_le_contrat` construit les requêtes avec `Contracts.endpoint()` et valide les codes via `Contracts.error_codes` ; les routes restent littérales en production. | patch |
| X1 | `maxReplayEvents` sans lecteur | corrigé | Doublon de B2 ; borne implémentée et testée par `test_rejeu_borne_par_max_replay_events`. | patch |
| X2 | `afterMaxAttempts` et `dropAfterSeconds` sans lecteur | corrigé | `dropAfterSeconds` pilote l'abandon (`outbox.py`) et `afterMaxAttempts` choisit `keep-in-outbox`/`drop` ; `test_delai_abandon_vient_du_contrat`, `test_politique_drop_apres_max_attempts`. | patch |

**Routage :** `patch` — 47 constats traités dans le code, les tests, le
packaging ou la documentation ; `B13` et `E2` sont reportés dans
`deferred-work.md` ; `E15` est rejeté avec justification. Aucun `bad_spec` ni
`intent_gap` retenu ; `review_loop_iteration` reste à `0`.

## Design Notes

- `executionId` est recalculé à l’identique du mobile : `base64url(session_id + ':' + user_row_id)` sans padding. `submission_id` ne remplace jamais `user_row_id`.
- Un seul WebSocket par couple `(origine, profil, session)` ; le curseur `{connection, profile, sessionId, last_seen, epoch}` est persisté. Après un lot sans troncature, le curseur avance à `latest_seq` ; si un lot atteint `maxReplayEvents`, il s’arrête au dernier `seq` réellement traité et le rejeu reprend là.
- Sur `truncated`, `cursor_ahead`, epoch changé ou epoch absent : `session.history` est rechargé, les `events` présents dans la réponse restent une preuve terminale et sont traités ; le curseur ne saute au `latest_seq` qu’après ce traitement, ou reprend au dernier `seq` traité si la borne `maxReplayEvents` est atteinte. Aucun succès n’est fabriqué sans terminal correspondant.
- L’outbox est indexée par `(subscriptionId, executionId)` ; la dédup `(subscriptionId, executionId, terminal)` enregistre les répétitions. Les états sont `pending`, `delivered`, `dropped`. L’abandon est piloté par `retries.dropAfterSeconds` (autoritaire, 48 h) ; `afterMaxAttempts` choisit `keep-in-outbox` ou `drop`.
- Au redémarrage, `_reconcile` ouvre une veille pour `watch_executions()` même si l’outbox est encore `pending`, afin de voir les doublons et terminaux tardifs avant la livraison.
- La santé est globale : elle est dégradée si au moins une veille active n’a pas eu de succès Hermes depuis 60 s, si l’outbox dépasse 50 entrées, ou après une erreur de stockage ; une erreur de stockage est levée à la lecture suivante réussie. `next_event` sans événement compte comme succès ; `fcm-unavailable` est ignoré en dry-run et pour `integration`. Une veille bloquée peut être masquée par une autre veille saine.
- Le token FCM est chiffré au repos avec une clé de `/data` en 0600 ; le bearer n’est jamais stocké en clair, seulement son hash salé.
- Le contrat 5.1 consigne `watchdog: true` ; la forme HA actuelle est une URL. `config.yaml` porte `tcp://[HOST]:[PORT:8787]`, même intention sans port hôte publié.
- Les valeurs `proposed` du contrat de déploiement (port 8787, 443, TLS Tailscale) ne sont pas déclarées validées par 5.2 ; seule l’installation réelle de 5.5 les confirme.
- 5.1 est en revue ; si sa revue change le contrat de suivi, 5.2 est re-vérifiée avant clôture.

## Verification

**Commands:**
- `python server/notifier/sync_contracts.py --check` — `contrats vendorises identiques`.
- `python -m unittest discover -s server/notifier/tests -t server/notifier` — 121 tests, `OK` (2026-10-27).
- `python -m compileall -q server/notifier/hermes_notifier` — aucune erreur de syntaxe.
- `python -m hermes_notifier --version` — `0.1.0` ; `--check` couvert par `test_service.py::test_check_affiche_un_resume_sans_secret`.
- `flutter analyze --no-pub` — `No issues found!` (122,7 s).
- `flutter test --no-pub` — 466 réussis, 17 ignorés, `All tests passed!`.
- `docker build -f server/notifier/Dockerfile server/notifier` — non exécuté localement (daemon `dockerDesktopLinuxEngine` arrêté) ; la CI construit l’image, exécute `python -m hermes_notifier --version`, charge `Contracts.load()` et vérifie `/run.sh` exécutable.

**Manual checks (if no CLI):**
- `server/notifier/config.yaml` : pas de `ports`, watchdog TCP 8787, architectures `amd64`/`aarch64`, version alignée.
- `test_api.py::test_api_suit_le_contrat` vérifie routes, statuts et codes via `Contracts.endpoint()` et `Contracts.error_codes`.
- `test_packaging.py::test_watchdog_et_port_par_defaut` aligne le port du watchdog et `Config.port`.
- Environnement `personal` : démarrage refusé et journalisé sans secret tant que Firebase/FCM manque.
- Tailscale Serve n’est pas appliqué en 5.2 ; la procédure est documentée pour l’essai réel de 5.5.
- Aucun fichier de `lib/`, `test/` Dart ou `contracts/` canonique n’a été modifié.
