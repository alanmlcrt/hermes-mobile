# Documentation Hermes Notifier

## 1. Rôle et périmètre

Hermes Notifier est un add-on Home Assistant dédié. Il :

- s'authentifie auprès de Hermes en lecture seule ;
- ouvre une veille par couple `(origine, profil, session)` ;
- reprend le flux avec `session.events.since` et un curseur `last_seen`
  persistant ;
- rapproche un terminal de l'exécution par
  `session_id` + `persisted_turn.user_row_id` ;
- écrit une outbox durable dans `/data` ;
- expose une santé authentifiée.

Il ne fait **jamais** de `prompt.submit`, `session.interrupt`, `session.create`,
`session.title`, `file.attach` ni de lecture de base privée Hermes. Les seules
méthodes et routes autorisées sont celles de
`contracts/notification-deployment.json`.

**Réserve du contrat :** `session.resume` sert à rejoindre une session et peut,
côté Hermes, reconstruire une session locale si elle n'existe plus. Le notifier
ne crée ni ne modifie volontairement de travail, mais cette méthode n'est pas
un simple `GET` : elle doit rester la seule écriture indirecte admise, et son
usage est journalisé (`observer.resumed`).

En intégration, l'envoi FCM reste simulé et marque l'entrée `delivered`.
Le transport personnel HTTP v1 existe, mais sa configuration réelle et ses
essais sont différés en 5.5. Aucun push réel n'a été envoyé pendant 5.3.

## 2. Environnements

| Environnement | Transport FCM | Registre | Disponibilité |
|---|---|---|---|
| `fixtures` | `dry-run` | `notifier-registry-fixtures` | tests locaux |
| `integration` | `dry-run` verrouillé | `notifier-registry-integration` | oui, dry-run |
| `personal` | `fcm-http-v1` | `notifier-registry-personal` | clé privée et essais 5.5 requis |

Chaque environnement a son répertoire sous `/data` et son credential séparé.
`personal` refuse de démarrer sans configuration Firebase valide.
Voir §15 pour le montage privé et les prérequis de 5.5.

## 3. Installation dans Home Assistant

### 3.1 Dépôt d'add-ons

Le dépôt racine contient `repository.yaml` et expose l'add-on
`server/notifier/`. Dans Home Assistant :

1. **Paramètres → Add-ons → Boutique → Dépôts**.
2. Ajouter `https://github.com/alanmlcrt/hermes-mobile`.
3. Installer **Hermes Notifier**.

L'add-on :

- démarre au boot (`boot: auto`) ;
- utilise `/data` comme volume persistant ;
- n'expose aucun port sur l'hôte ;
- déclare un watchdog TCP sur `tcp://[HOST]:[PORT:8787]` ;
- écoute sur `0.0.0.0:8787` **dans le conteneur**.

L'installation réelle et l'exposition réseau sont validées en 5.5. En 5.2, le
paquet est construit et testé localement.

### 3.2 Bearer

Le bearer n'est jamais stocké en clair. Générez-le hors du conteneur :

```sh
cd server/notifier
python -m pip install -r requirements.txt
python -m hermes_notifier.credential generate --json
```

Exemple de sortie :

```json
{"token":"<secret>","salt":"<hex>","hash":"<hex>"}
```

À faire :

- conserver `token` dans le client mobile ou un gestionnaire de secrets ;
- recopier `hash` dans l'option `bearer_hash` ;
- recopier `salt` dans l'option `bearer_salt`.

À ne pas faire :

- coller `token` dans les options ;
- journaliser la sortie de la commande ;
- réutiliser le même bearer entre environnements.

Vérification :

```sh
python -m hermes_notifier.credential verify \
  --token "$TOKEN" --hash "$HASH" --salt "$SALT"
```

Le serveur compare le hash en temps constant. Un en-tête absent, mal formé ou
un token erroné reçoit `401`.

### 3.3 Rotation du bearer

