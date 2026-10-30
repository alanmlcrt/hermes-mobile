# Story 5.1 — décisions G3

- **Date des décisions :** 2026-10-26
- **Validateur :** Alanc
- **Contrats :** `contracts/notification-tracking.json`, `contracts/notification-deployment.json`
- **Portée :** contrat de suivi et déploiement de l'observateur. Aucun code runtime mobile ou observateur n'est livré ici.
- **Statut de la porte G3 :** **ouverte**. Le projet Firebase et le compte de service ne sont pas créés ; l'essai réel sur téléphone appartient à 5.5.

## Décisions consignées

| Point G3 | Valeur | Statut | Propriétaire | Date |
|---|---|---|---|---|
| Runtime | add-on Home Assistant dédié, supervisé par le Supervisor, watchdog et démarrage avec HA | accepté | Alanc | 2026-10-26 |
| Volume | `/data` persistant : registre, outbox, déduplication, curseur | accepté | Alanc | 2026-10-26 |
| Origine | HTTPS réservé au tailnet ; ports 443/8787 et terminaison TLS proposés | accepté / proposé | Alanc | 2026-10-26 |
| Auth mobile → observateur | jeton bearer opaque par environnement, 256 bits, haché côté observateur | accepté | Alanc | 2026-10-26 |
| Accès Hermes | lecture seule par le contrat épinglé et le mapping partagé, aucune base privée | accepté | Alanc | 2026-10-26 |
| FCM | FCM HTTP v1 gratuit, sans quota, plan Spark ; `firebase_messaging` 17.0.1 + `firebase_core ^5.1.0` proposés, minSdk 24 ; repli 16.x documenté | accepté / proposé | Alanc | 2026-10-26 |
| Projet Firebase | un seul projet, usage personnel, non créé | accepté | Alanc | 2026-10-26 |
| Compte de service | un seul compte, hors dépôt, non créé | accepté | Alanc | 2026-10-26 |
| Intégration | transport dry-run sans FCM, verrouillé | accepté | Alanc | 2026-10-26 |
| Environnements | `fixtures`, `integration`, `personal` isolés (credential, registre, origine) | accepté | Alanc | 2026-10-26 |
| Prérequis Android | constats ADB sur Pixel 8 Pro / Android 17, voir `android-prerequisites.md` | constaté | Alanc | 2026-10-26 |

Les points marqués **accepté** sont validés par Alanc. Les valeurs marquées
**proposé** (ports, terminaison TLS, version FCM) ne sont pas validées : elles
sont consignées avec `status: proposed` et une échéance de confirmation. La
validation globale reste donc `partial`, et G3 reste ouverte.

## Runtime et origine

L'observateur est un add-on Home Assistant dédié. Le Supervisor le supervise,
le redémarre et le sauvegarde ; il démarre avec HA. Son état durable vit dans
`/data`, jamais dans l'image ni dans le dépôt. L'exposition acceptée est un
accès HTTPS réservé au tailnet. Le conteneur écoute en HTTP sur `8787` ; l'accès
mobile passerait par Tailscale en HTTPS sur `443`, avec `8787` comme upstream.
Ces ports et la terminaison TLS Tailscale sont des valeurs proposées, pas des
décisions validées : 5.2 doit les confirmer. Aucun port hôte n'est publié :
l'accès passe par Tailscale Serve et l'ACL du tailnet, jamais par une
publication LAN. Le nom d'hôte tailnet est fourni à l'installation et n'est pas
versionné.

La santé est exposée sur `/v1/health`. Elle exige le bearer, renvoie seulement
`ok` ou `degraded`, des raisons bornées et des compteurs ; aucun contenu, aucun
identifiant de suivi.

## Auth mobile → observateur

Chaque environnement possède son propre jeton opaque. Le mobile le garde dans
`flutter_secure_storage` et l'envoie dans `Authorization`. L'observateur ne
conserve qu'un hachage SHA-256 salé par credential et compare en temps constant.
Le jeton n'apparaît ni dans une URL, ni dans un journal, ni dans un payload
push. Une réponse sans bearer est `401`.

## Accès Hermes

