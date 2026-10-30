# Rapport d'implémentation — Story 5.2

**Story :** Faire tourner l'observateur de fins de travail
**Spec :** `_bmad-output/implementation-artifacts/spec-5-2-faire-tourner-observateur-fins-travail.md`
**Branche :** `epic/5-notifications`
**Baseline :** `838bdacaa38263d74d7c980aed16be147a73925e`
**Date :** 2026-10-27
**Statut :** implémentation terminée, revue traitée (50 constats), vérification locale complète

## 1. Résultat

`server/notifier/` livre un add-on Home Assistant autonome qui :

- observe les fins de travail Hermes en lecture seule, par le mapping partagé ;
- persiste dans `/data` le registre, les attachements, l'outbox, la
  déduplication, les curseurs et les compteurs ;
- reprend après redémarrage avec `session.events.since` et `last_seen` ;
- traite `truncated`, changement d'`epoch` et curseur en avance par un
  `session.history`, sans jamais fabriquer de succès ;
- expose `GET /v1/health` authentifié, avec état, raisons seuillées, compteurs,
  version et `checkedAt` ;
- fonctionne en dry-run : le dispatcher valide le message puis marque l'entrée
  `delivered`, sans aucun envoi FCM réel.

Aucun fichier de `lib/`, `test/` Dart, `contracts/` canonique, `pubspec.yaml`,
Android ou iOS n'a été modifié.

## 2. Fichiers livrés

### Service

| Fichier | Rôle |
|---|---|
| `hermes_notifier/contracts.py` | Chargement/validation des trois contrats, résolution des terminaux, TTL et seuils |
| `hermes_notifier/config.py` | Options HA et variables d'environnement, isolation des environnements, refus de `personal` |
| `hermes_notifier/credential.py` | Bearer hash salé, comparaison constante, CLI de génération/vérification, chiffrement du token FCM |
| `hermes_notifier/store.py` | SQLite `/data`, schéma, registre, attachements, outbox, dédup, curseurs, compteurs, migrations |
| `hermes_notifier/retention.py` | Purge des abonnements, déduplications et entrées outbox |
| `hermes_notifier/api.py` | Quatre routes du contrat, bearer, erreurs bornées, rate limit |
| `hermes_notifier/health.py` | Santé dérivée des seuils du contrat |
| `hermes_notifier/logs.py` | Journaux `domaine.code`, allowlist de champs, redacteur borné |
| `hermes_notifier/payload.py` | Message `notification + data` dérivé du contrat, sans identité |
| `hermes_notifier/outbox.py` | Dispatcher dry-run, retries bornés, abandon à 48 h, compteurs |
| `hermes_notifier/hermes/rpc.py` | Login/refresh/ticket WS, JSON-RPC, allowlist de lecture seule |
| `hermes_notifier/hermes/observer.py` | Veilles, curseurs, rattrapage, troncature/epoch, rapprochement terminal |
| `hermes_notifier/service.py` | Orchestration, reprise, SIGTERM, réveil sur attache |
| `hermes_notifier/__main__.py` | Point d'entrée `python -m hermes_notifier` |

### Packaging et outillage

| Fichier | Rôle |
|---|---|
| `server/notifier/config.yaml` | Add-on HA, watchdog TCP 8787, options et schéma, aucun port hôte |
| `server/notifier/Dockerfile` | Image Python 3.13 épinglée, `ARG BUILD_FROM` avec défaut |
| `server/notifier/run.sh` | Lancement `exec python -m hermes_notifier` |
| `server/notifier/requirements.txt` | `cryptography==46.0.3`, `websockets==16.0` |
| `server/notifier/requirements-dev.txt` | `PyYAML==6.0.3` |
| `server/notifier/.dockerignore` | Contexte de build minimal |
| `repository.yaml` | Dépôt d'add-ons HA |
| `server/notifier/sync_contracts.py` | Copie byte-identique des contrats, mode `--check` |
| `server/notifier/vendor/contracts/` | Copies vendoriées des trois contrats |
| `.github/workflows/ci.yml` | Vérification de dérive et tests notifier ajoutés |
| `.gitignore` | Artefacts Python ignorés |

### Documentation

| Fichier | Rôle |
|---|---|
| `server/notifier/README.md` | Démarrage rapide, bearer, installation HA, limites |
| `server/notifier/DOCS.md` | Documentation opérationnelle : API, santé, options, Tailscale, diagnostic, sauvegarde |

### Tests

`server/notifier/tests/` contient onze modules et un faux Hermes HTTP+WS
(`support.py`) partageant une seule origine, comme en production :

