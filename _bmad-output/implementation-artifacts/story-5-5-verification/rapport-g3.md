# Story 5.5 — rapport G3 (plugin Hermes)

Date : 2026-10-30. Verdict : **G3 reste ouverte** — un scénario échoué (profil sans plugin), un non jouable (`/new`). Écarts remontés à Alanc ci-dessous.

## Protocole

- Téléphone d'Alanc en ADB ; APK release signé, versionCode 22 (`flutter build apk --release --build-number=22`), installé par `adb install -r`.
- Hermes (add-on HA), profil de test `.hermes` (« default ») ; profil sans plugin : `mesure-pieces-jointes`.
- Plugin `hermes-mobile-notify` 1.0.0, puis **1.0.1** (correctif ci-dessous), copié et activé par Alanc, Hermes redémarré par Alanc ; copie vérifiée identique au dépôt par Samba. Après revue, le dépôt passe en **1.0.2** (garde restreinte aux arrêts), à recopier ; non rejouée en réel.
- Retrait de l'add-on observateur : non confirmé par Alanc ; l'app n'enregistrant plus d'abonnement depuis 5.7, il ne notifie rien.
- Firebase `hermes-mobile-f22ed`. Gestes et constats visuels : Alanc. Preuves serveur : `HERMES_HOME/plugins/hermes-mobile-notify/session-end.jsonl` et `logs/agent.log`, lus en lecture seule par Samba. **Toutes les heures ci-dessous sont en UTC** (journal du plugin) ; `agent.log` (heure locale, UTC+1) a été converti. Sessions abrégées à leurs 6 derniers caractères ; jeton jamais au-delà de `token_tail`.

## Résultats

| Scénario | Résultat | Preuve |
|---|---|---|
| App fermée | Réussi (après correctif) | 1.0.0 : 09:14:01 `succeeded sent 200`, puis 09:14:09 faux « arrêté » (deux notifications vues). 1.0.1 : envoi 09:30:04, app balayée 09:30:06 (ws 1006), 09:30:17 `sent 200`, 09:30:26 `skipped session_close` ; une notification, toucher ouvre la conversation (Alanc) |
| Coupure réseau | Réussi | 09:28:26 `succeeded sent 200` ; socket fermé à la reconnexion (09:28:54) ; notification reçue après reconnexion (Alanc) |
| Arrêt | Réussi | 09:32:23 `stopped` (`interrupted_during_api_call`) `sent 200` (Alanc) |
| Sous-agent | **Écart à la matrice** (une notification attendue, deux reçues ; critère d'epic « sans doublon de sous-agent » tenu) | 09:33:05 fin du sous-agent `skipped platform` ; deux notifications pour deux vrais tours `tui` : annonce de délégation (09:33:02) et tour injecté à la fin de la délégation asynchrone (`kind=async_delegation_complete`, 09:33:06 → 09:33:11) |
| Conversation reprise | Réussi | `…ecff32` rouverte depuis l'historique, 09:36:28 `sent 200`, toucher ouvre la conversation (Alanc) |
| `/new` | **Non jouable** | L'app envoie « /new … » comme message ordinaire (`kind=user`, 09:34:12) ; aucune commande `/` |
| Toucher froid | Réussi | 09:36:28, app tuée, bonne conversation (Alanc) |
| Toucher chaud | Réussi | 09:38:48 `sent 200`, ws fermé en arrière-plan 09:38:42, rouvert au toucher 09:38:49, bonne conversation (Alanc) |
| Récents | Réussi | Relance depuis les récents sans rejeu du toucher (Alanc) |
| Profil sans plugin | **Échoué** | Tour terminé 09:40:12, hook non appelé, aucune notification. Mais `/hermes-mobile-token` accepté (journal `.hermes`, 09:40:08 `event: token`) : pas de 4018, « Notification non suivie » **non affichée** (Alanc) |
| Redémarrage Hermes | Consigné (arrêt propre seulement) | SIGTERM 09:41:20 → interruption propre du tour, 09:41:21 `stopped sent 200` : notification « arrêté » reçue, aucune perte dans ce cas |
| Arrêt forcé | **Partiel** | 09:47:10 `sent 200`, rien affiché (Alanc). Reprise après réouverture et explication dans l'app non constatées |
| Permission refusée | **Partiel** | 09:48:31 `sent 200`, rien affiché (Alanc). État « permission refusée » non constaté |

## Défaut corrigé pendant les essais

Quand l'app est quittée, Hermes récolte la session détachée quelques secondes après la fin du tour (`agent_close`) et rappelle `on_session_end` **sans `turn_id`** (`interrupted: true`). Le plugin 1.0.0 en faisait un « arrêté » (deux notifications, aussi vu le 29 à 21:18:30). Plugin **1.0.1** : sans `turn_id` → `skipped`, `reason: session_close` ; auto-vérification étendue (échoue sans le correctif), README mis à jour. Les vrais arrêts portent un `turn_id` et restent notifiés.

## Écarts remontés à Alanc

1. **Profil sans plugin non détecté.** Hermes sert tous les profils dans un seul processus ; la commande du plugin y est globale, donc l'app ne reçoit jamais 4018 et ne marque pas « Notification non suivie ». Le jeton est écrit dans le `HERMES_HOME` du profil qui porte le plugin : emplacement unique, donc un client d'un autre profil peut écraser le jeton (même problème que le report « plusieurs téléphones par profil »). Piste : la commande vérifie que le plugin est activé dans le `config.yaml` du profil courant et répond un refus reconnu par l'app.
2. **`/new` non applicable** : l'app n'interprète aucune commande `/` ; « Nouvelle conversation » en tient lieu. À trancher : non applicable, ou story dédiée.
3. **Explications de l'arrêt forcé et de la permission refusée** non constatées dans l'app pendant les essais (Alanc : « pas grave »).
4. **Sous-agent asynchrone** : deux notifications par délégation (annonce puis résultat) ; la matrice en attendait une.
5. **Redémarrage brutal non joué** : seul l'arrêt propre (SIGTERM) l'a été ; la perte en cas de plantage reste non constatée.

## Limites des preuves

Les constats visuels reposent sur Alanc ; aucune capture ni extrait `logcat` n'a été pris pendant ces essais (Alanc a demandé d'écourter). Le chemin natif du toucher (`EXTRA_SESSION`, garde des récents) est prouvé par l'effet observé — bonne conversation ouverte, pas de rejeu — sans trace `logcat`.
