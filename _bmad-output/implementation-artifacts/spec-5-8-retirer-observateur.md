---
title: 'Story 5.8 — Retirer l''observateur'
type: 'chore'
created: '2026-10-30'
status: 'done'
baseline_commit: 'db5dca26ec6a60678118f808a35edced6391b453'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** L'app parle au plugin depuis la 5.7, mais le dépôt porte encore l'add-on Notifier (`server/notifier/`, `repository.yaml`, trois étapes CI, contrat de déploiement, docs) et un contrat de suivi + test qui figent l'ancien payload `{subscriptionId, outcome}`, à l'opposé de ce que l'app accepte.

**Approche :** Supprimer tout le chemin observateur du dépôt ; réduire `contracts/notification-tracking.json` au seul payload du plugin (titres, canal, `outcome`, `sessionId`) et réécrire son test pour qu'il vérifie l'accord contrat ↔ plugin ↔ Android ; réécrire les docs ; clore les reports propres à l'observateur. Le retrait Home Assistant / Tailscale reste fait par Alanc (proposition, section 6).

## Boundaries & Constraints

**Toujours :** Les migrations SQLite existantes (dont celles qui citent l'observateur) restent intactes ; le commentaire d'héritage de `SecretUsage.observerBearer` reste. Les tests qui vérifient l'*absence* de l'observateur (`notification_settings_test`, migration de purge, payload `subscriptionId` ignoré) restent. Les étapes CI du plugin et de `tool/` restent (donc `setup-python`).

**Jamais :** Toucher le code Dart de `lib/` ou Android (sauf si le test d'accord révèle un écart réel). Modifier les artefacts de planification ou de stories passées. Agir sur Home Assistant ou Tailscale.

</frozen-after-approval>

## Code Map

- `server/notifier/` — à supprimer entièrement (code, tests, vendor, DOCS.md, Dockerfile).
- `repository.yaml` — dépôt d'add-ons HA, à supprimer.
- `contracts/notification-deployment.json` — à supprimer ; seul lecteur : `test/notification_contract_test.dart`.
- `.github/workflows/ci.yml` — supprimer « Contrats vendorisés du notifier », « Tests du notifier », « Image du notifier » (et son commentaire).
- `.gitignore:42-48` — retirer `server/notifier/**/*.sqlite3*` ; renommer le titre `# Python (notifier)` en `# Python` et garder les règles génériques (plugin, `tool/`).
- `contracts/notification-tracking.json` — garder `schemaVersion` (→ 2) et `payload` réduit : `transport`, `platforms`, `messageKind`, `dataFields: ["outcome","sessionId"]`, `dataValueType`, `outcomeValues`, `notification.{title, bodyByOutcome}`, `android.{channelId, priority, ttlSeconds, notificationTagTemplate "hermes:{sessionId}:{outcome}", collapseKeyTemplate "hermes:{sessionId}"}`, `forbiddenDataFields` (sans `sessionId`), `maxBytes`, `note`. Tout le reste (registre, endpoints, auth, santé, rattrapage, terminals…) disparaît.
- `test/notification_contract_test.dart` (1408 l.) — réécrire court : champs `data` exactement `{outcome, sessionId}`, issues = celles de `event-mapping.json` notifiables (`succeeded/failed/stopped`) ; titres, libellés, canal, TTL, tag et collapse key égaux aux constantes de `server/hermes-plugin/hermes-mobile-notify/__init__.py` (`_TITLE`, `_BODIES`, `_CHANNEL`, `_TTL`, `_payload`) ; libellés et canal présents dans `MainActivity.kt` et `AndroidManifest.xml` ; aucun champ interdit, aucun TBD/secret (réutiliser `_scanContractValue`/`_expectNoPersonalText` existants).
- `server/hermes-plugin/hermes-mobile-notify/__init__.py:41` — commentaire « Repris de contracts/notification-tracking.json » reste vrai.
- `contracts/README.md:220-302` — section « Suivi et déploiement de l'observateur (story 5.1) » remplacée par une courte section « Payload des notifications (plugin) » : rôle du fichier, `{outcome, sessionId}`, commande de test.
- `README.md:1-13` — paragraphe observateur remplacé : notifications via le plugin Hermes (lien `server/hermes-plugin/README.md`), « notification non suivie » si plugin absent ; reprendre de `server/notifier/DOCS.md` §15 la note Android (`android/app/google-services.json` non versionné, plugin Gradle appliqué seulement s'il existe, sinon « Firebase non configuré »).
- `server/hermes-plugin/README.md:44,61-63` — retirer la source `\\homeassistant.local\share\hermes-notifier\…` et le paragraphe des doubles notifications.
- `_bmad-output/implementation-artifacts/deferred-work.md` — supprimer les entrées 5-2 (montage `fcm_service_account`, abonnements multiples), 5-4 (extra natif `subscriptionId`), 5-6 et la 2ᵉ de 5-7 (contrat/test du payload). Garder 5-7 Kotlin et étude-2 (plusieurs téléphones).

## Tasks & Acceptance

**Exécution :**
- [x] `server/notifier/`, `repository.yaml`, `contracts/notification-deployment.json` — `git rm -r`.
- [x] `.github/workflows/ci.yml`, `.gitignore` — retirer le notifier.
- [x] `contracts/notification-tracking.json`, `test/notification_contract_test.dart` — contrat du payload plugin et test d'accord.
- [x] `contracts/README.md`, `README.md`, `server/hermes-plugin/README.md` — docs.
- [x] `deferred-work.md` — clore les reports observateur.

**Critères d'acceptation :**
- Étant donné le dépôt, quand `grep -rnE "server/notifier|hermes-notifier|hermes_notifier|subscriptionId|[Oo]bservateur|observerBearer|notification-deployment" lib android/app/src contracts .github README.md .gitignore server test` tourne, alors seuls apparaissent `lib/data/storage/migrations.dart`, `lib/data/storage/secret_store.dart`, `test/notification_repository_test.dart` (purge), `test/notification_settings_test.dart` (absence) et `test/firebase_notification_client_test.dart` (payload `subscriptionId` rejeté).
- Étant donné une divergence entre contrat et plugin (libellé, canal, champ `data`), quand `flutter test` tourne, alors le test de contrat échoue.
- Étant donné Home Assistant et Tailscale, quand Alanc suit la section 6 de `sprint-change-proposal-2026-10-29.md`, alors l'add-on, son dépôt, `/share/hermes-notifier/` et `svc:hermes-notifier` n'existent plus.

## Implementation Notes

## Spec Change Log

## Review Triage Log

| Constat | Verdict | Preuve | Suite |
|---|---|---|---|
| `maxBytes` testé avec un `sessionId` de 64 car. au lieu de 256, sans jeton ni enveloppe `message` (3 relecteurs) | low | 256 car. ×3 → ~1030 o > 1024 ; ids réels de 22 car. | patch (échantillon complet, `maxBytes` 2048) |
| Clé du toucher `EXTRA_SESSION` non vérifiée (2 relecteurs) | medium | `MainActivity.kt:95` ; le test ne lit que `argument<String>` (chemin `show`) | patch |
| Client Dart (`firebase_notification_client.dart`) non relié au contrat | low | Clés et issues codées en dur l. 56-58 | patch |
| `subscriptionId` absent de `forbiddenDataFields` | low | Clé retirée, rejetée par le client ; l'ajouter casse le critère grep figé | rejeté (patch annulé) |
| `README.md` non scanné pour texte personnel | low | Le scan refuse l'exemple légitime `C:/Users/<utilisateur>/…` de `key.properties` | rejeté (patch annulé) |
| Obtention de la clé Firebase plus documentée après suppression de `DOCS.md` §15 | medium | README du plugin dit seulement « déjà installée » | patch |
| Suivi des récents / `takeOpened` perdu avec le report 5-4 (2 relecteurs) | low | Le report 5-7 restant ne cite que froid/chaud/`show` | defer |
| `substring(-1)` / `_pyBlock` sans garde → RangeError | low | Échec bruyant, pas silencieux | rejeté |
| Kotlin : branches en plus non détectées (contains seul) | low | Garde ajoutée pour un cas non observé | rejeté |
| Terminal sans `statusMap` ni `workState` ignoré | low | Aucun tel événement dans `event-mapping.json` | rejeté |
| `_outcome()` du plugin non relié à `outcomeValues` | low | L'auto-vérification du plugin couvre les issues | rejeté |
| `notification_priority` et `sound` hors contrat | low | Champs non routants, couverts par l'auto-vérification | rejeté |
| Format de `sessionId` absent du contrat | low | Règle dans Dart et Kotlin ; hors intention | rejeté |
| `payloadFn` court jusqu'à la fin du fichier ; `_pyBlock` coupe au premier `}` | low | Forme actuelle correcte ; fragilité acceptée (Design Notes) | rejeté |
| `provenance` et `schemaVersion` 2 non expliqués | low | Spec : payload seul | rejeté |
| Doubles notifications possibles tant que l'add-on tourne | false | Depuis 5.7 l'app n'enregistre plus d'abonnement : l'observateur ne notifie rien | rejeté |
| Aucun doc ne pointe vers le retrait HA/Tailscale | low | Proposition, section 6 ; tâche manuelle ponctuelle | rejeté |
| Vérif. du canal Kotlin liée au nom `val channel` | low | Cosmétique | rejeté |

## Design Notes

Le test lit `__init__.py` en texte (regex sur les constantes) plutôt que d'importer Python : il reste dans `flutter test`, sans nouvel outil. L'auto-vérification Python du plugin reste en CI pour le comportement.

## Verification

**Commandes :**
- `fvm flutter analyze --no-pub` et `fvm flutter test --no-pub` — aucun échec.
- `python server/hermes-plugin/hermes-mobile-notify/__init__.py` — auto-vérification OK.
- Le grep du premier critère — seulement les exceptions listées.

**Vérification manuelle (Alanc) :** section 6 de la proposition (add-on désinstallé, dépôt retiré, `/share/hermes-notifier/` supprimé, `svc:hermes-notifier` supprimé dans l'add-on et la console Tailscale).
