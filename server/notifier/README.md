# Hermes Notifier

Add-on Home Assistant qui observe les fins de travail Hermes et tient une
outbox durable. Il est **strictement en lecture seule** côté Hermes : il ne
soumet, n'arrête, ne crée et ne renomme jamais de travail. En 5.2, aucun push
FCM réel n'est envoyé : le dispatcher fonctionne en dry-run et marque les
entrées `delivered`.

- Source : `server/notifier/`
- Contrats : `contracts/event-mapping.json`,
  `contracts/notification-tracking.json`,
  `contracts/notification-deployment.json` (copies vendoriées identiques)
- Données persistantes : `/data` uniquement
- Port interne : `8787`, **aucun port hôte publié**
- Santé : `GET /v1/health`, authentifié par bearer

## Démarrage rapide

### 1. Générer le bearer hors du conteneur

Depuis un poste avec Python 3.13 et les dépendances du notifier :

```sh
cd server/notifier
python -m pip install -r requirements.txt
python -m hermes_notifier.credential generate --json
```

La sortie contient `token`, `salt` et `hash`.

- Conservez `token` dans un gestionnaire de secrets : c'est lui que le client
  mobile enverra dans `Authorization: Bearer <token>`.
- Ne mettez **jamais** `token` dans les options de l'add-on.
- Recopiez uniquement `hash` dans `bearer_hash` et `salt` dans `bearer_salt`.

Pour vérifier un couple sans l'écrire en clair :

```sh
python -m hermes_notifier.credential verify --token "$TOKEN" \
  --hash "$HASH" --salt "$SALT"
```

### 2. Configurer l'add-on

Options minimales pour l'essai en dry-run :

| Option | Valeur |
|---|---|
| `environment` | `integration` |
| `hermes_origin` | origine HTTP(S) de Hermes, sans identifiants ni query |
| `hermes_username` | compte Hermes |
| `hermes_password` | mot de passe Hermes (secret HA) |
| `hermes_profile` | profil par défaut, ou vide |
| `bearer_hash` | hash hexadécimal de 64 caractères |
| `bearer_salt` | sel hexadécimal de 64 à 128 caractères |
| `fcm_enabled` | `false` en 5.2 |
| `log_level` | `info` |
| `rate_limit_per_minute` | `120` |

`environment: personal` est refusé en 5.2, même avec Firebase : aucun
transport FCM réel n'est encore livré (story 5.3). Voir [DOCS.md](DOCS.md)
pour le détail des options, de l'API et des limites.

### 3. Installer dans Home Assistant

1. Ajouter ce dépôt comme dépôt d'add-ons :
   `https://github.com/alanmlcrt/hermes-mobile`.
2. Installer **Hermes Notifier**.
3. Renseigner les options ci-dessus, puis démarrer.
4. Vérifier la santé depuis le réseau de l'add-on :

```sh
curl -fsS -H "Authorization: Bearer $TOKEN" \
  http://<hote-addon>:8787/v1/health
```

L'installation réelle sur Home Assistant et l'exposition Tailscale sont
prévues en 5.5 ; 5.2 livre le paquet et les preuves locales.

## Tests et vérifications

```sh
python server/notifier/sync_contracts.py --check
python -m unittest discover -s server/notifier/tests -t server/notifier
python -m compileall server/notifier/hermes_notifier
```

La CI exécute aussi la vérification des contrats vendoriés et la suite du
notifier. Les artefacts Python courants sont ignorés par `.gitignore`.

## Limites assumées

- Aucun push FCM avant 5.3 ; le dry-run prouve l'outbox, pas la livraison.
- Le service est en lecture seule, sauf `session.resume` qui peut reconstruire
  une session locale côté Hermes (réserve du contrat, voir DOCS.md §1).
- Une exécution n'est suivie que par un seul abonnement ; un second appareil
  sur la même ligne reçoit `400` (multi-appareils hors périmètre 5.2).
- `fcm_service_account` n'a pas encore de chemin monté ; `personal` reste
  refusé avant utilisation.
- Pas de garantie « exactement une fois » : au moins une tentative, dédup par
  `(subscriptionId, executionId, terminal)`, premier terminal gagnant.
- Aucun port hôte ; l'accès passe par le réseau interne de Home Assistant et,
  en 5.5, par Tailscale Serve.
- Aucun payload, contenu, identifiant ou token n'est journalisé.
- `personal` reste bloqué tant que Firebase/G3 n'est pas prêt.

Documentation complète : [DOCS.md](DOCS.md).
