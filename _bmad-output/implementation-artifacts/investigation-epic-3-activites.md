# Investigation — activités et contrôle Hermes

Date : 22 octobre 2026. Préparation de la story 3.1 ; aucun code applicatif modifié, aucun accès à l’installation privée ou envoi de demande réalisé.

## Preuves disponibles

Le contrat local est documentaire, au SHA `9e01b44dd23978f9ff40b7837467f3a9f1582130` ; `contracts/README.md` et `capabilities.json` précisent que les capacités réelles restent non vérifiées. Les fixtures sont synthétiques. Le build observé par health ne prouve pas l’équivalence du comportement installé.

La vérification de la source officielle épinglée retrouve :

- [Schémas d’événements](https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/contracts/events.py#L354-L387) : `tool.start` exige `tool_id` et `name` ; `context`, `args`, `args_text`, `preview`, `labels` sont optionnels. `tool.complete` porte la même identité ; `args`, `duration_s`, `result`, `summary`, `result_text`, `inline_diff`, `todos`, `revision`, `labels` peuvent être présents. Ne pas confondre disponibilité d’un champ dans le schéma et réception effective.
- [Émetteur des activités](https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/tool_progress.py#L276-L362) : `tool_id` reprend `tool_call_id` ; l’émission dépend des chemins et réglages de progression. Le résultat peut être structuré ou textuel. L’absence de fin ne constitue jamais une fin implicite.

Le mapping local connaît `tool.start` et `tool.complete`, mais l’extrait `contracts/openrpc.json` ne les inclut pas dans ses notifications sélectionnées. Le script `tool/extract_openrpc.py` sélectionne une surface limitée. La seule fixture locale d’outil ne porte que `name: SYNTHETIC` : elle doit être complétée sans être présentée comme capture réelle.

Pour 3.1, les seules familles justifiées par le mapping actuel sont `tool` et `unknown`. Les familles plus précises de la recherche UX proviennent d’autres chemins/commits ; aucune classification de l’installation ne doit en être déduite.

## Réutilisation et lacunes locales

- `ActivityItem` ne conserve que tour/famille ; ni ID ni fin. `EventMapping` produit le même effet pour début et fin. `_reduce` fusionne les activités adjacentes de même famille : plusieurs outils deviennent une ligne.
- `_apply` protège les séquences ; les mutations de projection sont sérialisées par fil. Conserver ces garanties et leur portée connexion/profil/session/epoch. Une identité d’événement ne remplace pas une identité d’action.
- `accepted` rattache les activités de tour zéro à la première demande : préserver tous les nouveaux champs lors de cette copie.
- Les projections JSON existantes demandent une lecture compatible, pas une migration destructive. Les entrées sans ID restent génériques ; ne pas les raccrocher par nom.
- `HermesRpc.history` ne décode actuellement que le texte utilisateur/assistant. Le snapshot reconstruit donc un fil sans outils. Le rejeu peut restituer les événements disponibles ; un historique sans métadonnées ne permet ni détails ni fins d’action reconstitués.
- `ActivityLine`, `StatusLabel`, `Content`, tokens et galerie existent. `_timeline` garde des blocs paresseux sous une réservation Otc par tour ; ne pas remplacer tout le tour par une grande colonne construite d’avance.

## Continuité Otc

Specs lots 1 à 4 terminées : anatomie v5 et interactions locales, présence profils et nom Otc, fonds locaux par identité, accompagnement de réponse. Les contrats courants UX du 22 octobre priment sur les paragraphes historiques : lapin seul pour l’intention des points de préparation, activité conservée, statut live unique près de la saisie. Aucun mouvement ne prouve la progression ou une réussite.

## Vérification réelle et suite

La disponibilité effective de `tool.start`/`tool.complete`, de leurs IDs et des champs optionnels reste ouverte sur l’installation personnelle. Les essais locaux devront être présentés comme tels. Ne pas rendre un marqueur de fin en l’absence de preuve reçue.

La commande d’arrêt relève de 3.5 : la méthode documentaire `session.interrupt` et le mapping `message.complete.status=interrupted` ne démontrent pas une interruption réelle. L’opération locale devra rester distincte de la projection ; ni accusé RPC, ni silence, ni coupure ne confirmeront l’arrêt. Réexaminer capacités, ciblage et reprise dans sa propre spécification.

Deux arbitrages UX sont proposés dans la spec 3.1 : signe visible de fin et repli en présence d’activités sans fin confirmée. Aucun n’est considéré approuvé.
