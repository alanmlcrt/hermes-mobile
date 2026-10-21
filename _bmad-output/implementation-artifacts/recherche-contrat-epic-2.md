# Recherche contrat — epic 2 (conversations)

Build lu : `v0.22.2+1690`, commit `9e01b44` (main). Sources : code Python lu à ce commit, liens épinglés en bas de note. Rien n’a été exécuté ni envoyé au serveur ; tout est **documentaire**. « Non établi » = non trouvé dans le code lu.

**Réserve majeure.** Deux dialectes existent sur `/api/ws`. Le dialecte « legacy » (`server.dispatch`) est celui décrit ci-dessous et par `contracts/openrpc.json`. Si `gateway.ready.payload.session_authority` est `true` ([ws-ready]), les verbes de session passent par l’autorité de sessions (forme « canonique » : `submission_id`, `AdmissionStatus`, `runtime.describe` ; [canon-sess]). Quel dialecte sert l’installation : **non établi**. À lire dans la première trame.

## 1. Trames JSON-RPC
- Une trame = un message texte WebSocket contenant un objet JSON ([ws-recv]). Parse raté → `{"error":{"code":-32700}}`, `id:null`.
- Requête : `{"jsonrpc":"2.0","id":<chaîne ou nombre>,"method":…,"params":{…}}`. L’`id` est libre et recopié ; le client officiel envoie `r1`, `r2`… ([rpc-id]). Les requêtes sont traitées en série, dans l’ordre d’arrivée ([ws-loop]).
- Réponse : `{"jsonrpc":"2.0","id":…,"result":{…}}` ou `…"error":{"code","message"[,"data"]}`. Méthode inconnue : `-32601` ([dispatch]). `profile` inexistant : `4064`. Pas de verrouillage de version autre que ce message.
- Notification : `{"jsonrpc":"2.0","method":"event","params":{"type":…,"session_id":…,"payload":{…},"seq":N}}` ([frame]). La session est dans `params.session_id` (identifiant **runtime**, 8 hex ; pour `session.title` c’est la clé stockée). `seq` est un entier croissant par session, posé par le serveur ([stamp]). Les événements sans `session_id` (`gateway.ready`, `sessions.changed`) n’ont pas de `seq`.
- Sonde : `gateway.ping` répond `{"ok":true}` hors file ([ws-ping]) ; `ping` répond `{"pong":true}`.

## 2. session.create
- `profile` : résolu vers le dossier du profil ; il est mémorisé dans la session et lie agent, base et tours à ce profil ([create], [profile-home]). Profil absent → `4064`, jamais de repli silencieux.
- `close_on_disconnect` (défaut `false`) : `true` → session détruite dès que la socket tombe sans autre client attaché ; sinon elle est « parquée » ([lifecycle]).
- `idempotency_key` : table en mémoire processus, TTL **300 s**, rafraîchi à chaque rejeu ([create-idem], [ttl]). Rejeu avec session encore vivante → mêmes `session_id` et `stored_session_id`, avec l’état actuel. Session fermée entre-temps → nouvelle session sous la même clé. **Aucun conflit détecté** : mêmes clé, autres paramètres → la première session est rendue sans erreur. La table n’est **pas** cloisonnée par profil et disparaît au redémarrage. Conséquence : préfixer la clé par profil et par brouillon.
- Résultat ([create-result]) : `session_id` = id runtime (8 hex), éphémère, utilisé par `prompt.submit`, `session.history`, `session.status`, `session.interrupt`, `session.title` et dans les événements. `stored_session_id` = clé durable (état SQLite), seule valeur à persister ; c’est l’argument de `session.resume`. Aucune ligne n’existe en base avant le premier prompt ; un brouillon vide reste purement mémoire.

