---
title: 'Story 5.7 — Basculer l''app sur le plugin'
type: 'feature'
created: '2026-10-29'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '7c451bce2acc4bfa6dd371fa37f73a8810cec6d9'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Les notifications du plugin portent `{outcome, sessionId}`, mais l'app n'accepte que `{subscriptionId, outcome}` : en premier plan elles sont ignorées, au toucher la conversation ne s'ouvre pas. Les réglages demandent encore une URL et un bearer d'observateur par connexion, et l'envoi enregistre un abonnement auprès de l'observateur.

**Approche :** Remplacer la clé `subscriptionId` par `sessionId` (id stocké Hermes) de bout en bout, résolu localement vers connexion/profil ; retirer de l'app tout le chemin observateur (abonnements, réglages, santé, bearer) ; marquer « notification non suivie » quand `command.dispatch hermes-mobile-token` répond 4018 ; purger tables et secret par une migration ajoutée.

## Boundaries & Constraints

**Toujours :** La notification reste un indice : la conversation ouverte se réauthentifie et recharge depuis Hermes. Rien ne bloque ni ne retarde l'envoi. Seuls `outcome` ∈ {succeeded, failed, stopped} et un `sessionId` valide sont acceptés ; aucun texte reçu n'est affiché. Migrations en ajout seul. Explications permission refusée, prérequis Google et arrêt forcé conservées.

**Jamais :** Toucher `server/`, `contracts/`, `test/notification_contract_test.dart`, `README.md` ni la CI (story 5.8). Pas de nouvelle dépendance. Pas de file ni de rattrapage côté app.

## I/O & Edge-Case Matrix

| Scénario | Entrée / état | Attendu | Gestion d'erreur |
|---|---|---|---|
| Toucher, session connue | `sessionId` présent dans `conversation_timelines` ou `outbox_drafts` (connexion courante, profil existant) | `/c/<connexion>/<profil>/<sessionId>` à froid, à chaud, depuis les récents | Sans authentification : la cible attend |
| Toucher, session inconnue | aucune ligne, autre connexion ou profil disparu | SnackBar `notificationTargetMissing` puis accueil | Jamais le fil affiché |
| Premier plan | `data = {outcome, sessionId}` valides | Notification locale générique, tag `hermes:<sessionId>:<outcome>` | Clés en plus, `outcome` inconnu, id invalide → ignoré |
| Plugin absent | `command.dispatch` → `RpcError(4018)` | Tour marqué « Notification non suivie » (`notification_unfollowed = 1`, timeline rafraîchie) | Autre erreur, délai, pas de jeton → aucune marque, envoi accepté |
| Migration | base v. N avec tables et bearer d'observateur | Tables supprimées, secret `observerBearer` effacé pour chaque connexion configurée | Échec du stockage sécurisé ignoré (la migration aboutit) |

</frozen-after-approval>

## Code Map