Il n'existe qu'un bearer actif : il n'y a pas de période de recouvrement.

1. Générer un nouveau couple hors du conteneur :
   `python -m hermes_notifier.credential generate --json`.
2. Remplacer `bearer_hash` et `bearer_salt` dans les options de l'add-on.
3. Redémarrer l'add-on : l'ancien token est refusé dès le redémarrage.
4. Mettre à jour le client mobile avec le nouveau `token`, puis vérifier
   `GET /v1/health` avec `Authorization: Bearer <nouveau>`.

En cas d'urgence, révoquer d'abord les abonnements (`DELETE`) puis faire la
rotation : un token mobile volé ne peut plus attacher ni lire la santé, mais
les notifications déjà en outbox restent soumises au nouveau bearer côté
serveur (le bearer n'authentifie pas FCM).

## 4. Options de l'add-on

| Option | Type | Défaut | Contrainte |
|---|---|---|---|
| `environment` | liste | `integration` | `fixtures`, `integration`, `personal` |
| `hermes_origin` | texte | — | `http(s)://hote[:port][/base]`, sans identifiants, query ni fragment |
| `hermes_username` | texte | `hermes` | non vide |
| `hermes_password` | mot de passe | — | non vide, jamais journalisé |
| `hermes_profile` | texte | vide | profil par défaut si la requête n'en fournit pas |
| `bearer_hash` | texte | — | 64 caractères hexadécimaux |
| `bearer_salt` | texte | — | 64 à 128 caractères hexadécimaux |
| `fcm_enabled` | booléen | `false` | doit rester `false` en dry-run |
| `fcm_service_account` | texte | vide | requis seulement pour `personal` (5.3) |
| `log_level` | liste | `info` | `debug`, `info`, `warning`, `error` |
| `rate_limit_per_minute` | entier | `120` | 1 à 10000 |

Variables d'environnement équivalentes, utiles aux tests et au diagnostic :
`HERMES_NOTIFIER_ENVIRONMENT`, `HERMES_NOTIFIER_HERMES_ORIGIN`,
`HERMES_NOTIFIER_HERMES_USERNAME`, `HERMES_NOTIFIER_HERMES_PASSWORD`,
`HERMES_NOTIFIER_HERMES_PROFILE`, `HERMES_NOTIFIER_BEARER_HASH`,
`HERMES_NOTIFIER_BEARER_SALT`, `HERMES_NOTIFIER_FCM_ENABLED`,
`HERMES_NOTIFIER_FCM_SERVICE_ACCOUNT`, `HERMES_NOTIFIER_LOG_LEVEL`,
`HERMES_NOTIFIER_RATE_LIMIT_PER_MINUTE`, `HERMES_NOTIFIER_DATA_DIR`,
`HERMES_NOTIFIER_PORT`.

Toute option de credential en clair (`bearer`, `token`, etc.) est refusée au
chargement.

`fcm_service_account` attend un **chemin de fichier** lisible dans le
conteneur. Le montage `/share` en lecture seule décrit au §15 fournit le fichier.
`personal` exige la validation de
ce chemin. Le montage ou la remise du JSON Firebase sera tranché avec la
story 5.3 (piste : secret Home Assistant ou volume `/share` en lecture seule).
Ne pas placer de clé de service dans `/data` sans décision explicite.

## 5. API du notifier

Toutes les routes exigent :

```http
Authorization: Bearer <token>
```

Réponses d'erreur : exactement `{"code": "...", "message": "..."}`. Aucun
identifiant, chemin ou contenu n'y figure.

### 5.0 Codes d'erreur

| Code | Statut HTTP | Sens |
|---|---|---|
| `invalid-request` | `400` | corps, identifiant ou `executionId` invalide, conflit d'attache |
| `unauthorized` | `401` | bearer absent, mal formé ou erroné (`WWW-Authenticate: Bearer`) |
| `not-found` | `404` | route ou abonnement inconnu |
| `gone` | `410` | abonnement expiré ou révoqué |
| `rate-limited` | `429` | limite d'une minute dépassée (`Retry-After`) |
| `unavailable` | `503` | stockage, configuration ou service indisponible |
| `internal` | `500` | erreur interne masquée |

Les codes `502` et `504` figurent dans les `errorStatus` du contrat pour un
proxy amont ; le notifier ne les émet pas lui-même en 5.2 (aucun appel FCM).

### 5.1 Santé

```http
GET /v1/health
```

Réponse `200` :

```json
{
  "state": "ok",
  "reasons": [],
  "counters": {
    "pending": 0,
    "attached": 0,
    "outboxPending": 0,
    "delivered": 0,
    "failed": 0,
    "dropped": 0,
    "expired": 0,
    "revoked": 0,
    "invalidToken": 0
  },
  "version": "0.1.0",
  "checkedAt": "2026-10-27T12:00:00Z"
}
```

`state` vaut `ok` ou `degraded`. Une raison contient son seuil :

- `hermes-unreachable` : au moins une veille active sans succès Hermes depuis
  60 s (`thresholdSeconds: 60`). Chaque poll `next_event` sans événement
  (toutes les 30 s) et chaque événement accepté compte comme succès. La sonde
  est **globale**, pas par veille : une veille bloquée peut être masquée par
  une autre veille saine, et une veille inactive ne dégrade pas la santé ;
- `outbox-backlog` : plus de 50 entrées `pending` (`threshold: 50`) ;
- `storage-error` : erreur SQLite ou clé de chiffrement
  (`thresholdSeconds: 0`), levée dès la lecture suivante réussie ;
- `fcm-unavailable` : erreur FCM depuis 300 s, ignorée en dry-run et pour
  l'environnement `integration`.

`outboxPending` est une jauge, pas un cumul. `delivered`, `failed`, `dropped`,
`expired`, `revoked` et `invalidToken` sont des compteurs persistants.

### 5.2 Enregistrement

```http
POST /v1/subscriptions
Content-Type: application/json

{"subscriptionId":"<opaque 22-128>","fcmToken":"<token FCM>"}
```

- `201` : créé ;
- `200` : déjà connu, token remplacé ;
- `400` : format invalide, clé inconnue ou corps trop long ;
- `401` : bearer absent ou invalide.

Le token FCM est chiffré avec une clé Fernet propre à `/data` (`token.key`,
mode `0600`). Il n'est jamais renvoyé ni journalisé.

### 5.3 Attache

```http
POST /v1/subscriptions/<subscriptionId>/attach
Content-Type: application/json

{"sessionId":"<session>","profile":"default","executionId":"<base64url>"}
```

`executionId = base64url(sessionId + ":" + user_row_id)` sans padding. Le
notifier recalcule la valeur et refuse toute incohérence. Exemple :
`base64url("a1b2c3d4:42") = YTFiMmMzZDQ6NDI`.

- `202` : exécution attachée, veille démarrée ;
- `200` : attache déjà connue pour le même abonnement ;
- `404` : abonnement inconnu ;
- `410` : abonnement expiré ou révoqué ;
- `400` : conflit, format invalide ou autre exécution déjà attachée.

Une exécution n'appartient qu'à **un seul** abonnement : si un second appareil
attache la même session et la même ligne, il reçoit `400`. Le suivi simultané
multi-appareils est hors périmètre 5.2 ; il faudra un abonnement par appareil
et une évolution du stockage (voir `deferred-work.md`). Ré-attacher la même
exécution depuis le même abonnement reste idempotent (`200`).

### 5.4 Révocation

```http
DELETE /v1/subscriptions/<subscriptionId>
```

Toujours `204`, y compris pour un identifiant inconnu (idempotent). Les
exécutions, l'outbox et les curseurs orphelins sont supprimés. Un tombstone
fait répondre `410` à un attachement pendant `expiredTtlSeconds` (1 jour),
tant que l'identifiant n'est pas ré-enregistré ; après ce délai la ligne est
purgée et un attachement répond `404`. Un `POST /v1/subscriptions` explicite
recrée l'abonnement et efface le tombstone.

Réutiliser un identifiant après révocation est donc volontairement possible :
le nouveau `POST` remplace l'ancien état, remet l'abonnement en
`registered`, et exige un nouveau token FCM. Les terminaux de l'ancienne
exécution ne sont pas rejoués.

### 5.5 Limite de débit

Fenêtre fixe d'une minute, par défaut 120 requêtes. Au-delà : `429` avec
`Retry-After`. Le rate limit s'applique après l'authentification.

### 5.6 Rotation du token FCM

Le token FCM se renouvelle en réenregistrant le **même** `subscriptionId` :

```http
POST /v1/subscriptions
{"subscriptionId":"<identique>","fcmToken":"<nouveau>"}
```

La réponse est `200`, le token chiffré est remplacé et les entrées outbox
encore `pending` utilisent le nouveau token à la prochaine tentative. Un token
invalide signalé par FCM supprime l'abonnement et incrémente `invalidToken` :
le mobile doit alors se réenregistrer et ré-attacher.

### 5.7 429, horloge et reprises

- Sur `429`, respecter `Retry-After` (secondes) avant de réessayer ; ne pas
  réessayer en boucle serrée.
- `checkedAt` est en UTC (`...Z`). Un décalage d'horloge du client ne change
  pas la validité du bearer, mais peut fausser l'interprétation des TTL et des
  âges de santé : garder NTP actif sur Home Assistant et le téléphone.
- Les erreurs `500`, `502`, `503`, `504` et réseau sont retryables côté mobile
  avec un backoff borné ; `400`, `401`, `404`, `409` et `410` ne le sont pas.

## 6. Cycle de vie d'un terminal

1. L'observateur ouvre `session.resume` avec `omit_messages: true`; si Hermes
   refuse l'option, il réessaie sans.
2. Il envoie `gateway.capabilities`, puis `session.events.since` avec
   `last_seen`.
3. Le mapping partagé décide seul du terminal :
   `message.complete.status` via `statusMap`, `error` via `workState`.
4. Un statut absent ou inconnu ne produit **jamais** de notification.
5. Le terminal est rapproché par `session_id` et `persisted_turn.user_row_id`.
6. Le premier terminal gagne : une entrée outbox par
   `(subscriptionId, executionId)`, dédup
   `(subscriptionId, executionId, terminal)` avec `seen_count`.
7. Le dispatcher déchiffre le token, construit un message `notification +
   data` conforme au contrat, puis :
   - dry-run : valide le schéma, marque `delivered`, incrémente `delivered` ;
   - erreur retryable : `pending`, backoffs `1, 5, 30, 300` s (5 tentatives),
     puis une tentative toutes les 300 s tant que l'entrée a moins de
     `dropAfterSeconds` (48 h) ; `afterMaxAttempts: keep-in-outbox` conserve
     l'entrée, une politique `drop` l'abandonne ;
   - token invalide : abonnement supprimé, compteur `invalidToken` ;
   - erreur permanente ou payload invalide : `dropped` ;
   - plus de 48 h sans livraison : `dropped`.

Aucune promesse « exactement une fois ». Le système garantit au mieux une
livraison et une déduplication durable ; un doublon côté FCM reste possible.

## 7. Rattrapage, troncature et epoch

Le curseur `{connection, profile, sessionId, last_seen, epoch}` est écrit dans
SQLite. Après un redémarrage, `session.events.since` repart de `last_seen`.

Si la réponse est `truncated`, si `latest_seq < last_seen`, si l'epoch change
ou manque, le service :

1. appelle `session.history` pour documenter la fenêtre incertaine ;
2. traite les `events` **présents** dans la réponse comme preuve terminale :
   un terminal explicitement renvoyé n'est pas jeté ;
3. fait avancer le curseur au dernier `seq` réellement traité, jamais
   directement à `latest_seq` lorsqu'un terminal a été exploité ;
4. au-delà de `maxReplayEvents` (1000), reprend le rejeu depuis le dernier
   `seq` traité (`continue-from-last-processed`) au lieu de sauter au bout ;
5. journalise `observer.truncated`, `observer.epoch_changed`,
   `observer.epoch_missing` ou `observer.cursor_ahead`.

Une erreur transitoire de `session.events.since` (timeout, 5xx) est retryée :
le curseur reste en arrière et le prochain essai rejoue la même fenêtre. Seul
un gateway qui ne connaît pas la méthode (`-32601`, méthode absente) replie
sur `session.history` et journalise `observer.catch_up_unavailable`.

Une fin indémontrable reste inconnue plutôt que d'être annoncée à tort : aucun
succès n'est déduit d'un historique ou d'un rejeu incomplet sans terminal
correspondant à la ligne attachée.

## 8. Rétention et purge

Valeurs du contrat :

| Élément | Durée / seuil |
|---|---|
| Abonnement `notified` | 7 jours |
| Abonnement `expired` | 1 jour |
| Déduplication | 30 jours |
| Entrée outbox en attente | 48 h maximum |
| Purge | toutes les heures |

La purge est aussi exécutée au démarrage pour borner les états laissés par un
arrêt brutal. Les tombstones de révocation suivent `expiredTtlSeconds`
(1 jour) : après ce délai, l'identifiant est oublié et un attachement répond
`404` au lieu de `410`.

## 9. Journaux

Format : `domaine.code` suivi de champs sûrs. Exemples :

```text
INFO observer.resumed {"status":"attached"}
INFO observer.terminal {"outcome":"succeeded","state":"pending","terminal":"succeeded"}
INFO outbox.delivered {"attempt":1,"outcome":"succeeded","schema_valid":true,"status":"delivered","terminal":"succeeded"}
WARNING observer.truncated
```

Catalogue des codes émis :

| Code | Niveau | Quand |
|---|---|---|
| `service.started` / `service.stopped` | info | démarrage et arrêt propre |
| `api.request` | info | requête authentifiée traitée |
| `api.refused` | warning | `401`, `429` ou erreur métier bornée |
| `api.error` | error | exception inattendue (classe seule) |
| `storage.error` | error | lecture/écriture SQLite ou clé indisponible |
| `storage.pruned` | info | purge avec compteurs réellement supprimés |
| `observer.resumed` | info | `session.resume` accepté |
| `observer.resume_fallback` | warning | `omit_messages` refusé, reprise sans |
| `observer.catch_up` | info | événements de rattrapage traités |
| `observer.catch_up_unavailable` | warning | `session.events.since` absent, repli historique |
| `observer.history_refetched` | info | historique rechargé (troncature/epoch) |
| `observer.truncated` / `observer.epoch_changed` / `observer.epoch_missing` / `observer.cursor_ahead` | warning | incertitude de rejeu |
| `observer.terminal` | info | terminal retenu pour une exécution |
| `observer.duplicate` | info | terminal déjà dédupliqué |
| `observer.unmatched` | info | terminal sans ligne persistée correspondante |
| `observer.error_ambiguous` | warning | plusieurs erreurs candidates, aucune notifiée |
| `observer.expired` | warning | session disparue, exécution expirée |
| `observer.session_retry` / `observer.unreachable` | warning | reprise Hermes bornée |
| `observer.cycle_error` / `observer.loop_error` / `observer.watch_error` | error | garde-fou de boucle ou de veille |
| `outbox.delivered` | info | entrée livrée (dry-run en 5.2) |
| `outbox.retry` / `outbox.retry_exhausted` | warning | nouvelle tentative planifiée / plafond atteint |
| `outbox.dropped` | warning | abandon (âge, état, payload, livraison) |
| `outbox.invalid_token` | warning | token FCM invalide, abonnement supprimé |
| `outbox.payload_invalid` / `outbox.delivery_permanent` / `outbox.token_unavailable` | error/warning | message ou credential inutilisable |
| `outbox.transport_error` / `outbox.loop_error` | error | transport ou boucle en échec |
| `hermes.refresh_refused` | warning | renouvellement du jeton Hermes refusé |

Ne sont jamais journalisés : payload, contenu, message Hermes, token,
`subscriptionId`, `executionId`, `sessionId`, profil, mot de passe, hash, sel
ou chemin. Un redacteur retire en plus les motifs `Authorization`/`Bearer` et
les identifiants opaques connus.

## 10. Tailscale Serve (procédure cible 5.5)

L'add-on ne publie **aucun port hôte**. L'accès distant prévu est
`tailnet-only`, avec TLS terminé par Tailscale sur le port 443 et un upstream
interne vers le port 8787.

Procédure à valider en 5.5, depuis l'environnement Tailscale de Home
Assistant :

1. Vérifier que l'add-on Tailscale et Hermes Notifier partagent le réseau
   Docker interne de Home Assistant.
2. Résoudre le nom d'hôte interne de l'add-on (remplacer `<hote-interne>`).
3. Configurer un proxy HTTPS :

   ```sh
   tailscale serve --bg --https=443 http://<hote-interne>:8787
   ```

4. Vérifier depuis un appareil du tailnet :

   ```sh
   curl -fsS -H "Authorization: Bearer $TOKEN" \
     https://<machine>.<tailnet>.ts.net/v1/health
   ```

5. Ne jamais publier 8787 sur l'hôte, ni exposer l'add-on au LAN.

Les ports 8787 et 443, ainsi que la terminaison TLS, restent `proposed` dans le
contrat de déploiement jusqu'à l'essai réel de 5.5.

## 11. Sauvegarde et restauration

Sauvegarder l'ensemble du volume `/data` :

- `notifier.sqlite3` (registre, outbox, dédup, curseurs, compteurs) ;
- `token.key` (clé de déchiffrement des tokens FCM) ;
- journaux éventuels du Supervisor.

Sans `token.key`, les tokens FCM chiffrés sont illisibles : les entrées outbox
correspondantes finissent en retry puis en abandon. Restaurer la base et la clé
ensemble, à l'arrêt de l'add-on.

## 12. Diagnostic

| Symptôme | Vérifier |
|---|---|
| `401` sur toutes les routes | hash/sel recopiés, token côté client, espace dans l'en-tête |
| `404` à l'attache | abonnement enregistré, `executionId` recalculé |
| `410` à l'attache | abonnement expiré ou révoqué, réenregistrer |
| `degraded` + `hermes-unreachable` | origine Hermes, identifiants, profil, réseau |
| `degraded` + `outbox-backlog` | dispatcher arrêté ou transport bloqué |
| `degraded` + `storage-error` | permissions de `/data`, intégrité SQLite, clé |
| Aucun terminal | mapping, statut absent/inconnu, `persisted_turn.user_row_id` |
| `personal` refuse de démarrer | compte de service absent/invalide, `fcm_enabled`, montage privé |

Logs utiles : voir le catalogue du §9 ; les plus fréquents en diagnostic sont
`observer.resumed`, `observer.catch_up`, `observer.terminal`,
`observer.duplicate`, `observer.truncated`, `observer.epoch_changed`,
`observer.catch_up_unavailable`, `outbox.delivered`, `outbox.retry`,
`outbox.dropped`, `storage.pruned` et `api.refused`.

## 13. Développement et CI

```sh
# Contrats vendoriés
python server/notifier/sync_contracts.py --check

# Suite complète
python -m unittest discover -s server/notifier/tests -t server/notifier

# Syntaxe
python -m compileall server/notifier/hermes_notifier

# Image (si Docker est disponible)
docker build -f server/notifier/Dockerfile server/notifier
```

La CI ajoute `sync_contracts.py --check`, installe
`server/notifier/requirements.txt` et `requirements-dev.txt`, puis exécute la
suite. Le build context de l'image est `server/notifier/` ; les contrats
vendorisés doivent rester byte-identiques aux contrats racine.

## 14. Limites connues

- Aucun envoi FCM réel n'a été exécuté : seuls les transports simulés sont testés.
- Une exécution n'est liée qu'à un abonnement : deux appareils ne peuvent pas
  suivre la même ligne simultanément (second attachement `400`).
- `session.resume` peut reconstruire une session locale côté Hermes ; c'est la
  seule méthode non strictement passive, documentée au §1.
- Aucune installation Home Assistant ni exposition Tailscale validée avant
  5.5 ; le contrat garde ces valeurs `proposed`.
- Le watchdog est déclaré sous forme d'URL TCP 8787 ; le contrat 5.1 le
  consigne comme booléen `true`.
- La rétention ne promet pas « exactement une fois ».
- Le redacteur borne sa mémoire : au-delà de 4096 valeurs connues, les plus
  anciennes sont oubliées. Les motifs opaques longs restent masqués.
- Les tests locaux utilisent un faux Hermes HTTP+WS, pas un déploiement réel.

## 15. Préparation FCM pour 5.5

Ne créer aucun projet ou compte pendant 5.3. En 5.5, préparer le projet personnel
unique, FCM HTTP v1 et un compte de service avec `roles/firebasecloudmessaging.admin`.
Conserver sa clé JSON hors dépôt ; ne la mettre ni dans les options HA ni dans
une image. Le transport utilise `google-auth` pour des tokens OAuth courts,
renouvelés à expiration, et borne chaque requête OAuth/FCM à huit secondes.
L’intégration et les fixtures restent verrouillées en dry-run, sans accès Google.

Chemin utilisable par l’add-on : déposer la clé privée dans
`/share/hermes-notifier/service-account.json` sur Home Assistant, avec des droits
limités au propriétaire. L’add-on monte `share` en lecture seule ; il ne lit que
le fichier référencé. Configurer `environment: personal`, `fcm_enabled: true`
et `fcm_service_account: /share/hermes-notifier/service-account.json`.
Hors Supervisor, `GOOGLE_APPLICATION_CREDENTIALS` peut référencer un fichier
monté en lecture seule (l’option explicite garde priorité). `--check` valide la
clé et son projet sans appeler Google. Sauvegarder la clé séparément et limiter
l’accès aux sauvegardes HA ; rotation annuelle ou au moindre doute.

Pour Android en 5.5, enregistrer `fr.hermes_mobile`, obtenir la configuration
client et déposer le fichier non versionné `android/app/google-services.json`.
Le plugin Gradle Google Services n’est appliqué que si ce fichier existe.
Sans lui, le même APK démarre avec l’état « Firebase non configuré » ; aucun faux
token n’est utilisé. L’autorisation est demandée uniquement par le bouton
d’activation. Services Google absents, permission refusée, batterie et arrêt
forcé sont expliqués dans les réglages. Après arrêt forcé, rouvrir l’app.

Tests reproductibles sans compte Google :

```sh
fvm flutter pub get --enforce-lockfile
fvm flutter analyze --no-pub
fvm flutter test --no-pub
fvm flutter build apk --debug --no-pub
python -m unittest discover -s server/notifier/tests -t server/notifier
python server/notifier/sync_contracts.py --check
```

Les erreurs FCM permanentes sont abandonnées, `UNREGISTERED` révoque le token,
les pannes/429/5xx suivent l’outbox bornée. Un 401 force le renouvellement OAuth.
Les réponses et exceptions brutes ne sont jamais journalisées. Le payload est
construit depuis le contrat : seulement `subscriptionId` et `outcome` en data,
avec trois libellés génériques. Aucune promesse d’exactement une livraison et
aucune validation G3 avant les essais réels de 5.5.