- `test_contracts.py` — mapping unique, statuts inconnus, `executionId`,
  environnements, allowlists, intégrité vendoriée ;
- `test_store.py` — registre, conflits, ré-attache d'une exécution expirée,
  outbox, premier terminal, dédup, curseurs, purge, retries ;
- `test_api.py` — bearer, quatre routes, erreurs bornées, rate limit, contrat ;
- `test_config.py` — options, secrets, origine, `personal`, CLI, chiffrement ;
- `test_outbox.py` — dry-run, payload, retries, token invalide, abandon 48 h ;
- `test_health.py` — état, seuils, compteurs, champs interdits, retour à `ok` ;
- `test_observer.py` — live, rattrapage, troncature/epoch, doublons, `error`,
  repli `omit_messages`, session disparue, rejeu borné, santé partagée,
  journaux sans identifiant ;
- `test_logs.py` — redaction, allowlist, exceptions, borne mémoire ;
- `test_readonly.py` — RPC/REST interdits, origine, URL WS ;
- `test_packaging.py` — HA, image, watchdog/port, contrats, CI, dérive ;
- `test_service.py` — `--version`, `--check`, `run()`/stop, stop→start, purge
  au démarrage.

## 3. Décisions d'implémentation

### Contrats et terminaux

- `contracts/event-mapping.json` reste la seule source des terminaux ;
  `message.complete.status` passe par `statusMap`, `error` par `workState`.
- Un statut absent ou inconnu ne notifie jamais.
- `executionId = base64url(session_id + ':' + user_row_id)` sans padding.
  `submission_id` n'est jamais substitué à `user_row_id`.
- Les copies vendoriées sont byte-identiques ; `sync_contracts.py --check`
  échoue en cas de dérive.

### Durabilité et déduplication

- SQLite dans `/data`, une connexion sérialisée par verrou.
- Une seule entrée outbox par `(subscriptionId, executionId)` ; la dédup
  `(subscriptionId, executionId, terminal)` conserve `seen_count`.
- Le premier terminal gagne ; les terminaux tardifs ou antérieurs à
  l'exécution sont ignorés.
- Le dispatcher dry-run livre immédiatement ; un échec retryable suit
  `1, 5, 30, 300` s puis 300 s jusqu'à `dropAfterSeconds` (48 h).
  `afterMaxAttempts` choisit `keep-in-outbox` (défaut) ou `drop`.
- `Store.active_executions()` sert à ouvrir les veilles ; `watch_executions()`
  maintient une veille déjà ouverte tant que l'exécution est attachée, même
  si un terminal attend dans l'outbox. Cela permet de voir les doublons et
  les terminaux tardifs pendant l'attente de livraison.
- La purge au démarrage borne les états laissés par un arrêt brutal ; la purge
  périodique suit `retention.prune_interval_seconds`.

### Auth et secrets

- Le bearer n'est jamais stocké en clair : hash SHA-256 salé et sel
  hexadécimal dans les options, comparaison en temps constant.
- La CLI `python -m hermes_notifier.credential generate --json` produit
  `token`, `salt` et `hash` hors du conteneur.
- Le token FCM est chiffré avec Fernet et une clé `token.key` en `0600` dans
  `/data`.
- Les journaux n'acceptent qu'une allowlist de champs ; le redacteur masque
  les en-têtes, tokens et identifiants connus. Sa mémoire est bornée à 4096
  valeurs : les plus récentes restent masquées, les plus anciennes sont
  oubliées.

### Observation et reprise

- `session.resume` avec `omit_messages`, repli sans l'option si Hermes la
  refuse ; puis `gateway.capabilities` et `session.events.since`.
- Le curseur `{connection, profile, sessionId, last_seen, epoch}` est
  persistant.
- `truncated`, `epoch` changé/manquant ou `latest_seq < last_seen` déclenchent
  `session.history`, puis les `events` présents sont traités comme preuve
  terminale ; le curseur avance après ce traitement, ou reprend au dernier
  `seq` traité si `maxReplayEvents` borne le lot.
- Une fin indémontrable reste inconnue ; aucun succès n'est déduit d'un rejeu
  incomplet.
- Seules les erreurs non retryables de type méthode absente (`-32601`) ou
  session inconnue (`-32004`) changent de chemin ; les timeouts et 5xx sont
  retryés.
- La règle `error` suit le contrat : aucune notification avec zéro ou plus
  d'une exécution candidate non pourvue d'outbox ; exactement une donne une
  entrée `failed`.

### Sécurité réseau et packaging

