---
title: 'Story 5.4 - Ouvrir la bonne conversation depuis une notification'
type: 'feature'
created: '2026-10-27'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'd10fe1359504be9ddf53a148c4c7331ff29b1a91'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** La 5.3 affiche la notification de fin, mais la toucher ouvre l’app sur l’écran courant ou l’accueil. Alanc doit chercher la conversation concernée.

**Approche :** Transmettre au toucher le seul `subscriptionId` de la notification, le résoudre localement grâce aux associations de suivi conservées en 5.3, puis laisser `resolveLaunchTarget()` ouvrir `/c/<ConnectionKey>/<ProfileKey>/<SessionKey>` en priorité. La conversation se recharge depuis Hermes ; une cible absente est expliquée puis l’accueil s’ouvre.

## Boundaries & Constraints

**Toujours :** Priorité notification, puis restauration, puis accueil. Couvrir l’ouverture à froid (app tuée) et à chaud (arrière-plan, `singleTop`), pour les notifications affichées par FCM comme pour celles affichées par l’app au premier plan. Valider le `subscriptionId` (même expression que 5.3) avant toute lecture. La notification n’est qu’un indice : aucune donnée de conversation n’est lue dans le push ; l’état vient de Hermes après réauthentification. Si l’authentification n’est pas encore rétablie, la cible attend, puis s’ouvre après connexion. Une cible inconnue, d’une autre connexion, sans session stockée ou d’un profil absent est expliquée par un message accessible, puis l’accueil s’ouvre. Chaque toucher n’est consommé qu’une fois.

**Jamais :** Ouvrir le fil courant ou un autre fil à la place de la cible. Mettre du contenu, un chemin ou un secret dans l’intent, les journaux ou le message. Modifier les contrats, le payload serveur ou le schéma SQLite. Envoyer un vrai push ou annoncer G3 franchie (5.5).

## I/O & Edge-Case Matrix

| Cas | Entrée | Résultat | Échec |
|---|---|---|---|
| Froid | Toucher, app tuée, association connue | Conversation ouverte après restauration | Restauration échouée : cible gardée jusqu’à la reconnexion |
| Chaud | Toucher, app en arrière-plan | Conversation ouverte, même depuis un autre fil | — |
| Premier plan | Toucher d’une notification affichée par l’app | Même résultat que FCM | — |
| Cible absente | Id inconnu, autre connexion, session nulle, profil disparu | Message explicatif puis accueil | Fil affiché jamais réutilisé |
| Id invalide | Extra malformé ou absent | Ignoré, lancement habituel | — |

</frozen-after-approval>

## Code Map

- `android/app/src/main/kotlin/fr/hermes_mobile/MainActivity.kt` — canal `hermes/notifications` ; `show` construit la notification sans `contentIntent`. FCM place le bloc data en extras de l’intent du lanceur au toucher : un seul mécanisme natif (extras `subscriptionId`) couvre les deux origines.
- `android/app/src/main/AndroidManifest.xml` — activité déjà `singleTop` : le toucher à chaud passe par `onNewIntent`.
- `lib/data/firebase_notification_client.dart` — possède le canal ; `initialize()` avale les échecs Firebase : le routage doit fonctionner même sans Firebase.
- `lib/models/notifications.dart` — interface `NotificationClient` (implémentée aussi par les faux des tests).
- `lib/data/notification_repository.dart` — table `notification_subscriptions` (`connection_key`, `profile_key`, `stored_session_id` = `SessionKey` de la route ; `session_id` est l’id runtime, à ne pas utiliser). Lignes jamais supprimées, états `expired`/`revoked` restent des indices valides.
- `lib/app/routes.dart` — `resolveLaunchTarget()` (aucune restauration de route n’existe aujourd’hui : priorité notification puis accueil), `conversationPath()`, listener `_onProfiles` qui détecte le retour d’authentification, redirect qui refuse `/c/` d’une autre connexion.
- `lib/main.dart` — `MaterialApp.router` ; y brancher le `scaffoldMessengerKey` et la cible initiale.
- `lib/ui/content.dart` — libellés ; ajouter le message de cible absente.
- Tests existants à étendre : `test/main_app_test.dart`, `test/notification_repository_test.dart`, `test/firebase_notification_client_test.dart`.

## Tasks & Acceptance

**Exécution :**
- [x] `MainActivity.kt` — `contentIntent` (PendingIntent immuable vers l’activité, extra `subscriptionId`, requestCode distinct par tag) ; méthode `takeOpened` qui consomme l’extra validé de l’intent de lancement ; `onNewIntent` : `setIntent` et `invokeMethod("opened", id)`.
- [x] `lib/models/notifications.dart`, `lib/data/firebase_notification_client.dart` — `Stream<String> opened` et `Future<String?> takeOpened()` ; handler du canal installé avant `Firebase.initializeApp` ; validation de l’id côté Dart.
- [x] `lib/data/notification_repository.dart` — `target(String subscriptionId)` renvoyant connexion, profil et session stockée, ou `null`.
- [x] `lib/app/routes.dart` — paramètre notification dans `resolveLaunchTarget()` (cible valide → `conversationPath`, sinon rappel d’explication et `/`) ; `AppRoutes.openNotification(id)` : cible en attente tant que non authentifié, consommée une fois au retour d’authentification ; `scaffoldMessengerKey`.
- [x] `lib/main.dart`, `lib/ui/content.dart` — écoute de `opened`, lecture de `takeOpened()` au démarrage, message accessible.
- [x] `test/notification_open_test.dart` — matrice : froid avec restauration différée, chaud depuis un autre fil, cible absente (quatre causes), id invalide, consommation unique ; `target()` sur SQLite en mémoire.

