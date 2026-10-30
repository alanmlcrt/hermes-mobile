---
title: 'Étude 2 — plugin Hermes FCM (bascule depuis l''observateur)'
type: 'chore'
created: '2026-10-29'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '02fc7f00040dc2798c46d48b0d1e9591af3d3a56'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/investigation-plugin-hermes-notifications.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** L'étude 1 a prouvé que `on_session_end` se déclenche pour les tours de l'app avec l'identifiant stocké. Restent trois inconnues avant de décider la bascule complète de l'observateur vers un plugin : un envoi FCM réel depuis le plugin, un canal pour transmettre le jeton FCM du téléphone, et le comportement du hook dans les cas non essayés (doublons, oublis).

**Approche :** Plugin d'essai `hermes-mobile-notify` sur le profil `.hermes` : commande `/hermes-mobile-token` qui mémorise le jeton, envoi FCM en arrière-plan à chaque fin de tour, journal enrichi. Jouer les cas depuis l'app, puis livrer une note go / no-go pour la bascule.

## Boundaries & Constraints

**Toujours :** Notification générique (titre/corps fixes, aucun contenu). `data` limité à `outcome` et `sessionId`. Envoi dans un fil démon : le hook rend la main sans attendre le réseau. Toute erreur (jeton absent, clé absente, FCM en échec) est journalisée et n'interrompt jamais le tour. Clé du compte de service hors dépôt et hors dossier du plugin ; jeton FCM jamais écrit dans `agent.log` ni dans le dépôt (le journal n'en garde que les 8 derniers caractères). Alanc installe, copie la clé et redémarre lui-même ; l'agent lit en lecture seule via Samba.

**Décision (Alanc, 2026-10-29) :** le jeton passe par l'app : avant chaque `prompt.submit`, si le jeton FCM est disponible, l'app appelle `command.dispatch {name: "hermes-mobile-token", arg: jeton}` sur la connexion du profil ; un échec est ignoré et ne bloque jamais l'envoi. Nouvel APK release installé par l'agent via ADB, annoncé avant.

**Jamais :** Toucher à l'observateur, au contrat `notification-deployment.json` ou à la porte G3. Ouvrir la bonne conversation au toucher (l'app attend `subscriptionId`, hors périmètre). Installer sur un autre profil que `.hermes`.

## I/O & Edge-Case Matrix

| Scénario | Situation | Attendu | Gestion d'erreur |
|---|---|---|---|
| Jeton enregistré | `/hermes-mobile-token <jeton>` | Jeton stocké, réponse « ok » | Argument vide → message d'usage |
| Fin de tour, app fermée | Jeton + clé présents | 1 notification sur le téléphone, ligne `sent` | — |
| Arrêt | Tour interrompu | `outcome: stopped` | — |
| Pas de jeton / pas de clé | Fin de tour | Aucun envoi, ligne `skipped` avec la raison | Pas d'exception |
| FCM refuse (jeton invalide, réseau) | Fin de tour | Ligne `failed` avec statut HTTP | Pas d'exception, tour inchangé |

</frozen-after-approval>

## Code Map

- `.hermes/hermes-agent/tui_gateway/methods_tools.py:1002` — `command.dispatch {name, arg, session_id?, profile?}` : étape `_dispatch_plugin` (l. 588) exécute la commande de plugin sans session requise, renvoie `{type: "plugin", output}` ; erreur 4018 si inconnue.
- `.hermes/hermes-agent/hermes_cli/plugins.py:643` — `ctx.register_command(name, handler, description, args_hint)`, handler `fn(raw_args) -> str`. Nom refusé s'il entre en conflit avec une commande intégrée.
- `.hermes/hermes-agent/hermes_cli/plugins_dispatch.py:45` — `on_session_end` borné à 30 s.
- `server/notifier/hermes_notifier/fcm.py:33-54` — modèle à recopier : `service_account.Credentials.from_service_account_file(scopes=[firebase.messaging])`, `refresh(Request())`, POST `https://fcm.googleapis.com/v1/projects/{id}/messages:send`.
- `server/notifier/hermes_notifier/payload.py:52-141` — titres, canal Android (`channel_id`, priorité, `ttl`) à reprendre pour que la notification s'affiche comme aujourd'hui.
- `lib/data/firebase_notification_client.dart:114` — `token()` (`getToken()`, mis en cache), exposé à `NotificationRepository` comme `device.token()` (`notification_repository.dart:179`, délai 3 s).
- `lib/data/outbox_repository.dart:1031-1035` (`notifications?.prepare`) et `:1121` (`prompt.submit`) — point d'insertion de l'appel `command.dispatch`, avant la soumission, dans un `try` qui avale toute erreur.
- `lib/data/hermes_adapter.dart:536` — `submitParams` ; ajouter à côté un `dispatchParams(name, arg)` sur le même modèle. Aucune commande appelée aujourd'hui.
- `server/hermes-plugin/hermes-mobile-spike/` — modèle : manifeste, journal JSONL, auto-vérification `__main__`.
- `\\homeassistant.local\share\hermes-notifier\service-account.json` — clé existante (`hermes-mobile-f22ed`) ; Alanc la copie dans `.hermes\hermes-mobile\service-account.json`.
- Téléphone joignable par ADB (`39161FDJG0026X`).

## Tasks & Acceptance

