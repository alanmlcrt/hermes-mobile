# Contrat documentaire Hermes

Référence officielle : **v0.22.2+1690 (main 9e01b44)**, commit `9e01b44dd23978f9ff40b7837467f3a9f1582130` de NousResearch/hermes-agent, soit le build observé via `/api/health` (`displayVersion 0.22.2+1690`) ; ce build n’est pas validé (`installedBuild = observed-health`). Le tag `v0.22.2` (`d923a5eb487a17c0a68801bba9ef0f56c81040a8`) n’est plus que la base, conservée dans `release.json` (`baseTagCommit`). `openrpc.json` est un extrait du fichier généré officiel : treize méthodes (connexion, création et suite de conversation : `session.list/history/resume/status`, `prompt.submit`, `session.interrupt/title`), dix notifications (`gateway.ready`, `message.*`, `error`, `session.info`, `status.update`, `sessions.changed`, `session.title`) et les schémas atteints par leurs références. `tool/extract_openrpc.py` le reconstruit depuis le fichier officiel complet. `x-provenance` conserve release, SHA, source et nature documentaire de l’extrait ; `methods.json` décrit la surface appelée, avec les liens épinglés.

Les fixtures sont **synthétiques**, avec des marqueurs de secrets fictifs. Le backend personnel n’a pas été contacté. Aucune équivalence avec le build de l’add-on n’est établie ; la capture 1.3/G1 et les vérifications sur téléphone restent ouvertes.

### Activités compactes (3.1)

Les [schémas officiels épinglés](https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/contracts/events.py#L354-L387) définissent `tool.start` (`tool_id`, `name`, puis `context`, `args`, `args_text`, `preview`, `labels` optionnels) et `tool.complete` (même identité ; `args`, `duration_s`, `result`, `summary`, `result_text`, `inline_diff`, `todos`, `revision`, `labels` optionnels). L’[émetteur](https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/tool_progress.py#L276-L362) reprend `tool_call_id` dans `tool_id` ; ses chemins et réglages conditionnent l’émission. Ces notifications ne font pas partie de l’extrait OpenRPC sélectionné localement.

`fixtures/tool-start.json` et `tool-complete.json` sont des exemples synthétiques, jamais des captures de l’installation. Les champs documentés et leur disponibilité effective restent distincts (`capabilities.json.activityEvents.actual = unverified`). Seuls le mapping `tool`/`unknown`, l’ID opaque et les preuves de début/fin reçues servent à la projection ; ni le nom ni un emoji ne déterminent une famille précise. La fin d’action ne prouve aucune réussite ni fin du travail. Sans ID, chaque événement reste une entrée générique séparée.

La projection persistée conserve ces preuves sans migration destructive. Les anciennes projections deviennent génériques sans fin supposée. `session.history` ne décode actuellement que le texte : une reprise par snapshot sans outils ne reconstitue aucune activité ; le rejeu peut seulement conserver les événements effectivement disponibles.

`capabilities.json` sépare présence documentaire et état réel non vérifié. Seules les réponses effectives (GET profils, `gateway.ready`, `gateway.capabilities`) changent les états en mémoire. Les capacités futures mutantes restent non vérifiées ; aucun envoi ni création de conversation n’est utilisé comme sonde. `event-mapping.json` décrit les événements utilisés ici, avec un type inconnu explicite ; les états de travail hors périmètre restent nuls.

Login JSON, cookies de session explicitement extraits, REST bearer, refresh puis relogin via coffre. Le ticket WS est un sous-protocole, sans secret dans l’URL ; les redirections sont refusées. Aucun POST de sélection globale.

Après activation autorisée : comparer build et contrat, capturer les réponses expurgées, vérifier auth, profils, ticket, reprise, deux profils, texte 200 % et TalkBack. La présence documentaire ne vaut jamais validation réelle.

## Détails d’action (story 3.2)

`tool.start` et `tool.complete` peuvent fournir `name`, `context`, `args`,
`args_text`, `preview`, `result`, `result_text`, `inline_diff`. Seuls ces champs
sont conservés ; les textes sont des chaînes et args/result sont des valeurs JSON.
Une fin enrichit la même identité selon les règles 3.1 : omission conserve,
null explicite supprime. Les données structurées priment sur les textes de secours.
Seule une chaîne non vide dans `result.error` produit une section Erreur ; ni code
de sortie, ni nom MCP, ni texte libre ne modifie le statut global.
Les données restent du texte sélectionnable, jamais exécuté. Aucun RPC au dépliage.
Les textes peuvent être expurgés ou tronqués par le serveur : leurs marqueurs sont
conservés et l’interface ne promet pas une sortie complète. Un snapshot textuel ne
reconstitue aucun détail. Toutes les fixtures outil sont synthétiques ; la
disponibilité sur une installation réelle reste **unverified**.
# Arrêt du travail (story 3.5)

`session.interrupt` est documenté dans le contrat OpenRPC versionné : runtime
`session_id`, `profile`, et `expected_hosted_task_id` optionnel. Le mobile ne
reçoit pas d'identité de tâche hébergée fiable ; il omet ce dernier champ et
revérifie son repère local de tour avant transmission. Cela ne garantit pas
l'isolation entre clients distants.

La réponse `interrupted` / `not_interrupted` est un résultat RPC, jamais un
terminal. Seul `message.complete.status=interrupted` confirme l'arrêt dans la
projection. Refus, méthode absente, réponse invalide et résultat incertain sont
affichés ; aucun protocole alternatif ni renvoi automatique n'est utilisé.
Ces preuves documentaires et les tests synthétiques ne valident pas
l'installation personnelle de Hermes.
