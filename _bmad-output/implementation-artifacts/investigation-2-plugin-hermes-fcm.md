# Investigation 2 — plugin Hermes FCM (bascule depuis l'observateur)

Date : 2026-10-29. Spec : [spec-etude-2-plugin-hermes-fcm.md](spec-etude-2-plugin-hermes-fcm.md). Étude 1 : [investigation-plugin-hermes-notifications.md](investigation-plugin-hermes-notifications.md).

## Protocole

Plugin `hermes-mobile-notify` installé par Alanc sur le profil `.hermes` (clé du compte de service `hermes-mobile-f22ed` copiée dans `.hermes/hermes-mobile/`), `hermes-mobile-spike` désactivé, add-on redémarré à 22:12. APK release 21 (appel `command.dispatch` du jeton avant chaque envoi). Notifications de l'observateur désactivées dans l'app pour ce profil. Alanc a joué les cas depuis l'app et confirme la réception des notifications. Journal `plugins/hermes-mobile-notify/session-end.jsonl` et `state.db` lus en lecture seule. Heures du journal en UTC.

## Constats

**1. Le canal du jeton app → plugin fonctionne.** Hermes n'enregistre pas l'argument de la commande : `hermes-mobile-token` absent de `agent.log`, `errors.log` et de la table `messages` de `state.db` ; seule la fin du jeton (`…YUodnb7c`) apparaît, écrite par le plugin. Premier envoi de l'app, puis un appel par message, sans réécriture tant que le jeton ne change pas :

```json
{"ts": "2026-10-29T21:15:22.403+00:00", "event": "token", "token_tail": "YUodnb7c", "changed": true}
{"ts": "2026-10-29T21:15:47.901+00:00", "event": "token", "token_tail": "YUodnb7c", "changed": false}
```

**2. L'envoi FCM réel fonctionne, en arrière-plan.** Chaque fin de tour donne `action: sent`, `status: 200`. Durée côté plugin (hook → réponse FCM 200) : 1 070 ms pour le premier (obtention du jeton OAuth), puis 103 à 456 ms. L'heure d'arrivée sur le téléphone n'a pas été mesurée. Réception constatée globalement par Alanc (« les notifs fonctionnent »), pas cas par cas.

```json
{"ts": "2026-10-29T21:15:29.404+00:00", "session_id": "20261029_221522_93eec8", "completed": true, "platform": "tui", "outcome": "succeeded", "action": "sent", "status": 200, "duration_ms": 1070}
```

**3. Arrêt → `outcome: stopped`.**

```json
{"ts": "2026-10-29T21:15:49.856+00:00", "interrupted": true, "turn_exit_reason": "interrupted_during_api_call", "outcome": "stopped", "action": "sent", "status": 200}
```

**4. Tour avec outils : une seule ligne** (21:16:47, `succeeded`, `sent`). Les appels d'outils ne déclenchent pas `on_session_end`.

**5. Sous-agent : notification en trop.** La délégation a produit trois envois : le tour parent (21:17:24), **le sous-agent** (21:17:34) et la reprise du parent quand le résultat revient (21:17:37).

```json
{"ts": "2026-10-29T21:17:34.592+00:00", "session_id": "20261029_221722_f9c699", "task_id": "sa-0-a49fa1d9", "platform": "subagent", "outcome": "succeeded", "action": "sent", "status": 200}
```

`state.db` : `20261029_221722_f9c699 | source tui | parent_session_id 20261029_221522_93eec8 | « Subagent: écris un seul haïku »`. Le sous-agent se reconnaît à `platform: subagent`. Correctif nécessaire : ne notifier que `platform == "tui"`.

**6. Tâche cron sans tour : aucun envoi.** Une session `cron` créée à 21:18:19 (0 message) n'a produit aucune ligne.

**7. Non constatés** : aucune autre session `tui` n'apparaît dans `state.db` pendant l'essai. La reprise d'une ancienne conversation et `/new` n'ont donc pas laissé de trace distincte (le tour de 21:17:50 est dans la même conversation). À rejouer au moment de la bascule. Tour en échec (`failed: true`) non reproduit.

## Ce que la bascule change

**Supprime :** l'add-on Hermes Notifier, Tailscale Services et le port 8787, l'URL et le bearer par profil dans l'app, l'abonnement `POST /v1/subscriptions` et l'attache, le décalage d'identifiant (4007).

**Perd, à compenser ou à accepter :**
- **File durable et rattrapage** : si Hermes plante en plein tour, pas de hook, pas de notification. Si FCM échoue, pas de nouvel essai (une ligne `failed`). Un nouvel essai simple en mémoire suffit probablement.
- **« Notification non suivie »** : l'app ne sait plus si le plugin est présent. d'après le code (`tui_gateway/methods_tools.py:1018`), `command.dispatch` renvoie 4018 quand la commande est absente ; non constaté en réel, à vérifier plugin désactivé avant d'en faire le signal.
- **Ouverture de la bonne conversation au toucher** : l'app attend `subscriptionId`. Le plugin connaît `session_id` (l'identifiant stocké, celui de l'app) : la notification peut porter `sessionId` et l'app ouvrir directement la conversation, plus simplement qu'aujourd'hui.

**À traiter aussi :** un plugin par profil (installation × profils), notification de tous les tours `tui` du profil (y compris ceux lancés depuis un autre appareil que le téléphone), plusieurs téléphones (un seul jeton par profil : le dernier client qui l'envoie reçoit toutes les notifications du profil), persistance aux mises à jour de l'add-on.

## Décision

**Go pour la bascule complète.** Le plugin couvre la promesse principale (une notification par fin de tour, app fermée) avec bien moins d'installation. Conditions avant de retirer l'observateur :
1. Filtrer `platform == "tui"` (constat 5).
2. Porter `sessionId` dans `data` et ouvrir la conversation au toucher.
3. Signal « non suivi » par `command.dispatch` (4018), après vérification en réel.
4. Jeton refusé par FCM (`UNREGISTERED`) : l'oublier jusqu'au prochain envoi de l'app ; nouvel essai simple en cas d'échec réseau.
5. Rejouer la reprise de conversation, `/new` et un tour en échec.

## Plan de bascule proposé

1. `bmad-correct-course` sur l'epic 5 : remplacer l'observateur par le plugin dans le contrat et les stories, retirer la configuration observateur de l'app, redéfinir la porte G3.
2. Story « plugin de notifications » : conditions 1 à 3, tests, procédure d'installation.
3. Story 5.5 rejouée avec le plugin, puis retrait de l'add-on Notifier.

## État laissé

`hermes-mobile-notify` actif sur `.hermes` (version des essais, qui notifie aussi les sous-agents ; la version du dépôt filtre `platform == "tui"` et doit être recopiée). Clé dans `.hermes/hermes-mobile/`, jeton dans `.hermes/hermes-mobile/fcm-token`. Notifications de l'observateur désactivées dans l'app pour ce profil. APK 21 installé.