## 3. prompt.submit
- Statuts (`PromptSubmitStatus`) : `streaming`, `queued`, `steered`, `redirected` ([openrpc]). La réponse arrive **avant la fin du tour** (`streaming` = tour lancé) ([submit-ok]).
- Session occupée : jamais de refus. Selon le mode d’entrée occupée côté serveur : `redirected`, `steered` ou `queued` ([busy]) ; `queued:true` force la file. Exception : une troncature demandée sur session occupée → erreur `4009 session busy` ([submit-busy]).
- `user_row_id` : id entier de la ligne utilisateur déjà écrite en base, rendu dans la réponse `streaming` quand l’écriture a réussi ([submit-row]). Il peut manquer (champ optionnel). Un statut `queued` ne le porte pas.
- Erreurs : `4001` session runtime inconnue (reaped/redémarrage → `session.resume`), `4009`, `4090` (limite de sessions actives), `5035` (backend en arrêt, reconnecter), `5070/5071/5072` (stockage), `4000` paramètres invalides.
- Idempotence : **aucune** en legacy (le schéma n’a pas de clé ; [openrpc]). Un renvoi après réponse perdue peut produire un second message. En canonique : `submission_id` et reçu `AdmissionStatus` (`admission_id`, `status`) ; sémantique exacte d’un rejeu : non établie.
- Socket coupée : la ligne utilisateur est déjà durable. Le tour continue côté serveur tant que son activité date de moins de 600 s ; les événements continuent d’être numérotés et stockés dans l’anneau de rejeu. Après 20 s de grace sans client, un tour inactif est interrompu puis la session détruite ([orphan]).

## 4. Séquence d’un tour
1. `message.start` : charge vide en usage ordinaire ([prompt-start]) ; sans id de message ni de tour.
2. `message.delta` `{text, rendered?}` : fragments ; `text:null` possible (frontière de segment, ignorable). `message.interim` `{text, already_streamed}` : commentaire scellé à côté d’outils.
3. `status.update` `{kind, text}` : ligne d’état transitoire ; `session.info` : instantané des réglages (`running`, `turn_started_at`, `usage`…).
4. **Terminal unique** : `message.complete` `{text, status, usage, persisted_turn?, error?, recoverable?, error_surface?, partial?}` ([complete]). `status` ∈ `complete` | `error` | `interrupted` ([status]). Un échec de tour passe aussi par `message.complete` avec `status:"error"` ([terminal-err]). L’événement `error {message}` est un échec de session hors tour.
5. Identité : pas d’id de message ni de tour. Seuls repères : `seq`, et `persisted_turn` `{row_ids, user_row_id?, user_row_ids?, final_assistant_row_id?, complete}` : adresses des lignes validées ([receipt]). Une adresse absente n’est jamais un refus ; `complete:true` autorise à retirer tout le tour local.

## 5. Reprise
- `gateway.ready` : `{skin, change_events, replay_epoch, heartbeat?, session_authority?}`. `replay_epoch` change à chaque redémarrage du processus : watermarks `seq` à remettre à zéro ([epoch]).
- `session.events.since {session_id, last_seen}` → `{events[], latest_seq, truncated, count, epoch, open_requests[]}` ([since]). Anneau : 512 événements et 4 Mio par session ([ring]). `truncated:true` → les événements intermédiaires sont perdus : relire l’historique. Les événements rejoués sont les `params` bruts, `seq` inclus. Dédupliquer par `seq > dernier vu` (le client officiel le fait : [newer]).
- `session.resume {session_id=stored}` : modes `lazy`, `defer_history`, `omit_messages`, `eager_build`, sinon reconstruction « froide » ([resume]). Session vivante : réattache. Rend un **nouveau** `session_id` runtime, `session_key`, `running`, `status` (`idle`/`working`/`waiting`/`starting`), `turn_started_at`, `inflight` (`user`, `assistant` partiel, `streaming`, `status`, `error`), `queued`, `open_requests` ([live]). Une compression peut remplacer la clé : la clé rendue fait foi.
- `session.history {session_id=runtime}` → `{count, messages[]}` ; la session doit être vivante. Ligne : `role`, `text`/`content`, `row_id`, `timestamp`, `display_kind`, `tool_call_id`… ; ancêtres inclus ([history]). Lignes `display_kind:"hidden"` à ne pas afficher.
- `session.list` → `{sessions[]}` : `id`, `title`, `preview`, `started_at`, `message_count`, `source`, `resolved_id?`, `_lineage_root_id?`. Tri : activité décroissante ; limite 200 par défaut ; sources internes et masquées exclues ([list]).
- **Tour encore en cours ?** `session.status` ne le dit pas : il renvoie seulement `{output}` en texte ([status-rpc]). Sources fiables : `session.resume` (`running`, `inflight`, `status`) puis `session.events.since`. Après redémarrage serveur, un tour interrompu peut être relancé automatiquement par la reprise : non détaillé ici.

## 6. Paramètre `profile`
Sur `session.create`, `session.list`, `session.resume`, `session.events.since`, `session.history`, `session.status`, `prompt.submit` le schéma accepte `profile`. Effet vérifié : `create`/`list`/`resume` ouvrent la base **de ce profil** (lecture seule si étranger) sans toucher le profil actif global ([profile-db]). Pour les méthodes à `session_id` runtime, `profile` est ignoré : la session porte déjà son profil ([sess]). Les `session_id` runtime sont uniques sur tout le processus, pas par profil ; les `row_id` sont propres à la base de chaque profil. Les deux listes ne se mélangent donc que si l’app le fait : indexer localement par (profil, `stored_session_id`).