- Aucun port hôte publié ; le service écoute sur `0.0.0.0:8787` **dans le
  conteneur**. L'exposition Tailscale reste `proposed` et sera validée en 5.5.
- `watchdog: "tcp://[HOST]:[PORT:8787]"` sonde le port interne.
- `map` a été retiré : le Supervisor monte toujours `/data` en
  lecture-écriture, sans entrée `map`. Une entrée `type: data, path: /data,
  read_only: false` aurait été un no-op, et `read_only` est ignoré pour ce
  type.
- Le `Dockerfile` conserve `ARG BUILD_FROM=python:3.13-slim-bookworm` et
  `FROM ${BUILD_FROM}` : Supervisor ≥ 2026.04 ne passe plus `BUILD_FROM` par
  défaut, mais un build HA peut toujours le piloter.
- `build.yaml` n'est pas utilisé (déprécié).
- `personal` refuse de démarrer sans Firebase ; en 5.2, il refuse aussi avec
  Firebase complet, car aucun transport FCM réel n'existe. Le refus est
  explicite et journalisé sans secret.

### Compteurs et santé

- `outboxPending` est une jauge (entrées `pending`), pas un cumul.
- `delivered`, `failed`, `dropped`, `expired`, `revoked` et `invalidToken`
  sont des compteurs persistants.
- `hermes-unreachable` : au moins une veille active sans succès Hermes depuis
  60 s ; un `next_event` sans événement compte comme succès, et la sonde reste
  globale (une veille bloquée peut être masquée). `outbox-backlog` : plus de
  50 entrées en attente ; `storage-error` : erreur SQLite ou clé, levée à la
  lecture suivante réussie ; `fcm-unavailable` est ignoré en dry-run et pour
  `integration`.

## 4. Preuves par critère d'acceptation

| Critère | Preuve |
|---|---|
| Une seule entrée outbox, dédup écrite, `outboxPending` puis `delivered` | `test_observer.py::test_terminal_succes_live`, `test_store.py::test_terminal_une_entree_et_dedup`, `test_outbox.py::test_dry_run_livre_et_compte` |
| Reprise depuis `last_seen` ; `truncated`/epoch → `history`, aucun faux succès | `test_observer.py::test_rattrapage_apres_redemarrage`, `test_troncature_recharge_l_historique_et_exploite_le_terminal`, `test_changement_d_epoch_recharge_l_historique_et_exploite_le_terminal`, `test_rejeu_borne_par_max_replay_events`, `test_curseur_sans_epoch_recharge_l_historique`, `test_store.py::test_curseur_persiste` |
| Doublons, terminaux tardifs ou antérieurs ignorés ; premier terminal gagne | `test_observer.py::test_doublon_et_premier_terminal`, `test_terminal_ancien_est_ignore`, `test_store.py::test_premier_terminal_gagne`, `test_terminal_apres_livraison_reste_unique`, `test_terminal_hors_execution_est_ignore`, `test_reattach_reactivates_expired_execution` |
| `error` ambigu sans notification, unique → `failed` | `test_observer.py::test_error_ambigue_est_ignore`, `test_error_unique_notifie_failed`, `test_error_apres_terminal_est_ignore`, `test_store.py::test_candidates_error_et_terminal` |
| Packaging sans port hôte, watchdog 8787, `/data` seul chemin persistant, `personal` refusé | `test_packaging.py::test_config_yaml_add_on`, `test_watchdog_et_port_par_defaut`, `test_config.py::test_personal_refuse_sans_firebase`, `test_personal_refuse_par_le_service_meme_complet` |
| Santé authentifiée bornée ; 401 sans bearer | `test_api.py::test_sante_authentifiee_bornee`, `test_api.py::test_toutes_les_routes_exigent_le_bearer`, `test_health.py::test_ok_avec_champs_exacts_et_compteurs`, `test_aucun_champ_interdit`, `test_observer.py::test_sante_reflete_l_observateur` |
| Aucun identifiant, token ni contenu dans les journaux | `test_observer.py::test_journalisation_sans_identifiant`, `test_logs.py::test_redacteur_masque_les_secrets_connus`, `test_logs.py::test_logger_filtre_les_champs_non_surs`, `test_api.py::test_erreurs_ne_contiennent_aucun_identifiant` |
| `unittest`, `sync_contracts --check`, `flutter analyze`, `flutter test` passent | Voir section 5 |

## 5. Commandes et résultats

Environnement : Windows 10.0.26200, Python 3.13.8, Flutter 3.47.7
(`C:\Users\alanc\fvm\versions\3.47.7\bin\flutter.bat`).