**Critères d’acceptation :**
- Étant donné une cible valide et une app authentifiée, quand la notification est touchée, alors la route `/c/<ConnectionKey>/<ProfileKey>/<SessionKey>` est affichée et la conversation se charge via l’outbox/Hermes, sans lire le push.
- Étant donné un toucher pendant que la restauration est en cours ou échoue, quand l’authentification revient, alors la cible s’ouvre une seule fois.
- Étant donné une cible absente, quand le message s’affiche, alors il est annoncé au lecteur d’écran et l’accueil remplace le fil courant.

## Implementation Notes

Implémentation par extras natifs `subscriptionId` (FCM et `show`), `takeOpened`/`opened` sur le canal, `NotificationRepository.target()` sur `stored_session_id`, cible en attente dans `AppRoutes.openNotification` jusqu’à authentification et profils chargés, SnackBar via `scaffoldMessengerKey`. Aucune migration ni changement de contrat.

## Spec Change Log

## Review Triage Log

| Réf. | Verdict | Preuve et traitement |
|---|---|---|
| B1/E2 | low | Course entre `_openPending` et le retour à l’accueil : la cible n’est résolue qu’après chargement des profils (réseau), bien après `onAuthenticated`/`_refresh.ping` ; improbable, garde supplémentaire — rejeté. |
| B2/E1 | medium | `profilesState == error` consomme la cible et affiche « introuvable ». Patch : attendre `ready`/`empty`/`refreshing`, test ajouté. |
| B3/E5 | low | Erreur SQLite traitée comme cible absente ; base locale rarement en échec, distinction = nouvelle branche — rejeté. |
| B4 | false | Session supprimée côté serveur : l’intention vise une cible absente « localement » ; le chargement en échec reste géré par `ContinuationView`. |
| B5/E7 | false | `notImplemented`/`error` impossibles une fois `initState` passé : le handler Dart est posé dès la construction du client et répond `null` ; avant, `setIntent` laisse l’extra à `takeOpened`. |
| B6/E3 | low | Deux touchers concurrents : ordre de `router.go` non garanti ; improbable, compteur à ajouter — rejeté. |
| B7/E10 | low | Collision de `hashCode` entre tags : probabilité négligeable — rejeté. |
| B8 | low | Commentaire FCM : comportement documenté de FCM (data en extras de l’intent du lanceur) ; vérifié en 5.5 — rejeté. |
| B9/V3 | low | Faux `Device` diffusé vs contrôleur simple réel ; `main.dart` écoute immédiatement — rejeté. |
| B10/V1 | medium | Chemin natif sans test (pas de harnais Android) — reporté, essais téléphone 5.5 (`deferred-work.md`). |
| B11 | low | Import de `Device` depuis un autre fichier de test : sans effet à l’exécution — rejeté. |
| B12 | low | Paramètre `outbox` inutilisé dans la branche notification — cosmétique, rejeté. |
| E4 | false | `stored_session_id` vient de `session.create` Hermes, jamais vide. |
| E6 | false | La résolution attend authentification et profils chargés, donc après le premier build de `MaterialApp` ; la clé est attachée. |
| E8 | low | Recréation d’activité hors `configChanges` rejouant l’intent : rare (les changements courants sont déclarés) — rejeté. |
| E9 | false | Un seul client en production ; seuls les tests en créent plusieurs. |
| E11 | low | Toucher sur la conversation déjà affichée : `go` sans effet, mais la reprise au premier plan resynchronise (2.4) — rejeté. |
| V2 | medium | Branche `_pendingNotification ??= id` jamais exercée. Patch : test avec `Completer` et perte d’authentification. |

## Design Notes

Extras natifs plutôt que `getInitialMessage`/`onMessageOpenedApp` : ces API ignorent les notifications affichées par l’app au premier plan ; les extras couvrent les deux cas avec un seul chemin, et restent disponibles sans Firebase configuré.

## Verification

**Commandes :**
- `flutter analyze --no-pub` — aucune anomalie.
- `flutter test --no-pub` — aucune régression, nouveaux tests verts.
- `flutter build apk --debug` — Kotlin compile.

**Vérification manuelle :** essais téléphone réels reportés à 5.5.

**Résultats finaux après revue :** `flutter analyze` sans anomalie ; 501 tests Flutter réussis, 17 ignorés (préexistants) ; APK debug compilé. Aucun push réel ; G3 reste ouverte (5.5).
