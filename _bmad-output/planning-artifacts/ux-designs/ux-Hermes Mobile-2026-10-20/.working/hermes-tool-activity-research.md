# Hermes : activités et emojis réels

Recherche ciblée du 20 octobre 2026. Dépôt officiel `NousResearch/hermes-agent`, branche main résolue par API au commit **5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2**. Lecture de sources via API GitHub, sans exécuter leur code. Ce relevé décrit l'amont actuel, pas la version installée chez Alanc.

## Lien avec Discord vérifié

1. Les modules enregistrent leur outil et son emoji dans `registry.register`. [`registry.get_emoji`](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/registry.py#L1001) lit cette valeur.
2. [`get_tool_emoji`](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/agent/display.py#L161) applique d'abord une éventuelle surcharge du skin, puis le registre, puis une valeur par défaut. Les emojis ci-dessous sont donc les valeurs enregistrées, pas une garantie de rendu identique sur toutes les installations.
3. Le [callback de progression gateway](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/gateway/run_turn_progress.py#L145) reçoit les événements d'outil. Le [rendu de message](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/gateway/run_turn_progress.py#L291) appelle bien `get_tool_emoji`, avec défaut **⚙️**, puis un libellé convivial lorsqu'il est défini.
4. La progression est envoyée à [l'adaptateur de la destination](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/gateway/run_turn_progress.py#L738), et le [message passe par `adapter.send`](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/gateway/run_turn_progress.py#L624). Le dépôt contient bien un [DiscordAdapter](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/plugins/platforms/discord/adapter.py#L1221), sa [méthode send](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/plugins/platforms/discord/adapter.py#L3246) et son support des blocs de code. Ce mécanisme n'est donc pas limité au CLI.

Limites : la progression doit être activée ; ce chemin rend surtout `tool.started`, filtre notamment `clarify`, et peut regrouper/éditer les messages. L'observation d'une icône ne constitue ni un pourcentage, ni une preuve de succès. La maquette mobile ne doit pas supposer que ce transport Discord est celui du futur client.

## Correspondances vérifiées — 27 outils

Les deux dernières colonnes sont des **suggestions UX**, pas les catégories ou traductions contractuelles d'Hermes. Les noms techniques restent dans les détails. Un pictogramme peut partager une famille d'animation sans perdre l'activité réelle.

| Outil exact | Emoji enregistré | Activité française suggérée | Pictogramme SVG animé suggéré | Source |
| --- | --- | --- | --- | --- |
| `terminal` | 💻 | Exécution en cours | Petit écran, curseur qui pulse et deux traits qui apparaissent. | [Terminal](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/terminal_tool.py#L1687) |
| `read_file` | 📖 | Lecture d'un fichier | Livre ouvert, page qui se soulève doucement. | [Fichiers](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/file_tools.py#L1405) |
| `write_file` | ✍️ | Écriture en cours | Crayon court suivant une ligne. | Fichiers, L1406 |
| `patch` | 🔧 | Modification en cours | Petite clé qui oscille d'un angle limité. | Fichiers, L1429 |
| `search_files` | 🔎 | Recherche dans les fichiers | Loupe parcourant deux petites feuilles. | Fichiers, L1430 |
| `web_search` | 🔍 | Recherche sur le web | Loupe sur un globe simple. | [Web](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/web_tools.py#L559) |
| `web_extract` | 📄 | Lecture d'une page | Feuille et surlignage qui glisse. | Web, L565 |
| `browser_navigate` | 🌐 | Ouverture d'une page | Globe, petit repère qui avance sur un arc. | [Table navigateur](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/browser_tool.py#L1340) |
| `browser_snapshot` | 📸 | Observation de la page | Cadre de prise de vue, battement discret de l'obturateur. | Table navigateur, L1342 |
| `browser_click` | 👆 | Interaction avec la page | Pointeur qui se pose, anneau bref autour du point. | Table navigateur, L1343 |
| `browser_type` | ⌨️ | Saisie en cours | Clavier simple avec touches alternées. | Table navigateur, L1344 |
| `browser_scroll` | 📜 | Parcours de la page | Deux lignes qui glissent dans une fenêtre. | Table navigateur, L1345 |
| `browser_back` | ◀️ | Retour à la page précédente | Flèche courbe, déplacement bref vers la gauche. | Table navigateur, L1346 |
| `browser_press` | ⌨️ | Interaction au clavier | Une touche qui s'enfonce doucement. | Table navigateur, L1347 |
| `browser_get_images` | 🖼️ | Consultation des images | Petit cadre image, second cadre qui se dévoile. | Table navigateur, L1348 |
| `browser_vision` | 👁️ | Observation de la page | Œil et balayage très court du regard. | Table navigateur, L1349 |
| `browser_console` | 🖥️ | Vérification de la page | Petit écran avec un trait d'activité. | Table navigateur, L1350 |
| `image_generate` | 🎨 | Création d'une image | Palette et tache simple qui se dessine. | [Image](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/image_generation_tool.py#L990) |
| `vision_analyze` | 👁️ | Analyse d'une image | Œil posé sur un petit cadre. | [Vision](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/vision_tools.py#L1030) |
| `video_analyze` | 🎬 | Analyse d'une vidéo | Bande de trois vignettes défilant d'un cran. | Vision, L1185 |
| `memory` | 🧠 | Mise à jour de la mémoire | Petit carnet, marque-page qui se place. | [Mémoire](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/memory_tool.py#L476) |
| `skills_list` | 📚 | Consultation des compétences | Deux livres, troisième qui dépasse légèrement. | [Skills](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/skills_tool.py#L731) |
| `skill_view` | 📚 | Lecture d'une compétence | Livre ouvert et petite ligne de lecture. | Skills, L763 |
| `skill_manage` | 📝 | Mise à jour d'une compétence | Note et crayon faisant un petit trait. | [Gestion skills](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/skill_manager_tool.py#L925) |
| `delegate_task` | 🔀 | Travail délégué en cours | Deux flèches qui se séparent puis reviennent au repos. | [Délégation](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/delegate_tool.py#L807) |
| `cronjob_manage` | ⏰ | Planification en cours | Petite horloge et aiguille oscillant sur un court arc. | [Planification](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/cronjob_tools.py#L1192) |
| `session_search` | 🔍 | Recherche dans les conversations | Bulle avec petite loupe. | [Historique](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/session_search_tool.py#L797) |

Hermes contient déjà des [libellés français conviviaux](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/locales/fr.yaml#L3668), par exemple Recherche sur le web, Lecture, Écriture, Modification, Exécution et Planification. Les suggestions ci-dessus simplifient encore certains termes ; elles ne prétendent pas être le texte exact affiché par Discord.

## Cas à traiter sans inventer de correspondance

- **MCP :** [l'enregistrement dynamique](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/mcp_tool_registration.py#L353) ne fournit pas d'emoji. Dans le chemin gateway vérifié, cela conduit au défaut **⚙️**, sauf surcharge du skin. Proposition : deux maillons qui se rapprochent, libellé générique « Action en cours » tant qu'une sémantique fiable n'est pas disponible. Le nom du serveur MCP seul ne prouve pas si l'action lit, écrit ou envoie.
- **Messagerie :** dans ce commit, [`send_message` est explicitement NON enregistré comme outil appelable par le modèle](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/tools/send_message_tool.py#L28). Les helpers servent notamment à cron, CLI et serveur MCP opt-in. Aucune association « send_message = tel emoji » ne doit être présentée comme vérifiée. Une enveloppe animée reste une proposition pour une réelle action d'envoi exposée par le backend.
- **Processus :** `terminal` est vérifié, mais aucun emoji distinct pour un outil `process` n'est établi par cette recherche ciblée. Ne pas annoncer une catégorie autonome vérifiée.
- **Réflexion/statut générique :** `_thinking` est traité à part et relayé uniquement sur option explicite ; le catalogue [gateway français](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/locales/fr.yaml#L975) utilise **💬 {text}**. Ne pas transformer cela en accès garanti à un raisonnement interne. Proposition visuelle générique : bulle et trois points calmes, sans texte interne inventé.
- **Outils personnalisés/inconnus :** les [verbes conviviaux sont une liste curatée](https://github.com/NousResearch/hermes-agent/blob/5e7f880d509bd6ef6a773b5cb727b1d952a1d2c2/agent/display.py#L531), pas une classification universelle. Prévoir un pictogramme de repli et garder le nom réel dans les détails plutôt que deviner l'intention à partir d'un sous-mot.

## Conséquence pour la prochaine maquette

Proposer une famille de petits pictogrammes vivants, lisibles à 32–48 px, partageant trait, volume et cadence. Les 27 noms permettent bien plus de quatre activités ; il n'est pas nécessaire d'avoir 27 animations complètement indépendantes. Changer la famille sur un événement d'outil fiable ; l'animation signifie seulement « activité en cours ». En mode de mouvement réduit, conserver un pictogramme immobile et son libellé. Le lien transport/événements du Hermes installé reste à vérifier en architecture.