| Commande | Résultat |
|---|---|
| `python server/notifier/sync_contracts.py --check` | `contrats vendorises identiques` |
| `python -m unittest discover -s server/notifier/tests -t server/notifier` | `Ran 121 tests in 24.956s — OK` |
| `python -m compileall -q server/notifier/hermes_notifier` | aucune sortie, aucune erreur |
| `python -m hermes_notifier --version` | `0.1.0` |
| `flutter analyze --no-pub` | `No issues found! (ran in 122.7s)` |
| `flutter test --no-pub` | 466 tests réussis, 17 ignorés, `All tests passed!` |
| `flutter pub get` / `pubspec.yaml` | non exécuté ; aucun changement Dart |
| `docker build -f server/notifier/Dockerfile server/notifier` | **non exécuté localement** : daemon `dockerDesktopLinuxEngine` arrêté. La CI construit l'image et exécute le smoke (`--version`, `Contracts.load()`, `/run.sh`). |

Les sorties `api.refused` et les lignes `INFO`/`WARNING` des tests sont des
journaux attendus des scénarios négatifs ou nominaux ; elles ne contiennent
aucun identifiant, token ni contenu.

## 6. Vérifications manuelles

- `config.yaml` : pas de clé `ports`, `watchdog` TCP 8787, architectures
  `amd64`/`aarch64`, version `0.1.0` alignée sur `hermes_notifier.__version__`.
- `Dockerfile` : `ARG BUILD_FROM` avec défaut, `FROM ${BUILD_FROM}`, aucune
  instruction `ADD`, aucun `curl`, `CMD ["/run.sh"]`.
- `run.sh` : shebang POSIX, `set -eu`, `exec python -m hermes_notifier`.
- Contrats : `vendor/contracts/*.json` byte-identiques aux contrats racine.
- `personal` : refus au chargement sans Firebase, et refus au `Service.check()`
  même complet en 5.2.
- Aucun fichier de `lib/`, `test/` Dart, `contracts/`, `pubspec.yaml`,
  Android ou iOS modifié.

## 7. Limites et points reportés

1. **Aucun push FCM réel.** Le dry-run prouve l'outbox, la déduplication, les
   retries, la rétention et les compteurs, pas la livraison Firebase. Story 5.3.
2. **Image Docker non construite localement.** Le daemon Docker n'était pas
   démarré. La CI la construit et exécute le smoke ; la preuve locale reste
   limitée aux tests de packaging et à la compilation Python.
3. **Installation HA et exposition Tailscale non validées.** L'add-on est
   packagé, mais l'installation réelle, le watchdog en conditions réelles, le
   réseau interne et `tailscale serve --https=443` sont reportés à 5.5. Les
   valeurs `proposed` du contrat de déploiement (8787, 443, TLS) restent
   `proposed`.
4. **Faux Hermes uniquement.** Les tests utilisent un faux HTTP+WS local ; le
   dialecte réel n'est pas rejoué contre un déploiement Hermes.
5. **Contrat 5.1 non modifié.** `runtime.sourcePathStatus` vaut encore
   `planned-for-5.2` et `runtime.watchdog` est un booléen, alors que le service
   existe et que `config.yaml` porte une URL TCP. Le contrat canonique est
   volontairement laissé intact pour ne pas casser les tests 5.1 ; sa mise à
   jour relève de la clôture de 5.1 ou de 5.5.
6. **Pas d'« exactement une fois ».** La garantie est au moins une tentative,
   avec déduplication durable et premier terminal gagnant ; un doublon côté
   FCM reste possible.
7. **Redacteur borné.** Au-delà de 4096 valeurs connues, les plus anciennes
   sont oubliées ; les motifs opaques longs restent masqués.
8. **Une exécution par abonnement.** Deux appareils ne peuvent pas suivre la
   même ligne simultanément ; le second attachement reçoit `400` (DOCS §5.3,
   `deferred-work.md`).
9. **`fcm_service_account` sans montage.** En 5.2, `/data` reste le seul
   volume et `personal` est refusé avant usage ; le chemin sera tranché en
   5.3/5.5 (`deferred-work.md`).
10. **Réserve `session.resume`.** La méthode peut reconstruire une session
    locale côté Hermes ; elle reste la seule écriture indirecte admise et est
    documentée (DOCS §1 et §14).

## 8. Prochaine étape

Lire et suivre `step-05-present.md` : présenter le diff de revue, les 50
constats triés et les preuves, puis recueillir la décision de clôture. Aucun
`bad_spec` ni `intent_gap` n'a été retenu ; `review_loop_iteration` reste à
`0`.