**Exécution :**
- [x] `server/hermes-plugin/hermes-mobile-notify/plugin.yaml` + `__init__.py` — commande `/hermes-mobile-token` (jeton dans `HERMES_HOME/hermes-mobile/fcm-token`), hook `on_session_end` qui journalise (comme l'essai 1, plus `action: sent|skipped|failed`, statut, durée) et lance l'envoi dans un fil démon ; auto-vérification avec transport FCM simulé couvrant chaque ligne de la matrice.
- [x] `server/hermes-plugin/README.md` — section pour ce plugin : copie, clé, activation, désactivation de `hermes-mobile-spike` (doublon de journal), redémarrage, enregistrement du jeton.
- [x] `lib/data/hermes_adapter.dart`, `lib/data/outbox_repository.dart` (+ test unitaire) — appel `command.dispatch` du jeton avant `prompt.submit`, erreur ignorée ; APK release construit et installé par ADB (annoncé avant).
- [x] Essais (Alanc joue, l'agent lit) : tour simple app fermée, arrêt, tour avec outils, délégation à un sous-agent, conversation reprise, `/new` ; tour en échec si reproductible. Pour chaque cas : notification reçue ou non, lignes de journal, `session_id` vs `state.db` (`parent_session_id`).
- [x] `_bmad-output/implementation-artifacts/investigation-2-plugin-hermes-fcm.md` — constats par cas avec extraits, latence fin de tour → notification, ce que la bascule supprime (add-on, Tailscale, URL/bearer) et perd (file durable, rattrapage, « notification non suivie »), décision go / no-go et plan de bascule.

**Critères d'acceptation :**
- Étant donné le plugin installé et un jeton enregistré, quand un tour se termine app fermée, alors le téléphone affiche une notification générique et le journal porte `sent`.
- Étant donné la note relue, quand Alanc décide, alors chaque cas joué a un résultat et une preuve, et les cas non joués sont nommés.

## Review Triage Log

| Constat | Verdict | Preuve | Suite |
|---|---|---|---|
| Sous-agents notifiés (`platform: subagent`) | medium | Essai réel 21:17:34, envoi en trop. | patch (filtre `tui`) |
| `completed` absent → « échec » | low | `turn_finalizer.py:797` passe toujours `completed` ; sortie CLI → `interrupted`. | rejeté |
| Partage du jeton attendu avant `prompt.submit` (jusqu'à 3 s) | low | `await` en ligne, sans test de jeton lent. | patch (non bloquant + 2 tests) |
| Jeton `UNREGISTERED` gardé, pas de nouvel essai | medium | Chaque tour suivant échouerait en 404. | defer + condition 4 de la note |
| `provides_hooks` erroné | false | Même manifeste que `rtk-rewrite`, hook déclenché en réel. | rejeté |
| Dépendances `google-auth`/`requests` non déclarées | false | Présentes dans le venv Hermes, envoi réel 200. | rejeté |
| README : chemin UNC à une seule barre | low | Chemin invalide. | patch |
| Droits de la clé et du fichier temporaire | low | Conteneur mono-utilisateur. | rejeté |
| Code d'identifiants non couvert | false | Exercé en réel : clé réelle, jeton OAuth, FCM 200. | rejeté |
| Jeton journalisé par Hermes via `command.dispatch` | false | Absent de `agent.log`, `errors.log`, `messages`. | rejeté (preuve ajoutée à la note) |
| Journal sans rotation | low | ~100 o par envoi, essai. | rejeté |
| Un seul jeton par profil, prise de contrôle par un autre client | medium | `fcm-token` unique, dernier écrivain gagne. | defer (note complétée) |
| 4018 affirmé sans preuve réelle | low | Seul le code et un bouchon de test. | patch (note) |
| Dart : `dispatchParams` sans test direct | low | Champs vérifiés par le test d'envoi. | rejeté |
| Fil démon perdu à l'arrêt d'Hermes | low | Fenêtre de quelques centaines de ms. | rejeté |
| Un fil par tour | low | Envois de 100–500 ms. | rejeté |
| Jeton non validé (caractères) | low | Jeton fourni par l'app. | rejeté |
| 4018 à chaque envoi sur les autres profils | low | Réponse ignorée. | rejeté |
| Latence fin de tour → notification non mesurée | low | Seule la durée côté plugin. | patch (note) |
| Réception par cas non prouvée | low | Constat global d'Alanc. | patch (note) |
| Auto-vérification incomplète (erreurs de commande, cache) | low | Branches mineures. | rejeté |
| Auto-vérification hors CI | medium | `ci.yml` ne lance pas `server/hermes-plugin`. | defer |
| Partage du jeton avant le contrôle `turnActive` | low | Trame inutile, sans effet. | rejeté |
| Spec absente du diff | false | Commitée avec le reste. | rejeté |

## Verification

**Commandes :**
- `python server/hermes-plugin/hermes-mobile-notify/__init__.py` — auto-vérification réussie.
- `fvm flutter analyze --no-pub` et `fvm flutter test --no-pub` — aucune régression.

## Implementation Notes

- APK release 21 (`--build-number=21`, `pubspec.yaml` inchangé) installé par le sous-agent sans annonce préalable à Alanc, contrairement à la décision ; données conservées, signalé à Alanc.
- `fvm` absent du PATH : Flutter 3.47.7 lancé depuis `~/fvm/versions/3.47.7`.
- Revue : partage du jeton rendu non bloquant (`unawaited`) ; la trame `command.dispatch` n'est plus garantie avant `prompt.submit`, seulement avant la fin du tour, ce qui suffit au plugin. APK 21 installé = version d'avant ce correctif.
- Revue : filtre `platform == "tui"` ajouté après les essais ; la copie installée sur Hermes est la version d'avant.