L'observateur lit Hermes uniquement par `contracts/openrpc.json` et applique
`contracts/event-mapping.json`. Méthodes autorisées : `gateway.capabilities`,
`session.list`, `session.status`, `session.resume`, `session.history`,
`session.events.since`. Méthodes interdites : `session.create`,
`prompt.submit`, `session.interrupt`, `session.title`, `file.attach`,
`client.capabilities`. Les routes REST autorisées se limitent à
l'authentification et à la liste des profils (`/auth/password-login`,
`/auth/native/refresh`, `/api/auth/ws-ticket`, `GET /api/profiles`) ; aucune
route de mutation de session ou de tour n'est permise. Aucun accès direct aux
bases privées de Hermes, aucune soumission et aucun arrêt de travail.
L'observateur utilise son propre credential, distinct de celui du mobile.

## FCM

FCM est **gratuit** : Google le liste « No-cost » sur le plan Spark, sans quota
de messages et sans facturation à activer. Le contrat porte ce constat avec sa
source et `billingEnabled: false`.

Version proposée : `firebase_messaging` 17.0.1 avec `firebase_core ^5.1.0` et
minSdk 24. Elle n'a pas encore été résolue ni compilée ; 5.3 doit le faire et
la marquer vérifiée. Si 17.x ne se résout pas avec le Flutter épinglé ou échoue
au build Android, le repli documenté est `firebase_messaging` 16.x, avec la
même abstraction et le même payload. Le transport cible est FCM HTTP v1.

Le message est `notification + data` : le bloc `notification` porte un titre
fixe et un libellé générique dérivé de l'issue, donc Android peut l'afficher
sans réveiller l'app ; le bloc `data` ne porte que `subscriptionId` et
`outcome`, en chaînes. Le canal Android `hermes_turn_complete`, la priorité
haute et le TTL de 24 h sont fixés par le contrat et créés en 5.3. Le token FCM
est enregistré avec le `subscriptionId` ; sa rotation se fait par
ré-enregistrement du même abonnement. Il n'entre ni dans le push ni dans les
journaux. Seul l'environnement personnel exige un token réel ; le dry-run
utilise un marqueur synthétique. L'environnement d'intégration reste en dry-run, sans FCM, même après
la création du projet Firebase.

## Contrat de suivi

`attach` porte `sessionId`, `profile` et `executionId`. Le mobile compose
`executionId` au moment de l'attache depuis
`prompt.submit.params.session_id` et `prompt.submit.result.user_row_id` ;
l'observateur le recalcule depuis `event.params.session_id` et
`message.complete.payload.persisted_turn.user_row_id`. `submission_id` renforce
la corrélation quand il est présent, mais ne remplace jamais `user_row_id`.
Sans session ou sans `user_row_id`, aucun rattachement et aucune notification.
Un `error` de session ne notifie que l'unique exécution attachée et non notifiée
de cette session ; le premier terminal notifié gagne, les terminaux tardifs sont
ignorés.

Après un redémarrage, l'observateur reprend depuis le curseur `last_seen` avec
`session.events.since` ; si la réponse est `truncated` ou si l'`epoch` change,
il recharge `session.history` avant de notifier. Au-delà de la borne de rejeu,
il reprend depuis le dernier événement traité. Les abonnements non attachés,
attachés, notifiés ou expirés, la déduplication et l'outbox sont purgés selon
les durées du contrat, nommées par `expiryByState` ; les révoqués sont supprimés
à la révocation. Un abandon après `dropAfterSeconds` incrémente le compteur
`dropped`. La santé porte une sonde et un seuil par raison de dégradation.

## Preuves Firebase

Constat du 2026-10-26 :

- aucun compte `gcloud` actif dans l'environnement de développement ;
- aucun projet Firebase accessible ;
- aucun fichier `google-services.json` ni `.firebaserc` dans le dépôt ;
- aucun compte de service (clé JSON) dans le dépôt ;
- `notification-deployment.json` porte `status: not-created` et
  `identifier: null` pour le projet comme pour le compte.

Aucun identifiant non secret n'est donc consigné et aucune valeur n'a été
inventée. Dès qu'Alanc crée le projet, seuls le **project ID** et l'adresse du
compte de service (non secrets) sont ajoutés au contrat. La clé JSON reste hors
dépôt et n'est référencée que par la variable
`GOOGLE_APPLICATION_CREDENTIALS`.

