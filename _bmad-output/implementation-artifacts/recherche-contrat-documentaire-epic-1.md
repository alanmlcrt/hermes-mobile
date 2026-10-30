# Contrat documentaire Hermes — préparation Epic 1

Date de consultation : 21 octobre 2026. Auteur des sources principales : NousResearch. Recherche de préparation de spec, sans implémentation ni requête au serveur personnel. Le backend d’Alanc est désactivé : **ce document décrit une release publique, pas le contrat réel de son installation et ne valide pas G1**.

## Résultat pour la spec

La référence publique retenue est **Hermes Agent `v0.22.2`, commit `d923a5eb487a17c0a68801bba9ef0f56c81040a8`**. Les portes utiles sont REST `/api/health`, `/api/status`, `/api/auth/providers`, `/api/profiles`, `/api/profiles/active`, et JSON-RPC sur `/api/ws`. Le login du provider nommé `basic` est un POST JSON avec cookies ; le flux natif PKCE fournit séparément des jetons JSON. Aucun de ces faits ne prouve la disponibilité sur l’add-on installé.

Les corrections à apporter aux hypothèses de spec sont les suivantes : ne pas prescrire `Authorization: Basic` pour le login, ne pas attendre des jetons dans le corps du login cookie, distinguer `is_default`, `active` et `current`, et détecter les capacités par leur surface effective plutôt que par un booléen universel. La présence d’`idempotency_key` sur `session.create` ne garantit pas l’idempotence de `prompt.submit`.

## Référence épinglée et portée des sources