## 7. Rapprochement local ↔ serveur (sans texte)
1. Local : `local_id` + `profile` + `stored_session_id` (une fois connu) ; brouillon : clé d’idempotence liée à (profil, brouillon).
2. À l’envoi : si la réponse `streaming` porte `user_row_id`, lier immédiatement. Sinon, attendre `persisted_turn`.
3. À `message.complete` : lier `user_row_ids`/`user_row_id` aux bulles du tour **par position dans le tour**, pas par texte ; ne rien lier si une bulle porte déjà un autre id (règle du client officiel [bind]). Retirer le tour local seulement si `complete:true`.
4. Sinon : `session.history` et appariement par `row_id` ; sans id, un message reste « à vérifier », jamais supprimé ni renvoyé automatiquement.
5. Réponse perdue : ne jamais renvoyer sans avoir relu `session.history` et `inflight`.

## Différences d923a5e → 9e01b44 sur ces surfaces
- `gateway.ready` : champ optionnel `session_authority`.
- Nouveau dialecte canonique via autorité de sessions : `submission_id`, `AdmissionStatus`, `prompt.receipt`, `runtime.describe` ; fallback legacy ([ws-auth]).
- `PersistedTurn` : ajout de `user_row_ids` et `submission_id` ; calcul déplacé dans `agent/persisted_turn_receipt.py`.
- `message.start` et `message.delta` ont des schémas typés ; `text` peut être `null` pour `message.delta`.
- `server.py` éclaté (registre de sessions, `rpc_dispatch`, `session_*`) : comportements décrits ici inchangés ; `event_replay.py` identique.
- `web_server_chat.py` : garde Origin/Host déplacée dans `web_server_boundary`, accès natif par en-tête `X-Hermes-Gateway-Ticket` ; sous-protocoles ticket inchangés.
- `CatalogTier` gagne `verified` (hors surfaces utilisées). Aucune différence sur `session.create`, `session.history`, `session.list` (schémas identiques).

[ws-ready]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/ws.py#L459-L462
[canon-sess]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/contracts/canonical_sessions.py#L196-L226
[ws-recv]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/ws.py#L486-L508
[rpc-id]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/apps/shared/src/json-rpc-channel.ts#L206
[ws-loop]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/ws.py#L410-L431
[dispatch]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/rpc_dispatch.py#L20-L38
[frame]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/server.py#L717-L720
[stamp]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/event_replay.py#L67-L88
[ws-ping]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/ws.py#L509-L513
[create]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/methods_session.py#L330-L336
[profile-home]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/server.py#L589-L612
[lifecycle]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/session_lifecycle.py#L1039-L1096
[create-idem]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/methods_session.py#L340-L376
[ttl]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/server.py#L114
[create-result]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/methods_session.py#L476-L481
[openrpc]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/apps/shared/src/gateway-contract.openrpc.json
[submit-ok]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/methods_prompt.py#L887
[busy]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/session_auto_continue.py#L400-L454
[submit-busy]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/methods_prompt.py#L815-L831
[submit-row]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/methods_prompt.py#L873-L877
[orphan]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/session_lifecycle.py#L976-L1010
[prompt-start]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/prompt_turn.py#L426
[complete]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/prompt_turn.py#L897-L930
[status]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/prompt_turn.py#L310-L313
[terminal-err]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/session_auto_continue.py#L559-L585
[receipt]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/agent/persisted_turn_receipt.py#L20-L63
[epoch]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/event_replay.py#L22-L26
[since]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/methods_session.py#L2327-L2341
[ring]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/event_replay.py#L29-L36
[newer]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/apps/shared/src/json-rpc-gateway.ts#L702-L720
[resume]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/methods_session.py#L1049-L1085
[live]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/session_registry.py#L790-L830
[history]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/methods_session.py#L1996-L2013
[list]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/methods_session.py#L541-L566
[status-rpc]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/methods_session.py#L1971-L1993
[profile-db]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/server.py#L511-L540
[sess]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/session_registry.py#L304-L320
[bind]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/apps/desktop/src/app/session/hooks/use-message-stream/receipt-user-rows.ts#L41-L94
[ws-auth]: https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/ws.py#L339-L363
