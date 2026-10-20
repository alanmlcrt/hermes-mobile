# Catalogue proposé — 17 illustrations

Direction demandée : dessins simples, traits affirmés, davantage de mouvement. Source des actions et emojis : [recherche Hermes épinglée](hermes-tool-activity-research.md), 27 outils vérifiés. Les familles ci-dessous constituent une proposition de présentation ; ce ne sont pas de nouveaux outils ou une preuve de disponibilité sur le serveur personnel.

| Illustration | Correspondance proposée avec les événements amont vérifiés |
| --- | --- |
| Ordinateur qui écrit du code | Vue spécialisée d’une activité de code ; ne pas la déduire de tout appel `terminal` ou `write_file`. |
| Page qui se remplit | `write_file` |
| Machine appelant un outil | Outils MCP ou personnalisés ; ne pas inférer leur intention depuis leur seul nom. |
| Recherche web à la loupe | `web_search` |
| Lecture de fichier | `read_file`, éventuellement `web_extract` avec libellé adapté |
| Console qui exécute | `terminal` |
| Navigateur et pointeur | `browser_navigate`, `browser_scroll`, `browser_click`, `browser_type` regroupés visuellement |
| Crayon qui modifie | `patch` |
| Dossier et fiche | `search_files` |
| Pinceau qui dessine | `image_generate` |
| Note rejoignant un carnet | `memory` ; le verbe exact doit distinguer consultation et modification. |
| Assistants et signaux partagés | `delegate_task` |
| Liste d’étapes | Métaphore proposée d’organisation, aucun nom d’outil vérifié pour cette famille. |
| Image explorée par une zone de lecture | `vision_analyze`, éventuellement `browser_vision` avec libellé adapté |
| Livre aux pages tournantes | `skills_list`, `skill_view` ; ne pas confondre avec administration des compétences. |
| Calendrier et horloge | `cronjob_manage`, avec libellé adapté à l’opération réellement reçue |
| Trois petits points en rotation | État générique de préparation de réponse, sans bulle ; aucun accès à un raisonnement privé supposé. |

Le futur client choisira une famille sur la base d’un événement fiable fourni par Hermes. Outil inconnu : libellé et pictogramme génériques. Aucun emoji ne sert de clé d’identification : ils peuvent être personnalisés. Aucun pourcentage, succès ou temps restant déduit de l’animation.

Dernier retour d’Alanc : indicateurs plus petits ; ordinateur de code immobile. La [référence Sparky](sparky-reference.md) motive une ligne d’activité compacte. La préparation utilise trois points tournants, conformément à sa demande, alors que les points Sparky rebondissent.

La sélection et le défilement automatique de cette maquette sont des commandes de démonstration hors interface produit. Le défilement change d’illustration toutes les 4,6 secondes, respecte pause et préférence de mouvement réduit, et s’arrête sur une sélection manuelle. Les formes et leur dynamisme attendent le retour visuel d’Alanc.