- `android/app/src/main/kotlin/fr/hermes_mobile/MainActivity.kt` — extra `subscriptionId` → `sessionId` (FCM met `data` en extras au toucher système), regex de session, `show` lit `sessionId`, tag inchangé dans sa forme.
- `lib/models/notifications.dart` — `isSubscriptionId` → `isSessionId` (`^[A-Za-z0-9_.:-]{1,256}$`, borne du plugin) ; supprimer `ObserverSettings`, `NotificationGateway` ; `NotificationClient` reste (doc : `sessionId`).
- `lib/data/firebase_notification_client.dart` — filtre `onMessage` sur `{sessionId, outcome}` ; canal `opened`/`takeOpened` valident `isSessionId`.
- `lib/data/notification_repository.dart` — réduire à `database` + `device` : `target(sessionId)` = `SELECT connection_key, profile_key FROM conversation_timelines WHERE stored_session_id = ? UNION SELECT … FROM outbox_drafts WHERE stored_session_id = ?` ; exactement une ligne → cible, sinon `null`. Supprimer settings/configure/enable/disable/health/resume/prepare/submitting/attach/submittedSession/_request, `http`, `secrets`, rotations ; `dispose` ferme `device`.
- `lib/app/routes.dart:346` — `openNotification(String sessionId)` avec `isSessionId` ; `resolveLaunchTarget` inchangé.
- `lib/main.dart:101,131` — retirer les `notifications?.resume()`.
- `lib/app/bootstrap.dart:36` — `NotificationRepository(database, device)`.
- `lib/data/outbox_repository.dart` — retirer `prepare` (l. 1055-1070), `submitting` (1141), `_attachNotification` et ses appels (1298, 1593, 1710) ; `_shareTokenWithPlugin(g, operation, timelineKey)` : sur `RpcError` code 4018 → `notification_unfollowed = 1` puis `conversation?.refreshAttachments(timelineKey)`.
- `lib/data/conversation_repository.dart:105-121` — `notificationUnfollowed = op['notification_unfollowed'] == 1` ; plus de lecture de `notification_subscriptions`.
- `lib/data/storage/migrations.dart` — nouvelle entrée en fin : lire `connection_key` de `notification_settings`, `DROP TABLE notification_subscriptions`, `DROP TABLE notification_settings`, puis `purgeObserverBearer(keys)` (variable de haut niveau remplaçable en test, défaut `SecureSecretStore(const FlutterSecureStorage()).delete(…, SecretUsage.observerBearer)` sous `try`). `SecretUsage.observerBearer` est gardé : clé héritée, aussi purgée par `clear()`.
- `lib/ui/components/notification_settings.dart` — prend `NotificationClient device` ; garde titre, `notificationPrerequisites`, état du téléphone, bouton « Autoriser les notifications » (`device.token(requestPermission: true)`), rafraîchissement au retour ; supprime champs URL/bearer, santé, activer/désactiver.
- `lib/features/profiles/profile_settings_view.dart:94` — passe `notifications.device` ; plus de condition sur la connexion.
- `lib/ui/content.dart:10-36` — supprimer `observerOrigin`, `observerBearer`, `notificationSave`, `notificationDisable`, `notificationHealth`, `notificationEnabled/Disabled`, `notificationRevocationHint`, `notificationConfigError`, `observerHealth` ; renommer `notificationEnable` → « Autoriser les notifications ».
- Tests : `test/notification_open_test.dart` (ids `sessionId`, cible via timelines/drafts), `test/firebase_notification_client_test.dart` (payload `sessionId`), `test/notification_repository_test.dart` (garder le groupe jeton plugin + 4018, supprimer le reste observateur), `test/notification_settings_test.dart` (nouveau widget), `test/*` utilisant `NotificationRepository(…)`.

## Tasks & Acceptance

**Exécution :**
- [x] `MainActivity.kt`, `lib/models/notifications.dart`, `lib/data/firebase_notification_client.dart` — clé `sessionId` de bout en bout.
- [x] `lib/data/notification_repository.dart`, `lib/app/routes.dart`, `lib/main.dart`, `lib/app/bootstrap.dart` — dépôt réduit à la résolution locale.
- [x] `lib/data/outbox_repository.dart`, `lib/data/conversation_repository.dart` — retrait des abonnements ; marque 4018.
- [x] `lib/data/storage/migrations.dart` — migration de purge.
- [x] `notification_settings.dart`, `profile_settings_view.dart`, `content.dart` — réglages sans observateur.
- [x] Tests — chaque ligne de la matrice ; migration depuis la version précédente (tables absentes, purge appelée avec les clés) ; réglages sans champ d'observateur.

**Critères d'acceptation :**
- Étant donné `grep -rn "subscriptionId\|observateur\|Observateur\|notification_subscriptions" lib android/app/src`, quand il tourne, alors seules la migration historique et la nouvelle migration apparaissent.
- Étant donné les réglages du profil, quand Alanc les ouvre, alors aucun champ d'URL ni de bearer, et les explications permission et arrêt forcé sont visibles.

