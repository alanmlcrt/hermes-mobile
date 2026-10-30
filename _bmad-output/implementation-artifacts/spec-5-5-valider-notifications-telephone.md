---
title: 'Story 5.5 - Valider les notifications sur mon téléphone'
type: 'chore'
created: '2026-10-27'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'e0d65e37066bc6fc553b5ba2603a9672b10e93cc'
context:
  - '{project-root}/server/hermes-plugin/README.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Le plugin `hermes-mobile-notify` 1.0.0 et l'app basculée sur `sessionId` (5.6–5.8) ne sont prouvés que par tests ; la porte G3 reste ouverte.

**Approche :** Installer le plugin 1.0.0 sur `.hermes`, installer l'APK release sur le téléphone d'Alanc, jouer les scénarios ci-dessous, consigner les preuves dans `rapport-g3.md`, corriger les défauts bloquants (code + test) et déclarer G3 franchie ou remonter les écarts.

## Boundaries & Constraints

**Toujours :** Essais réels uniquement ; aucune simulation ne compte comme preuve. Preuves sans contenu conversationnel, jeton (au-delà de `token_tail`), clé ni chemin privé. Chaque action externe (installation APK, demande de redémarrage) est annoncée avant exécution. Alanc installe/active le plugin et redémarre Hermes lui-même ; l'agent lit journaux et Samba en lecture seule. Un défaut trouvé est corrigé dans le code avec un test, ou consigné comme écart.

**Jamais :** Déclarer G3 franchie avec un scénario manquant ou échoué. Promettre une livraison exactement une fois. Ajouter file durable ou rattrapage.

## I/O & Edge-Case Matrix

| Scénario | Situation | Attendu | Preuve |
|---|---|---|---|
| App fermée | Envoi puis app tuée (balayage) | ≥1 notification, toucher ouvre la conversation | Capture + `session-end.jsonl` `action: sent` |
| Coupure réseau | Mode avion pendant le travail, retour après la fin | ≥1 notification après reconnexion | Idem |
| Arrêt | Travail arrêté depuis l'app, app quittée | Notification « arrêté » (`stopped`) | Idem |
| Sous-agent | Tour qui délègue à un sous-agent | Une seule notification ; tour sous-agent `skipped`, `reason: platform` | Idem |
| Conversation reprise | Message dans une conversation rouverte depuis l'historique | Notification, toucher ouvre cette conversation | Idem |
| `/new` | `/new` puis message | Notification pour la bonne conversation | Idem |
| Toucher froid / chaud / récents | App tuée, arrière-plan, relance depuis les récents | Bonne conversation, consommation unique (récents → pas de rejeu) | Capture |
| Profil sans plugin | Envoi sur `mesure-pieces-jointes` | Envoi accepté, tour « Notification non suivie » | Capture |
| Redémarrage Hermes | Redémarrage de l'add-on pendant un travail | Résultat consigné ; perte acceptée et expliquée | Capture + journal |
| Arrêt forcé | Réglages Android → Forcer l'arrêt | Aucune réception jusqu'à réouverture, puis reprise ; explication dans l'app | Capture |
| Permission refusée | Refus de la permission | Aucune notification, explication dans l'app | Capture |

