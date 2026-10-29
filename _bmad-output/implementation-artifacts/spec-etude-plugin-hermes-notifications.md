---
title: 'Étude — plugin Hermes de notifications (essai on_session_end)'
type: 'chore'
created: '2026-10-29'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '42265b2b6179514e38a873438278c285ed5f6991'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-5-5-valider-notifications-telephone.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** L'observateur (add-on HA, Tailscale Services, URL + bearer par profil) est jugé trop lourd par Alanc. Un plugin Hermes réagissant à `on_session_end` pourrait le remplacer, mais rien ne prouve encore que ce hook se déclenche pour les tours lancés depuis l'app ni quel `session_id` il porte.

**Approche :** Écrire un plugin d'essai minimal qui journalise chaque `on_session_end` (métadonnées seulement), l'installer dans le profil `.hermes` de l'add-on Hermes, jouer quelques tours depuis l'app et consigner ce que le journal prouve.

## Boundaries & Constraints

**Toujours :** Le plugin ne journalise que les kwargs du hook (identifiants, booléens, modèle, plateforme), jamais de contenu conversationnel. Il échoue silencieusement (aucune exception ne remonte au tour). Écriture brève, sans réseau. Chaque action sur Home Assistant (copie, modification de `config.yaml`, redémarrage) est annoncée avant exécution. Sauvegarde de `config.yaml` avant modification.

**Décision (Alanc, 2026-10-29) :** Alanc installe lui-même (copie, activation, redémarrage) ; l'agent livre le plugin et la procédure, puis lit les journaux via Samba en lecture seule.

**Jamais :** Envoyer une notification FCM, ouvrir un port, enregistrer une commande slash ou toucher à l'observateur existant (hors périmètre de l'essai). Installer sur un autre profil que `.hermes`.

## I/O & Edge-Case Matrix

| Scénario | Situation | Attendu | Gestion d'erreur |
|---|---|---|---|
| Tour terminé depuis l'app | Message envoyé, réponse complète | 1 ligne : `completed: true`, `platform`, `session_id` | — |
| Tour interrompu | Arrêt du travail depuis l'app | 1 ligne : `interrupted: true` | — |
| Fichier non inscriptible | Droits ou disque | Tour inchangé, avertissement dans `agent.log` | `except Exception` + `logger.warning` |

</frozen-after-approval>

## Code Map

- `\\homeassistant.local\addon_configs\0a6523c6_hermes_agent\.hermes\` — `HERMES_HOME` du profil `.hermes` (Samba, lecture/écriture). SSH fermé.
- `.hermes/hermes-agent/agent/turn_finalizer.py:797` — appel `on_session_end` à chaque tour sauf `_persist_disabled` : kwargs `session_id, task_id, turn_id, completed, failed, interrupted, turn_exit_reason, model, platform` (+ `telemetry_schema_version`). Synchrone, borné par `plugins.hook_callback_timeout` (30 s), exceptions journalisées.
- `.hermes/hermes-agent/tui_gateway/agent_factory.py` — la passerelle TUI (backend desktop 9119, utilisé par l'app) charge les plugins.
- `.hermes/plugins/rtk-rewrite/` — modèle local : `plugin.yaml` (`name, version, description, hooks, provides_hooks`) + `__init__.py` avec `register(ctx)`.
- `.hermes/config.yaml:107` — `plugins.enabled: [homeassistant, rtk-rewrite]`.
- `.hermes/logs/agent.log` — destination du `logging` Hermes.

## Tasks & Acceptance

**Exécution :**
- [x] `server/hermes-plugin/hermes-mobile-spike/plugin.yaml` — manifeste `hooks: [on_session_end]` — calqué sur `rtk-rewrite`.
- [x] `server/hermes-plugin/hermes-mobile-spike/__init__.py` — `register(ctx)` enregistre un callback qui ajoute une ligne JSON (horodatage + kwargs) à `session-end.jsonl` dans le dossier du plugin, plus `logger.info` ; auto-vérification `__main__` qui appelle le callback sur un fichier temporaire.
- [x] `server/hermes-plugin/README.md` — procédure d'installation pour Alanc (copie Samba, `hermes plugins enable hermes-mobile-spike` ou ajout à `plugins.enabled` après sauvegarde, redémarrage, vérification, désinstallation). Après installation par Alanc : `hermes plugins list` ou `/plugins` (ou `agent.log`) confirme le chargement.
- [x] Essais — Alanc joue depuis l'app : un tour complet, un tour arrêté ; l'agent lit `session-end.jsonl` via Samba et compare `session_id` avec l'id stocké de la session (table `sessions` de `state.db`, lecture seule).
- [x] `_bmad-output/implementation-artifacts/investigation-plugin-hermes-notifications.md` — constats : déclenchement, `platform`, nature de `session_id` (runtime ou stocké), latence, et questions restantes (commande slash, signature OAuth FCM, persistance aux mises à jour).

**Critères d'acceptation :**
- Étant donné le plugin installé, quand Hermes redémarre, alors il apparaît chargé sans avertissement.
- Étant donné les essais joués, quand le rapport est relu, alors chaque constat cite une ligne de journal expurgée et la réponse go / no-go pour la suite (FCM) est explicite.

## Review Triage Log

| Constat | Verdict | Preuve | Suite |
|---|---|---|---|
| NaN/Infinity non JSON | false | Les clés retenues sont des chaînes et booléens (lignes observées), aucun flottant. | rejeté |
| Écritures concurrentes sans verrou | low | Lignes courtes en mode ajout, essai mono-utilisateur. | rejeté |
| Journal sans limite de taille | low | ~400 o/tour, désinstallation documentée. | rejeté |
| README : bloc `plugins.enabled` à coller | low | Coller le bloc écraserait une liste différente. | patch |
| Rapport : latence annoncée non traitée | low | Aucune mesure dans le rapport. | patch (constat 6) |
| Rapport : constats sans extrait cité | low | Constats 3, 5, 7 sans extrait. | patch |
| Rapport : lignes JSON tronquées | low | `...` masquait `extra_keys` absent. | patch |
| Rapport : « une fois par tour » sur deux tours | medium | Échec, outils, sous-agents, `/new` non essayés. | patch (questions) |
| Rapport : constat 3 généralisé | medium | Seule une conversation nouvelle essayée. | patch |
| Rapport : borne 30 s sans source | low | Confirmée : `hermes_cli/plugins_dispatch.py:45`. | patch (citation) |
| Rapport : état de l'add-on non noté | low | Plugin toujours actif. | patch |
| `provides_hooks` erroné | false | Même manifeste que `rtk-rewrite`, hook déclenché. | rejeté |
| `turn_exit_reason` texte libre | false | Valeurs fixes (`interrupt_control.py:48`, `turn_finalizer.py:138,170,560`). | rejeté |
| Self-check : clé retenue non scalaire, avertissement non vérifié | low | Branche `type(value).__name__` non couverte. | patch |
| README : vérification échouerait sur la ligne capability | false | Ligne `INFO`, pas un avertissement. | rejeté |
| Rapport : transition observateur → plugin absente | low | Doublons possibles. | patch (questions) |
| Self-check hors CI | medium | `ci.yml` ne lance pas `server/hermes-plugin`. | defer |

## Verification

**Commandes :**
- `python server/hermes-plugin/hermes-mobile-spike/__init__.py` — auto-vérification réussie.

**Vérification manuelle :**
- `session-end.jsonl` sur le partage Samba contient une ligne par tour joué, sans contenu.