## Implementation Notes

## Spec Change Log

## Review Triage Log

| Constat | Verdict | Preuve | Suite |
|---|---|---|---|
| Rotation du jeton FCM plus relayée au plugin (2 relecteurs) | low | Rotation rare ; le jeton repart au prochain envoi ; un tour en vol peut perdre sa notification. Correctif = nouvel écouteur + dispatch hors envoi. | rejeté (rare, ajoute du code) |
| 4018 en nombre nu | low | Docstring de `_shareTokenWithPlugin` explique le code. | rejeté |
| Pas de marque sans jeton / délai / autre erreur | false | Matrice figée : seule 4018 marque. | rejeté (intention) |
| `isSessionId` accepte `.`/`..` | false | `target()` exige une ligne locale ; aucun id Hermes `..` → accueil. | rejeté |
| Test de migration épinglé à `length - 1` | low | Casse dès qu'une migration suit. | patch |
| Purge Keystore dans la transaction d'upgrade (2 relecteurs) | low | Une connexion en pratique, délai borné 3 s ; la spec demande la purge dans la migration. | rejeté |
| Test « délai dépassé » sans valeur | false | Le harnais fixe `timeout: 50 ms` (test l. 89) < 150 ms d'attente. | rejeté |
| Titres de tests 4018 qui se recouvrent | low | Cosmétique. | rejeté |
| `_busy` libéré par un resume pendant la demande de permission (2 relecteurs) | low | Seconde demande possible ; garde d'une condition. | patch |
| Bouton sans état ni accès aux réglages Android | low | Amélioration UX hors intention. | rejeté |
| Aucun texte n'annonce le plugin requis | low | La marque « non suivie » le signale par tour. | rejeté |
| Session jamais stockée localement → introuvable | false | Ligne de matrice figée. | rejeté (intention) |
| Filtre `data.length == 2` strict | false | Matrice figée : clés en plus → ignoré. | rejeté (intention) |
| Spec absente du diff | false | Exclue volontairement ; présente dans le dépôt. | rejeté |
| `SecretUsage.observerBearer` sans commentaire d'héritage | low | Correction directe d'une ligne. | patch |
| 4018 après changement de profil : marque invisible jusqu'au rechargement | low | `canPublish` faux ; relue à la prochaine lecture de la timeline. | rejeté |
| Jeton partagé avant le contrôle `turnActive` | false | Une opération non acceptée n'apparaît jamais (requête `state = accepted`). | rejeté |
| UNION ambiguë avec brouillon d'un autre profil | false | Un id stocké appartient à un seul profil ; UNION dédoublonne. | rejeté |
| Bearer orphelin sans ligne de réglages | low | Fenêtre de plantage ; `clear()` le supprime encore. | rejeté |
| Kotlin (`sessionId`, regex, `show`) sans test | medium | Aucun harnais Android ; seul le canal Dart est simulé. | defer (vérif. réelle 5.5) |
| Réglages du profil non testés via la route | low | Seuls des tests du widget isolé. | patch |
| Contrat `notification-tracking.json` et son test figent l'ancien payload | medium | Interdit en 5.7, prévu en 5.8. | defer |

## Design Notes

Le bouton « Autoriser les notifications » reste : sans lui, rien ne demanderait la permission Android 13+ (seul `enable` le faisait). Plus d'activation par connexion : le plugin décide, l'app partage toujours son jeton.

`target` ne filtre pas par connexion : `resolveLaunchTarget` compare déjà la connexion et les profils et explique sinon.

## Verification

**Commandes :**
- `flutter analyze --no-pub` et `flutter test --no-pub` (Flutter 3.47.7 via `~/fvm/versions/3.47.7`) — aucun échec.

**Vérification manuelle (Alanc, 5.5) :** toucher une notification du plugin app fermée, en arrière-plan, depuis les récents ; notification app ouverte ; profil sans plugin → « Notification non suivie ».