- [Release stable publiée](https://github.com/NousResearch/hermes-agent/releases/tag/v0.22.2), publiée le 15 octobre 2026 à 08:21:32 UTC ; [API releases/latest consultée](https://api.github.com/repos/NousResearch/hermes-agent/releases/latest) : `draft=false`, `prerelease=false`, `tag_name=v0.22.2`.
- [Référence du tag](https://api.github.com/repos/NousResearch/hermes-agent/git/ref/tags/v0.22.2) : objet tag annoté `7b77e29eedd85a8497ce2821448dac7964dc46f6` ; [déréférencement](https://api.github.com/repos/NousResearch/hermes-agent/git/tags/7b77e29eedd85a8497ce2821448dac7964dc46f6) : objet commit **`d923a5eb487a17c0a68801bba9ef0f56c81040a8`**. Ne pas confondre SHA du tag et SHA du code.
- [Documentation Desktop actuelle](https://hermes-agent.nousresearch.com/docs/user-guide/desktop) et [Web Dashboard actuelle](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard). L’URL courte demandée `/docs/features/web-dashboard` n’a pas pu être ouverte ; le chemin ci-dessus est celui du site officiel. Ces pages vivantes servent au cadrage, les liens de code ci-dessous fixent les détails.
- Copies documentaires au commit : [Desktop](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/website/docs/user-guide/desktop.md), [Web Dashboard](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/website/docs/user-guide/features/web-dashboard.md). Les comportements techniques retenus ci-dessous ont été vérifiés dans les handlers, indépendamment de ces copies.
- [OpenRPC généré au commit](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/apps/shared/src/gateway-contract.openrpc.json) : `openrpc=1.3.2`, `info.title="Hermes TUI/Desktop gateway"`, `info.version="1"`. Ce dernier champ n’est ni la version de release ni une preuve de capacités de l’instance.

Les valeurs dans les exemples sont fictives. Une réponse dite « projection » omet volontairement des champs ; elle ne constitue pas un schéma complet ni une capture réelle. Les POST d’authentification sont documentés mais n’ont pas été exécutés ; ils créent ou renouvellent des credentials et ne sont donc pas des sondes en lecture seule.

## Status et bootstrap REST

| Requête sans corps | Réponse vérifiée / usage | Preuve au commit |
|---|---|---|
| `GET /api/health` | `{ok, version, displayVersion, commit, auth_required}` ; sonde légère du processus, le commit correspond au code chargé au démarrage | [status.py L116–127](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/status.py#L116-L127) |
| `GET /api/status` | Version, état gateway, résumé auth, topologie et santé ; public, ne démontre pas une authentification ou un accès WS réussis | [status.py L367–563](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/status.py#L367-L563), [allowlist](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/public_paths.py#L9-L23) |
| `GET /api/auth/providers` | `{providers:[{name,display_name,supports_password}]}` ; `503 {detail:"no auth providers registered"}` si aucun provider de session | [routes.py L203–212](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L203-L212) |

Projection schématique de `/api/status`, avec les champs utiles à l’Epic 1 :

```json
{
  "version": "0.22.2",
  "auth_required": true,
  "auth_providers": ["basic"],
  "auth_flows": ["cookie", "native_pkce"],
  "gateway_running": true,
  "gateway_state": "running",
  "gateway_updated_at": "2026-10-21T00:00:00Z",
  "profiles": ["default", "travail"],
  "parked_profiles": [],
  "gateway_mode": "multiplex",
  "overall": "ok"
}
```

Sources de chaque groupe : `version`, `gateway_*` dans [construction du payload](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/status.py#L508-L528) ; `auth_required`, `auth_providers`, `auth_flows` dans [_auth_gate_status](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/status.py#L367-L389) ; `profiles`, `parked_profiles`, `gateway_mode` dans [projection topologie](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/status.py#L546-L561) ; `overall` dans [agrégation santé](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/status.py#L540-L544). `gateway_updated_at` est une chaîne RFC3339 ou `null`, pas un nombre ([normalisation](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/status.py#L347-L350)).

Attention à « non mutant » : `/api/status` ne change pas le profil sélectionné et n’envoie pas de prompt, mais son premier accès peut persister `install_id` ([L530–534](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/status.py#L530-L534)). Il ne faut donc pas promettre zéro écriture interne. Préférer `/api/health` pour la disponibilité légère ; distinguer disponibilité HTTP, auth acceptée et WS opérationnelle.

## Authentification : provider `basic`, cookies et natif

### Login par mot de passe avec cookies

La route est **`POST /auth/password-login`**, `Content-Type: application/json`, sans header HTTP Basic requis par ce handler. Les champs obligatoires sont `provider` (string, au plus 128 caractères), `username` (string), `password` (string) ; `next` (string) vaut `""` par défaut. Exemple documentaire :

```json
{"provider":"basic","username":"utilisateur-exemple","password":"<MOT_DE_PASSE_FICTIF>","next":""}
```

Réponse normale `200` :

```json
{"ok":true,"next":"/"}
```

Les tokens sont dans les headers `Set-Cookie`, pas dans ce corps JSON. Sur HTTP sans préfixe proxy, les noms sont `hermes_session_at`, `hermes_session_rt`, `hermes_session_provider` ; cookies HttpOnly, SameSite=Lax, Path=/, avec variantes `__Host-` sur HTTPS ou `__Secure-` derrière un préfixe. Le cookie RT n’est écrit que si le provider en fournit un. Sources : [body, handler et réponse](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L439-L493), [transfert de la session vers cookies](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L104-L108), [noms et attributs](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/cookies.py#L1-L63).

Le renouvellement cookie est transparent dans le middleware : à expiration de l’AT, le RT est utilisé et les cookies tournés réécrits. Ce n’est pas un endpoint supposé `/api/auth/refresh`. Un access token natif peut aussi authentifier les routes REST via `Authorization: Bearer <AT>`, mais ce chemin ne fait pas de refresh cookie automatique. Sources : [middleware L120–180](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/middleware.py#L120-L180), [contrat du module](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/middleware.py#L1-L8).

Le provider `basic` a un AT de 12 h par défaut, configurable (minimum 60 s), et un RT de 30 jours. Son secret de signature **peut être stable si configuré** ; il n’est aléatoire par processus que si absent. Le nom d’utilisateur est configuré ; `hermes` et `access_password` relèvent éventuellement de l’add-on, pas du schéma générique officiel. Sources : [TTL et configuration](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/plugins/dashboard_auth/basic/__init__.py#L30-L33), [session et renouvellement](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/plugins/dashboard_auth/basic/__init__.py#L125-L182), [résolution secret et paramètres](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/plugins/dashboard_auth/basic/__init__.py#L191-L253).

### Flux natif, distinct du login cookie

1. `GET /auth/native/authorize` accepte les query params `provider=""`, `code_challenge=""`, `code_challenge_method=""`, `redirect_uri=""`, `state=""`. `S256` et un challenge non vide sont exigés ; le callback autorisé est une URL **HTTP loopback avec IP littérale `127.0.0.1` ou `::1`**, pas un lien applicatif arbitraire. Pour `basic`, le flux passe par le formulaire de login avec un broker dans le cookie PKCE. Sources : [validation callback](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L238-L276), [authorize et paramètres](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L279-L324).
2. `POST /auth/native/token`, JSON `{"code":"<CODE_FICTIF>","code_verifier":"<VERIFIER_FICTIF>"}` : échange du code à usage unique ; échec générique `400` avec `detail`. [Handler et schéma](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L569-L586).
3. `POST /auth/native/refresh`, JSON `{"refresh_token":"<RT_FICTIF>","provider":"basic"}` ; `refresh_token` requis, `provider` optionnel par défaut `""`. [Handler et schéma](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L589-L617).

Réponse JSON commune de token et refresh, sans cookie :

```json
{"access_token":"<AT_FICTIF>","refresh_token":"<RT_FICTIF>","token_type":"Bearer","expires_at":1800000000,"provider":"basic","user_id":"utilisateur-exemple"}
```

Tous les champs proviennent de [_bearer_payload](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L111-L116) ; `expires_at` est l’expiration epoch en secondes du provider ([mint/session](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/plugins/dashboard_auth/basic/__init__.py#L171-L182)). Le login cookie peut renvoyer un `next` vers ce callback au lieu de poser les cookies lorsqu’un broker natif est présent ([branche native](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L447-L493)).

**Décision ouverte de spec :** choisir et tester le flux adapté à Flutter Android (cookie géré explicitement, ou navigateur système + listener loopback natif). Ne pas transformer la découverte de ces routes en promesse qu’un simple POST mot de passe renvoie des tokens JSON. Le callback applicatif `hermes-mobile://…` n’est pas accepté comme `redirect_uri` par cette route.

### Ticket WebSocket

`POST /api/auth/ws-ticket` nécessite une session vérifiée par cookie ou bearer ; aucun champ de corps n’est lu. Réponse `200` :

```json
{"ticket":"<TICKET_FICTIF>","ttl_seconds":30}
```

Le ticket est à usage unique, conservé en mémoire serveur, TTL de 30 secondes ; il faut en obtenir un nouveau pour chaque nouvelle socket. Sources : [route](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L517-L564), [stockage et consommation](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/ws_tickets.py#L20-L61).

Upgrade vers `/api/ws?ticket=<TICKET_FICTIF>` ; alternative vérifiée évitant le secret en query : proposer ensemble les sous-protocoles `hermes-gateway-v1` et `hermes-gateway-ticket.<TICKET_FICTIF>`. Le serveur ne sélectionne en retour que `hermes-gateway-v1`. Le client mobile peut privilégier cette variante sous réserve de vérification de son transport. Le serveur accepte également certaines autres formes de credentials, mais ce ne sont pas des raisons pour persister un token dans une URL. Source : [parsing des sous-protocoles](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_server_chat.py#L207-L222), [admission ticket](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_server_chat.py#L250-L345).

## Profils et défaut sans mutation globale

`GET /api/profiles` sans corps retourne `{"profiles":[…]}`. Chaque entrée normale a : `name:string`, `path:string`, `is_default:bool`, `model:string|null`, `provider:string|null`, `has_env:bool`, `skill_count:int`, `gateway_running:bool`, `description:string`, `description_auto:bool`, `display_name:string`, `bot_title:string`, `distribution_name`, `distribution_version`, `distribution_source` (valeurs de métadonnées, null possibles), `has_alias:bool`. Source de projection : [_profile_to_dict](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/profiles.py#L84-L100), types de base : [ProfileInfo](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/profiles.py#L660-L688).

Projection schématique :

```json
{"profiles":[{"name":"default","is_default":true,"display_name":"Principal"},{"name":"travail","is_default":false,"display_name":"Travail"}]}
```

`is_default` identifie le profil racine nommé `default` dans cette release ; ce n’est pas le dernier profil choisi. [list_profiles L1033–1051](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/profiles.py#L1033-L1051).

`GET /api/profiles/active` retourne `{"active":"travail","current":"default"}` (exemple) : `active` est le choix persistant global utilisé par les nouvelles invocations CLI ; `current` est le profil du dashboard en cours. Cette lecture ne change pas le choix global. **Ne pas appeler `POST /api/profiles/active`** pour la sélection mobile : il écrit précisément ce choix global. Sources : [GET et distinction](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/profiles.py#L888-L906), [POST mutant à exclure](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/profiles.py#L909-L917).

Limites importantes : le GET actif remplace certaines lectures échouées par `default` ou `custom` ; la liste normale échouée bascule sur un scan de dossiers sans drapeau explicite d’erreur. Ne pas promettre que le payload expose tous les échecs de découverte. Sources : [_read_profiles](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/profiles.py#L798-L812), [fallback](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_server_profiles.py#L145-L187).

Recommandation de produit, pas champ serveur nouveau : définir avec précision lequel de `is_default` ou `active` signifie « défaut fourni par Hermes » pour le démarrage mobile, puis conserver le choix explicite du mobile localement. Ne pas ajouter un champ fictif `default_profile` au contrat.

## Handshake JSON-RPC et capacités observables

La route `/api/ws` appelle le transport `tui_gateway.ws.handle_ws` après authentification et contrôle du client/Host/Origin. [Montage](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/chat_ws.py#L695-L719), [contrôles](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_server_chat.py#L167-L204).

Après acceptation, le serveur émet cette **notification**, sans `id` ; `skin` est un objet de thème omis de l’exemple ci-dessous (projection du payload, pas trame exhaustive) :

```json
{"jsonrpc":"2.0","method":"event","params":{"type":"gateway.ready","payload":{"change_events":true,"heartbeat":true,"replay_epoch":"<EPOCH_FICTIF>"}}}
```

Les champs exacts sont `skin`, `change_events`, `heartbeat`, `replay_epoch` ; aucune requête préalable `initialize` n’est nécessaire dans ce handler. L’epoch sert à réinitialiser les watermarks après redémarrage. [Emission effective](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/tui_gateway/ws.py#L353-L376).

Exemples de sondes sans création de session ou de travail :

```json
{"jsonrpc":"2.0","id":1,"method":"gateway.capabilities","params":{}}
{"jsonrpc":"2.0","id":1,"result":{"per_session_exclusive_submit":true}}
{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}
{"jsonrpc":"2.0","id":2,"result":{"pong":true}}
```

Les noms et formes de ces réponses sont vérifiés dans les handlers ; `per_session_exclusive_submit=true` est ici illustratif, sa valeur dépend de la constante du module d’autorité et restera à mesurer sur l’instance. [Handlers et sources d’autorité](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/tui_gateway/methods_voice.py#L434-L457), [schémas](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/tui_gateway/contracts/liveness.py#L9-L48). Le transport WS reconnaît aussi `gateway.ping` avec résultat `{"ok":true}` ; ne pas confondre les deux noms/réponses ([fast path WS](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/tui_gateway/ws.py#L420-L424)).

Après `gateway.ready`, le client peut envoyer une fois `client.capabilities` avec `{"server_requests":false}` (défaut), ou `true` seulement s’il sait répondre aux requêtes serveur. Réponse : `{server_requests: string[], declines_not_shown: boolean}`, avec `declines_not_shown=true` dans ce handler. C’est une déclaration de comportement du client, pas une sonde parfaitement passive : elle modifie l’état de ce transport. Une méthode serveur non prise en charge doit recevoir une erreur JSON-RPC `-32601` si le client annonce la prise en charge des requêtes serveur. Sources : [schéma et sémantique](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/tui_gateway/contracts/liveness.py#L29-L48), [handler](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/tui_gateway/methods_voice.py#L442-L450).

| Capacité à inscrire dans la spec documentaire | Preuve publique épinglée | Limite / état de l’instance |
|---|---|---|
| `change_events`, `heartbeat`, `replay_epoch` | Champs de `gateway.ready` ci-dessus | Non vérifiés sur l’instance ; ne pas inventer ces champs dans `gateway.capabilities` |
| `per_session_exclusive_submit` | Seul champ de `GatewayCapabilitiesResult` et handler ci-dessus | Pas une garantie d’idempotence de message |
| `session.events.since` | Params `session_id:string` requis, `profile:string|null` optionnel, `last_seen:int|null` optionnel ; résultat `{events,latest_seq,truncated,count,epoch,open_requests}` dans l’[OpenRPC](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/apps/shared/src/gateway-contract.openrpc.json) (`SessionEventsSinceParams/Result`) et [handler](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/tui_gateway/methods_session.py#L2327-L2341) | Replay de ring buffer, `truncated` impose de recharger l’état ; ne pas tester avec un identifiant de session inventé pour en conclure la reprise réelle |
| `idempotency_key` de `session.create` | String nullable optionnelle dans `SessionCreateParams`, cache de clés [L341–376](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/tui_gateway/methods_session.py#L341-L376), TTL mémoire 300 s [server.py L109–114](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/tui_gateway/server.py#L109-L114) | Portée création, cache mémoire expirant ; aucun champ `idempotency_key` dans `PromptSubmitParams` de l’OpenRPC lu ; ne pas autoriser le renvoi automatique d’une soumission incertaine sur cette base |
| `close_on_disconnect` | Booléen optionnel, défaut `false` dans `SessionCreateParams` de l’OpenRPC | Ne pas créer une session pour détecter une capacité à ce checkpoint |
| `file.attach` | Méthode OpenRPC ; `session_id:string` requis, `profile`, `path`, `data_url`, `name` strings nullables optionnelles (`FileAttachParams`) | Méthode de staging de fichier, donc mutante ; existence documentaire seulement, ne pas l’appeler comme sonde |

Il n’existe pas, dans le résultat `gateway.capabilities` examiné, de liste exhaustive de toutes les méthodes. L’OpenRPC public décrit le build, pas les capacités mesurées du serveur personnel. Pour toute capacité obligatoire non vérifiée : marquer « non vérifiée » et reporter sa validation, sans produire une valeur supposée vraie.

## Erreurs et limites à conserver dans la spec

| Situation | Forme vérifiée | Source |
|---|---|---|
| Mauvais mot de passe | HTTP `401 {detail:"Invalid credentials"}` | [login L475–485](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L475-L485) |
| Provider inconnu / login limité / provider défaillant | HTTP 404 / 429 / 503, enveloppe `detail` ; limite locale de 10 tentatives sur 60 s | [login et limite](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L382-L485) |
| API sans session ou session expirée | HTTP 401 `{error:"unauthenticated"|"session_expired",detail:"Unauthorized",reason,login_url}` | [middleware L72–86](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/middleware.py#L72-L86) |
| RT natif rejeté | HTTP 401 `{error:"session_expired",detail:"Refresh token expired or invalid; start a new sign-in."}` ; RT vide 400, provider inaccessible 503 | [refresh L594–617](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/dashboard_auth/routes.py#L594-L617) |
| WS credentials refusés / guard refusé | Fermeture pré-accept 4401 / 4403 ; chat désactivé donne aussi 4403 ; selon client ASGI, refus visible comme échec HTTP d’upgrade plutôt qu’une close frame | [guard exact](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/hermes_cli/web_routers/chat_ws.py#L161-L173) ; interprétation transport à tester sur Android |
| JSON invalide / méthode RPC inconnue / clé de paramètre inconnue | JSON-RPC `{jsonrpc:"2.0",id,error:{code,message}}` avec `-32700` / `-32601` / `4000` | [parsing](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/tui_gateway/ws.py#L410-L419), [dispatch](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/tui_gateway/rpc_dispatch.py#L17-L41) |
| Backend en retrait | RPC code `5035`, reconnexion demandée | [admission](https://github.com/NousResearch/hermes-agent/blob/d923a5eb487a17c0a68801bba9ef0f56c81040a8/tui_gateway/rpc_dispatch.py#L8-L14) |

L’enveloppe mobile `code` namespacé, `retryable`, `operationKey?` reste un modèle **local à concevoir** : ce n’est pas l’enveloppe native du serveur. Les erreurs réseau sans réponse HTTP restent distinctes des 401 ; les messages serveur bruts peuvent contenir des détails et ne doivent pas être affichés ou journalisés sans filtrage. La règle locale de ne jamais transmettre les credentials à une autre origine reste requise ; elle ne découle pas d’une preuve que tout client HTTP gère déjà correctement les redirections.

## Add-on 1.3.9 et vérifications différées

Le tag public de l’add-on est **`v1.3.9`**, commit **`64cdcb5ce4527bb0e3635f2dc57e11c087c50abd`**, confirmé par la [liste de tags GitHub](https://api.github.com/repos/WolframRavenwolf/hermes-ha-addon/tags?per_page=100) ; [arbre épinglé](https://github.com/WolframRavenwolf/hermes-ha-addon/tree/64cdcb5ce4527bb0e3635f2dc57e11c087c50abd). L’examen de son script de démarrage, de son image et du SHA Hermes réellement embarqué reste **non réalisé** : aucune équivalence `add-on 1.3.9 = Hermes v0.22.2` n’est établie. L’option `enable_desktop_backend`, le mapping 9119, l’utilisateur `hermes` et le lien vers `access_password` restent à vérifier dans ce code et, ensuite, sur l’installation activée ; ils ne sont pas élevés ici au rang de contrat confirmé.

À faire après activation autorisée : relever `/api/health` et `/api/status` sans secret, déterminer le build effectif, vérifier les providers, le flux d’auth choisi, le ticket et `gateway.ready`, puis les lectures de profils et la politique de défaut. Capturer des fixtures anonymisées seulement lors de cette future observation, avec tests anti-secret et comparaison au contrat documentaire. La reprise, le routage de deux profils et l’absence de double exécution nécessiteront des validations séparées ; aucune méthode conversationnelle mutante n’a été appelée dans cette recherche.

Le checkpoint documentaire peut préparer les specs 1.3–1.7, mais la capture du contrat installé et l’acceptation réelle restent ouvertes. Les lectures distantes ont porté uniquement sur les docs publiques et le code GitHub ; un refus HTTP 429 sur une lecture raw a été contourné par lecture de contenu via l’API GitHub, sans consultation de HEAD ni accès au serveur personnel.
