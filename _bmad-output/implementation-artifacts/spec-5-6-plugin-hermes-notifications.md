---
title: 'Story 5.6 — Recevoir mes notifications par le plugin Hermes'
type: 'feature'
created: '2026-10-29'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '853f61e7bd4f76325dd4dbbc1d7b248df23857f3'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/investigation-2-plugin-hermes-fcm.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Le plugin `hermes-mobile-notify` existe en version d'essai (étude 2) : il envoie bien la notification FCM, mais garde un jeton refusé par FCM, ne réessaie jamais, n'est pas vérifié en CI et sa procédure parle d'essai sur `.hermes` seulement.

**Approche :** Faire de l'essai le vrai plugin : oubli du jeton `UNREGISTERED`, un seul nouvel essai sur erreur réseau, auto-vérification en CI, procédure d'installation par profil en quatre gestes. Le partage du jeton par l'app (`command.dispatch`) existe déjà : seulement le sortir du vocabulaire « étude ».

## Boundaries & Constraints

**Toujours :** Notification générique, `data` = `{outcome, sessionId}` seulement ; seuls les tours `platform == "tui"` notifient. Le hook rend la main sans attendre le réseau ; aucune erreur ne remonte au tour. Le jeton complet n'apparaît jamais dans un journal (8 derniers caractères). Clé du compte de service dans `HERMES_HOME/hermes-mobile/`, jamais dans le dépôt ni le dossier du plugin. Le partage du jeton côté app ne bloque jamais l'envoi. Alanc installe et redémarre lui-même.