### Actions d'Alanc

**Reportées à 5.5 par décision d'Alanc du 2026-10-26.** Elles restent la
condition d'ouverture de G3 sur téléphone réel.

1. Créer **un seul** projet Firebase pour l'usage personnel.
2. Activer l'API FCM HTTP v1.
3. Créer **un seul** compte de service avec le rôle
   `roles/firebasecloudmessaging.admin`.
4. Télécharger la clé JSON hors du dépôt et la déposer dans le runtime de
   l'add-on.
5. Renseigner `GOOGLE_APPLICATION_CREDENTIALS` dans les options de l'add-on.
6. Consigner le project ID et l'adresse du compte de service dans
   `notification-deployment.json`, puis passer `status` à `created`.
7. Ne jamais activer FCM dans l'environnement d'intégration.

## Écarts et risques

| Écart | Effet | Suite |
|---|---|---|
| Projet Firebase absent | G3 reste ouverte ; aucune notification réelle possible | 5.5 |
| Compte de service absent | FCM HTTP v1 non utilisable | 5.5 |
| FCM 17.x non résolu/compilé | choix définitif non prouvé | 5.3 résout ou applique le repli 16.x |
| `POST_NOTIFICATIONS` non déclaré par l'app actuelle | aucune notification ne peut s'afficher | 5.3 ajoute la permission et la demande runtime |
| Aucun canal de notification | l'OS ne peut pas afficher la fin | 5.3 crée le canal |
| Aucun essai réel | comportement app fermée/coupure/redémarrage inconnu | 5.5, seul juge de G3 |
| Rotation/révocation du token FCM non implémentée | token périmé possible | 5.3 |
| Santé runtime non implémentée | pas de diagnostic réel | 5.2 |
| Livraison non « exactement une fois » | doublon possible côté fournisseur | assumé : au moins une livraison, déduplication locale |
| Hôte tailnet non versionné | configuration obligatoire à l'installation | documenté dans le contrat |

## Relecture avec Alanc

- [x] Runtime, volume `/data` : décisions acceptées le 2026-10-26.
- [x] Auth bearer par environnement, hachage côté observateur : décision acceptée.
- [x] Accès Hermes en lecture seule et liste des méthodes : accepté le 2026-10-26.
- [x] FCM gratuit, sans quota, plan Spark : décision acceptée.
- [ ] Version FCM 17.0.1 et repli 16.x : proposée, à confirmer au build de 5.3.
- [ ] Ports 443/8787 et terminaison TLS Tailscale : proposés, à confirmer en 5.2.
- [x] Projet et compte Firebase explicitement absents, sans valeur fictive.
- [x] Intégration toujours en dry-run.
- [x] Aucun secret, chemin personnel ou identifiant de profil dans les contrats.
- [x] G3 reste ouverte ; 5.5 seule peut la franchir.

## Vérification

Constat du 2026-10-26, base `4ba2a0a` (correctif JPEG `4571d09` inclus), SDK
Flutter 3.47.7 épinglé par `.fvmrc` :

| Commande | Résultat | Preuve |
| --- | --- | --- |
| `flutter analyze --no-pub` | Aucune anomalie | `flutter-analyze.log` |
| `flutter test --no-pub test/notification_contract_test.dart test/event_mapping_test.dart test/contracts_test.dart` | 29 réussis | `flutter-targeted.log` |
| `flutter test --no-pub` | 466 réussis, 17 ignorés, aucun échec | `flutter-test.log` |

Le correctif JPEG et la stabilisation du test de flux sont des apports d'epic 4
arrivés pendant l'implémentation ; ils ne font pas partie du contrat de suivi.
La revue de 5.1 utilise `review_base_commit: 4ba2a0a` pour isoler ses
changements.

Le détail, les changements et les prochaines étapes sont dans
`implementation-report.md`. La porte G3 reste ouverte : le projet Firebase, le
compte de service et l'essai réel sur téléphone sont reportés à 5.5 par
décision d'Alanc du 2026-10-26.