**Décisions (Alanc, 2026-10-30) :** Firebase `hermes-mobile-f22ed` existant ; APK **release** signé (signature de l'app installée) ; téléphone en ADB, l'agent installe, lit `logcat` et capture, Alanc fait les gestes ; profil de test `.hermes` ; spec gardée entière malgré sa taille.

</frozen-after-approval>

## Code Map

- `server/hermes-plugin/hermes-mobile-notify/` — plugin 1.0.0 à recopier sur `.hermes` ; la version installée est **0.1.0** (étude 2, `__init__.py` différent). Le spike n'est plus présent ; `plugins.enabled` contient déjà `hermes-mobile-notify`.
- `server/hermes-plugin/README.md` — procédure d'installation, journal `session-end.jsonl` (`action`, `reason`, `token_tail`), raisons `platform`/`no_token`… ; source des preuves serveur.
- Samba `\\homeassistant.local\addon_configs\0a6523c6_hermes_agent\.hermes\` — `hermes-mobile\{fcm-token,service-account.json}` présents ; profil `profiles\mesure-pieces-jointes\` sans aucun plugin (candidat « profil sans plugin »).
- `lib/data/outbox_repository.dart:767-787` — jeton envoyé par `command.dispatch`, seule l'erreur 4018 marque « non suivie ».
- `lib/ui/content.dart:7-19`, `lib/ui/components/notification_settings.dart` — libellés « Notification non suivie », prérequis (arrêt forcé, batterie), états permission ; à constater, pas à modifier sauf défaut.
- `lib/app/routes.dart:392` — conversation introuvable → accueil + SnackBar.
- `android/app/src/main/kotlin/fr/hermes_mobile/MainActivity.kt:18-73` — extra `EXTRA_SESSION`, garde `FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY`, `takeOpened` ; sans test Android (reports 5-7 et 5-8).
- `android/app/google-services.json`, `android/key.properties` — présents, ignorés par Git.
- `_bmad-output/planning-artifacts/architecture/architecture-Hermes Mobile-2026-10-20/ARCHITECTURE-SPINE.md:249` — ligne G3 ; y noter le statut final (seul endroit où vit la porte depuis la suppression de `notification-deployment.json`).
- `_bmad-output/implementation-artifacts/deferred-work.md` — clore les reports 5-7 (Kotlin `sessionId`) et 5-8 (récents, `takeOpened`) une fois joués.
- `_bmad-output/implementation-artifacts/story-5-5-verification/` — preuves des essais observateur (historique) ; nouvelles preuves préfixées `plugin-`.
- `adb devices` : aucun appareil branché actuellement.

## Tasks & Acceptance

**Exécution :**
- [x] Prérequis (Alanc) — recopier le plugin 1.0.0 sur `.hermes` et redémarrer ; confirmer le retrait de l'add-on observateur (proposition §6) ; brancher le téléphone en ADB. L'agent vérifie par Samba (`plugin.yaml` 1.0.0, fichiers identiques) et `hermes plugins list`/journal.
- [x] Téléphone — `fvm flutter build apk --release`, installation `adb install -r` (annoncée), permission accordée, premier envoi → ligne `event: token`.
- [x] Scénarios — jouer chaque ligne de la matrice ; preuves : capture `adb exec-out screencap`, extrait `session-end.jsonl` expurgé, `logcat` filtré ; défaut bloquant → correctif + test, puis rejouer.
- [x] `story-5-5-verification/rapport-g3.md` — protocole, résultat et preuve par scénario, écarts, verdict G3.
- [x] `ARCHITECTURE-SPINE.md` (ligne G3), `deferred-work.md` — statut G3 et reports Kotlin/récents clos ou maintenus.

**Critères d'acceptation :**
- Étant donné le rapport, quand il est relu, alors chaque scénario a un résultat constaté et une preuve, sans secret ni contenu.
- Étant donné tous les scénarios réussis, quand la porte est mise à jour, alors G3 est notée franchie avec la date ; sinon elle reste ouverte et les écarts sont remontés à Alanc.

## Implementation Notes


**Repassée en `draft` (2026-10-29) :** proposition de changement approuvée ([sprint-change-proposal-2026-10-29.md](../planning-artifacts/sprint-change-proposal-2026-10-29.md)) — l'observateur est remplacé par le plugin Hermes. Critères réécrits dans `epics.md` (story 5.5) ; l'intention ci-dessus est à renégocier avec Alanc. Reprendre avec bmad-build après les stories 5.6, 5.7 et 5.8.

**En pause (2026-10-29), à la demande d'Alanc :** priorité donnée à l'étude d'un plugin Hermes remplaçant l'observateur (voir ci-dessous). G3 reste ouverte.

État du déploiement : Firebase `hermes-mobile-f22ed` créé par CLI (gcloud), dépôt public, add-on 0.1.4 en `personal`, exposé par Tailscale Services (`host_network`, écoute 127.0.0.1:8787, sans watchdog TCP), APK **release** signé (et non debug : signature de l'app déjà installée), profil `.hermes` (affiché « default »).

Défauts corrigés pendant les essais (commits 88f0723…6bac332) : jeton FCM via `getToken` (le FID de `register()` ne se résolvait jamais) et permission sans délai de 3 s ; attache avec `stored_session_id` (Hermes renvoie 4007 sur l'id runtime) ; `last_seen` omis au premier rattrapage (-32602 sur `null`) ; `rpc_code` journalisé. Faiblesse : le test 4007 ne distingue pas l'ancien comportement.

Scénarios joués :
- App fermée — réussi (`04-app-fermee-observateur.log`, `delivered: 1`).
- Toucher froid, chaud — réussis, constatés par Alanc (captures noires : écran éteint).
- Relance depuis les récents après `am kill` — réussi, accueil, toucher non rejoué (`06-relance-recents-accueil.png`).
- Permission refusée — explication capturée (`01-…png`), absence de notification non encore constatée.
- Restent : coupure réseau, redémarrage observateur, observateur absent, arrêt forcé.

Restent ensuite : `rapport-g3.md`, contrat (`hermes-mobile-f22ed`, écoute loopback/Tailscale Services 443), `DOCS.md` §3/§10/§14/§15, `deferred-work.md` (clore 5.4, 4007), vérifications finales, revue (step-04).

**Écart remonté par Alanc :** installation trop lourde (add-on, Firebase, URL + bearer par profil). Piste : plugin Hermes (`~/.hermes/plugins/`) avec hook `on_session_end` (par tour : `session_id`, `completed`, `interrupted`, `failed`, `platform`) envoyant FCM, jeton enregistré par commande slash (`ctx.register_command`). À prouver : déclenchement pour les tours de l'app, nature de `session_id`, appel de commande depuis l'app, bibliothèque de signature OAuth dans l'add-on Hermes, persistance du plugin aux mises à jour.

**Reprise (2026-10-30) :** 5.6, 5.7 et 5.8 faites (`e0d65e3`). Spec réécrite pour le plugin ; nouvelle intention adoptée par Alanc.

**Essais plugin (2026-10-30) :** APK release `--build-number=22` (l'app installée était en versionCode 21 ; `fvm` hors PATH → `~/.fvm-bin/fvm/fvm.exe`). Plugin 1.0.0 copié et Hermes redémarré par Alanc.
- App fermée — réussi : notification reçue, toucher ouvre la conversation (Alanc) ; `session-end.jsonl` 09:14:01 `tui succeeded sent 200`, jeton `event: token` 09:13:42.
- **Défaut :** 8 s après, `on_session_end` sans `turn_id` (`interrupted: true`, `failed` absent) quand Hermes ferme la session détachée (`agent_close`, app quittée) → faux « arrêté » envoyé (aussi le 29 à 21:18:30). Correctif plugin 1.0.1 : sans `turn_id` → `skipped`, `reason: session_close` ; auto-vérification étendue (échoue sans le correctif) ; README mis à jour.
- Plugin 1.0.1 copié, Hermes redémarré 10:25:44. Rejeu app fermée (09:27:58) et coupure réseau (09:28:26, socket fermé seulement à la reconnexion 10:28:54) : une notification chacun, reçue après reconnexion pour la coupure (Alanc). Les deux dans la conversation `…ecff32`.
- Preuve du correctif : envoi 10:30:04, app balayée 10:30:06 (ws 1006) → `sent 200` 10:30:17, puis 10:30:26 `skipped session_close` ; une seule notification (Alanc).
- Arrêt — réussi : 09:32:23 `stopped` (`interrupted_during_api_call`, avec `turn_id`) envoyé (Alanc).
- Sous-agent — fin du sous-agent `skipped platform` (09:33:05) ; deux notifications reçues pour deux vrais tours `tui` : annonce de délégation (09:33:02) puis tour injecté par Hermes à la fin de la délégation asynchrone (`kind=async_delegation_complete`, 09:33:11). Pas de doublon de sous-agent.
- `/new` — **écart** : l'app envoie « /new … » comme message ordinaire (`kind=user`, 09:34:12) ; aucune commande `/` interprétée. Notification reçue pour ce tour.
- Conversation reprise + toucher froid — réussis : `…ecff32` rouverte depuis l'historique, 09:36:28 `sent 200`, app tuée, toucher ouvre la conversation (Alanc) ; 09:36:41 `skipped session_close`.
- Récents — réussi (Alanc) : relance depuis les récents sans rejeu du toucher.
- Toucher chaud — réussi : 09:38:48 `sent 200`, ws fermé en arrière-plan 10:38:42, rouvert au toucher 10:38:49, bonne conversation (Alanc).
- Profil sans plugin — **échoué** : tour terminé, hook non appelé, aucune notification ; mais `/hermes-mobile-token` accepté (commande globale au processus Hermes multi-profils), pas de 4018, « Notification non suivie » absente (Alanc).
- Redémarrage Hermes — SIGTERM interrompt proprement le tour : `stopped sent 200`, notification « arrêté », aucune perte.
- Arrêt forcé, permission refusée — `sent 200`, rien affiché (Alanc) ; explications dans l'app non regardées.
- Alanc arrête les essais. Verdict : G3 ouverte (rapport `story-5-5-verification/rapport-g3.md`, ligne G3 de `ARCHITECTURE-SPINE.md`) ; écarts dans `deferred-work.md` ; reports 5-7 Kotlin et 5-8 récents clos, `show` premier plan reporté.
- Heures de ces notes : journal du plugin en UTC, `agent.log` en heure locale (UTC+1) ; le rapport les unifie en UTC.
- Vérifications (après 1.0.1 puis 1.0.2) : auto-vérification du plugin réussie (et en échec sans la garde) ; `fvm flutter test --no-pub` 499 tests réussis (`~/.fvm-bin/fvm/fvm.exe`) ; `google-services.json` et `key.properties` ignorés (`!!`). Seul du Python et de la doc ont changé : `flutter analyze` non relancé.
- Revue : garde restreinte aux arrêts sans `turn_id` (1.0.2, `outcome` retiré de la ligne `session_close`) ; rapport passé en UTC, sous-agent noté écart à la matrice, arrêt forcé et permission « partiel », limites des preuves, retrait de l'observateur non confirmé ; README « version minimale 1.0.2 » ; reports ajoutés (délégation asynchrone, arrêt brutal, rejeu 1.0.2).

## Spec Change Log

## Review Triage Log

| Constat | Verdict | Preuve | Suite |
|---|---|---|---|
| Garde `session_close` trop large : fin réussie/échouée sans `turn_id` perdue | medium | `if not kwargs.get("turn_id")` ignore tout ; seule forme observée : `interrupted` | patch (garde sur `stopped`, cas d'auto-vérification) |
| Session récoltée en plein tour → vrai arrêt perdu | false | 09:30:06 app quittée en plein tour : fin `sent` 09:30:17, récolte seulement après (09:30:26) | rejeté |
| `outcome: stopped` journalisé pour `session_close` | low | Trompe la lecture du journal ; suppression directe | patch |
| Auto-vérification sans clé `turn_id` absente (seulement `None`) | low | `kwargs.get` traite les deux pareil | rejeté |
| Heures UTC/locale mélangées entre spec et rapport (3 relecteurs) | medium | ex. `/new` 09:34:12 vs 10:34:12 | patch (rapport en UTC, note de fuseau) |
| Sous-agent noté « Réussi » alors que la matrice attend une notification | medium | Deux reçues | patch (écart à la matrice) + defer (UX) |
| Arrêt forcé / permission « Réussi (partiel) » ; reprise non constatée | medium | Explications et reprise non regardées | patch (« Partiel ») |
| Captures / `logcat` prévus absents | medium | Seul `rapport-g3.md` ajouté | patch (section « Limites des preuves ») |
| Reports 5-7/5-8 clos sans trace native | low | Effet observé (bonne conversation, pas de rejeu) prouve le chemin | patch (dit dans le rapport) |
| Écart sous-agent et arrêt brutal non suivis | low | Absents de `deferred-work.md` | patch (reports) |
| Jeton cross-profil « sans effet nuisible » | low | Emplacement unique, écrasable | patch (lien au report multi-téléphones) |
| Version minimale du plugin non indiquée | low | Une 1.0.0 recrée le faux « arrêté » | patch (README, ARCHITECTURE-SPINE) |
| Résultats des commandes de vérification non consignés | low | — | patch (notes) |
| Retrait de l'observateur coché sans preuve | low | Jamais confirmé | patch (dit dans le rapport) |
| Code Map en 1.0.0 ; intention réécrite sans Change Log ; vieille note « draft » | low | Notes d'implémentation datées tracent 1.0.1 ; Change Log réservé aux retours de revue | rejeté |
| Références par numéro de ligne dans le Code Map | low | Spec de cette story seulement | rejeté |

## Verification

**Commandes :**
- `fvm flutter analyze --no-pub` et `fvm flutter test --no-pub` — aucune régression après correctif éventuel.
- `python server/hermes-plugin/hermes-mobile-notify/__init__.py` — auto-vérification réussie.
- `git status --ignored` — `google-services.json`, `key.properties` et clé jamais suivis.

**Vérification manuelle :** chaque scénario de la matrice constaté sur le téléphone réel par Alanc.