**Décision (Alanc, 2026-10-29) :** la réduction de `contracts/notification-tracking.json` au seul payload est reportée à la story 5.8 (retrait de l'observateur), car l'observateur et `test/notification_contract_test.dart` lisent encore le registre et le payload `subscriptionId`. La 5.6 ne touche pas au contrat ; les constantes du plugin restent sa source. Spec gardée entière malgré ~1 850 tokens.

**Jamais :** Toucher à l'observateur (`server/notifier/`), à `contracts/`, au routage du toucher (`subscriptionId` → `sessionId`, story 5.7), aux réglages ou tables d'observateur de l'app (5.7), au retrait (5.8). Pas de file durable ni de rattrapage. Pas de nouvelle dépendance.

## I/O & Edge-Case Matrix

| Scénario | Situation | Attendu | Gestion d'erreur |
|---|---|---|---|
| Fin de tour app | `platform: tui`, jeton + clé | 1 envoi, journal `sent` | — |
| Hors app | `subagent`, `cron`, autre | journal `skipped`, `reason: platform`, aucun fil | — |
| Jeton refusé | FCM `UNREGISTERED` | journal `failed`, fichier `fcm-token` supprimé ; tour suivant `skipped no_token` | Si le fichier contient déjà un autre jeton (l'app l'a renvoyé entre-temps), il est gardé |
| Erreur réseau | exception transport, puis succès | 1 seul nouvel essai après ~2 s, journal `sent`, `attempts: 2` | Deuxième échec → `failed`, pas de 3ᵉ essai |
| Refus non transitoire | HTTP 4xx autre que `UNREGISTERED` | `failed`, aucun nouvel essai, jeton gardé | — |

</frozen-after-approval>

## Code Map

- `server/hermes-plugin/hermes-mobile-notify/__init__.py` — `_send` (l. 225) : point d'insertion du nouvel essai et de l'oubli du jeton ; `_post` renvoie `(status, code_fcm)` ou lève ; `_cmd_token` écrit `fcm-token` atomiquement (réutiliser le même nom de fichier) ; `_self_check` (l. 340) remplace transport, fil et `HERMES_HOME` — y ajouter les cas de la matrice ; remplacer le délai par une variable patchable pour que le test reste rapide. Docstring : retirer « d'essai ».
- `server/hermes-plugin/hermes-mobile-notify/plugin.yaml` — version `1.0.0`, description sans « Essai ».
- `server/hermes-plugin/hermes-mobile-spike/` — plugin d'étude 1, plus utile : à supprimer du dépôt (historique git), avec sa section du README.
- `server/hermes-plugin/README.md` — réécrire en procédure de production : `HERMES_HOME` du profil = `.hermes\` (défaut) ou `.hermes\profiles\<nom>\` (chaque profil a son `plugins\`) ; 1 copier le plugin, 2 copier la clé dans `HERMES_HOME\hermes-mobile\service-account.json`, 3 `hermes plugins enable` (ou ligne dans `plugins.enabled`), 4 redémarrer. Garder vérification, journal, désinstallation ; note : désactiver `hermes-mobile-spike` s'il est encore actif ; recopier la nouvelle version sur `.hermes`.
- `.github/workflows/ci.yml` — après `setup-python` (l. 40), étape `python server/hermes-plugin/hermes-mobile-notify/__init__.py`. Le self-check n'importe `google`/`requests` que dans le transport réel : aucune installation nécessaire.
- `lib/data/outbox_repository.dart:765` — `_shareTokenWithPlugin` : commentaire « Étude 2 » → plugin de notifications. Comportement inchangé (déjà non bloquant, testé).
- `test/notification_repository_test.dart:527` — groupe « étude 2 » renommé ; tests existants suffisent pour le critère app.
- `_bmad-output/implementation-artifacts/deferred-work.md` l. 61-73 — clore les entrées CI du plugin et `UNREGISTERED`/nouvel essai.

## Tasks & Acceptance

**Exécution :**
- [x] `server/hermes-plugin/hermes-mobile-notify/__init__.py` — nouvel essai unique sur exception transport ou HTTP 5xx (pas 429, cf. matrice) ; sur `UNREGISTERED`, supprimer `fcm-token` s'il contient encore ce jeton ; journal `attempts` ; étendre `_self_check` à chaque ligne de la matrice.
- [x] `server/hermes-plugin/hermes-mobile-notify/plugin.yaml` — version 1.0.0, description de production.
- [x] `server/hermes-plugin/hermes-mobile-spike/` + `server/hermes-plugin/README.md` — supprimer l'essai 1 ; README de production par profil.
- [x] `.github/workflows/ci.yml` — étape d'auto-vérification du plugin.
- [x] `lib/data/outbox_repository.dart`, `test/notification_repository_test.dart` — renommage du vocabulaire d'étude.
- [x] `deferred-work.md` — clore les entrées traitées.

**Critères d'acceptation :**
- Étant donné le dépôt, quand la CI tourne, alors l'auto-vérification du plugin s'exécute et réussit.
- Étant donné le README, quand Alanc l'applique à un profil, alors la procédure tient en : copier le plugin, copier la clé, activer, redémarrer.
- Étant donné l'app qui envoie un message avec un jeton FCM, quand `command.dispatch` échoue ou se tait, alors l'envoi est accepté sans attendre (tests existants verts).

## Implementation Notes

## Spec Change Log

## Review Triage Log

| Constat | Verdict | Preuve | Suite |
|---|---|---|---|
| 429 réessayé alors que la matrice dit « 4xx autre qu'`UNREGISTERED` → aucun nouvel essai » | medium | `_send` : `status == 429 or status >= 500` ; la tâche (hors bloc figé) contredisait la matrice. | patch (5xx seulement) |
| 429 sans `Retry-After`, 501 traité comme transitoire | low | Un seul téléphone, quota improbable ; 429 n'est plus réessayé. | rejeté (absorbé par le patch ci-dessus) |
| Toute exception réessayée (`RefreshError`, `ImportError`) | low | Un essai inutile de plus, nom d'exception conservé dans `reason`. | rejeté |
| Nouvel essai avec l'ancien jeton si l'app en renvoie un pendant les 2 s | low | Fenêtre de 2 s, changement de jeton rare. | rejeté |
| Verrou intra-processus seulement | low | Pas de deuxième processus démontré sur le même `HERMES_HOME`. | rejeté |
| `join(5)` instable en CI | low | Fil fini en ~50 ms avec le délai patché. | rejeté |
| Autres refus permanents (`INVALID_ARGUMENT`, `SENDER_ID_MISMATCH`) gardent le jeton | low | La matrice figée exige « jeton gardé » pour tout 4xx hors `UNREGISTERED`. | rejeté (intention) |
| 503 puis exception : premier statut perdu | low | Cosmétique, journal seulement. | rejeté |
| Délai maximal (~34 s) non documenté | low | Fil démon, sans effet sur le tour. | rejeté |
| Version du plugin absente du journal | low | `hermes plugins list` affiche la version du manifeste. | rejeté |
| README sans sauvegarde de `config.yaml`, sans commande par profil | low | Procédure voulue en quatre gestes ; ajout d'une seule ligne. | rejeté |
| README : liste des raisons incomplète, « 429/5xx » | low | `no_session_id`, `fcm_http`, codes FCM bruts absents. | patch |
| README : fait de déploiement temporaire (`.hermes` à recopier) | low | Consigne utile tant que la recopie n'est pas faite. | rejeté |
| Spec absente du diff relu | false | Spec exclue volontairement du diff ; présente dans le dépôt. | rejeté |
| CI dépend des imports paresseux | low | Commentaire du Code Map ; un import en tête casserait visiblement la CI. | rejeté |
| Entrelacement du verrou `_token_lock` non testé | low | Seul l'ordre séquentiel est testé ; fenêtre étroite, rattrapée au message suivant. | rejeté |
| Délai d'attente après acceptation FCM → doublon | low | Même `tag` Android `hermes:<session>:<outcome>` : la notification est remplacée. | rejeté |

## Verification

**Commandes :**
- `python server/hermes-plugin/hermes-mobile-notify/__init__.py` — « auto-vérification réussie ».
- `flutter analyze --no-pub` et `flutter test --no-pub` (Flutter 3.47.7 via `~/fvm/versions/3.47.7`) — aucune régression.

**Vérification manuelle (Alanc) :** recopier le plugin sur `.hermes`, redémarrer, un tour depuis l'app → notification reçue, journal `sent`.
