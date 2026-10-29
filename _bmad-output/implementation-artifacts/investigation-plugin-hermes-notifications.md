# Investigation — plugin Hermes de notifications (essai `on_session_end`)

Date : 2026-10-29. Spec : [spec-etude-plugin-hermes-notifications.md](spec-etude-plugin-hermes-notifications.md).

## Protocole

Plugin `hermes-mobile-spike` (`server/hermes-plugin/`) installé et activé par Alanc sur le profil `.hermes` de l'add-on Hermes 1.3.9, puis add-on redémarré. Depuis l'app, dans une conversation nouvelle : un tour complet, puis un tour arrêté. Journal lu en lecture seule via Samba ; `state.db` copié dans un dossier temporaire puis interrogé ; source Hermes lue sur le partage.

## Constats

**1. Le hook se déclenche pour les tours de l'app, une ligne par tour joué.** `session-end.jsonl`, lignes complètes (aucune `extra_keys` : Hermes n'a passé que les kwargs attendus) :

```json
{"ts": "2026-10-29T20:22:42.589+00:00", "session_id": "20261029_212234_ce7c72", "task_id": "20261029_212234_ce7c72", "turn_id": "20261029_212234_ce7c72:20261029_212234_ce7c72:1200919e", "completed": true, "failed": false, "interrupted": false, "turn_exit_reason": "text_response(finish_reason=stop)", "model": "gpt-6.1-sol", "platform": "tui", "telemetry_schema_version": "hermes.observer.v1"}
{"ts": "2026-10-29T20:22:58.552+00:00", "session_id": "20261029_212234_ce7c72", "task_id": "20261029_212234_ce7c72", "turn_id": "20261029_212234_ce7c72:20261029_212234_ce7c72:24c76d9b", "completed": false, "failed": false, "interrupted": true, "turn_exit_reason": "interrupted_during_api_call", "model": "gpt-6.1-sol", "platform": "tui", "telemetry_schema_version": "hermes.observer.v1"}
```

**2. `platform` vaut `tui`** pour les tours lancés depuis l'app (passerelle TUI, backend desktop) — mêmes lignes.

**3. `session_id` est l'identifiant stocké, pour une conversation nouvelle.** Requête `select id, source, started_at, title from sessions where id like '%ce7c72%'` sur la copie de `state.db` :

```
('20261029_212234_ce7c72', 'tui', 1793305354.79, 'Start friendly conversation #4')
```

C'est l'identifiant que l'app connaît ; pour ce cas, aucune correspondance runtime → stocké n'est nécessaire. Une conversation reprise (cas de l'erreur 4007 avec l'observateur) n'a pas été essayée.

**4. Arrêt distinct de la fin normale.** `completed`, `interrupted` et `turn_exit_reason` suffisent. `turn_exit_reason` est une valeur fixe (`agent/interrupt_control.py:48`, `agent/turn_finalizer.py:138,170,560`), pas un texte libre.

**5. Chargement sans erreur.** `logs/agent.log` :

```
2026-10-29 21:22:42,590 INFO hermes_mobile_spike: hermes-mobile-spike on_session_end session_id=20261029_212234_ce7c72 platform=tui completed=True interrupted=False
```

La ligne `INFO hermes_cli.plugin_capabilities: capability_check plugin=hermes-mobile-spike capability=tools.override decision=deny` apparaît aussi pour `homeassistant` et `rtk-rewrite` ; elle concerne le remplacement d'outils, et le hook s'est déclenché malgré elle.

**6. Délai borné.** `on_session_end` figure dans `_HOOK_TIMEOUT_BOUNDED_HOOKS` (`hermes_cli/plugins_dispatch.py:45`) : appel synchrone en fin de tour, abandonné après `plugins.hook_callback_timeout` (30 s par défaut). La latence entre la fin de réponse visible dans l'app et le hook n'a pas été mesurée ; le hook est appelé dans `finalize_turn`, après la réponse.

**7. Signature OAuth disponible.** `venv/lib/python3.14/site-packages/` contient `google_auth-2.55.1`, `cryptography-50.0.1`, `pyjwt-2.15.1`, `requests-2.33.0`, `httpx-0.28.1` : un jeton FCM HTTP v1 peut être obtenu depuis un compte de service sans installer de dépendance.

## Décision

**Go** pour une étude suivante : un plugin `on_session_end` → FCM est une voie crédible pour remplacer l'observateur. Les cas non essayés ci-dessous doivent être vérifiés avant de s'y fier.

## État laissé

Plugin d'essai toujours installé et activé sur `.hermes` (une ligne par tour, ~400 octets). `config.yaml` modifié par Alanc. Désinstallation : `server/hermes-plugin/README.md`.

## Questions restantes (prochaine étude)

- **Cas non essayés** : tour en échec (`failed: true`), tour avec outils, sous-agents (`delegate_task` : un enfant déclenche-t-il aussi `on_session_end`, avec quel `session_id` ?), conversation reprise, `/new` ou fin de session. Chacun peut produire des notifications en trop ou manquantes.
- **Enregistrement du jeton FCM du téléphone** : commande slash (`ctx.register_command`) appelable depuis l'app via la passerelle TUI, ou autre canal ?
- **Envoi non bloquant** : l'envoi FCM doit partir dans un fil en arrière-plan (borne de 30 s, constat 6).
- **Persistance aux mises à jour** : `plugins/` et `config.yaml` sont dans `/config/.hermes`, hors du dépôt `hermes-agent/`. Survie probable, non constatée.
- **Multi-profils** : un plugin par profil (`.hermes/profiles/<nom>/plugins/`) ou installation commune ?
- **Compte de service** : où le déposer côté Hermes (hors dépôt, lisible par le plugin) ?
- **Transition** : observateur et plugin actifs ensemble enverraient des doublons ; ordre de bascule et retrait de l'observateur à définir.
