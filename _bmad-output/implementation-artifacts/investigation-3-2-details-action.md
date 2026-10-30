# Investigation — détails d’action 3.2

Préparation du 22 octobre 2026, après la story 3.1 terminée. Aucun code applicatif modifié pour 3.2, aucune installation privée contactée.

## Preuves documentaires vérifiées

Source officielle épinglée au commit `9e01b44dd23978f9ff40b7837467f3a9f1582130` :

- [Schémas d’événements, lignes 317–347](https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/contracts/events.py#L317-L347) : identité et nom requis, arguments optionnels ; fin avec résultat JSON ou texte, textes de présentation et différence éventuelle. Aucun champ d’erreur autonome dans l’enveloppe d’outil.
- [Émetteurs, lignes 253–335](https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/tool_progress.py#L253-L335) : arguments émis selon présence, `args_text` et `result_text` selon le mode verbose ; résultat analysé comme JSON si possible, sinon chaîne. Émission conditionnelle, fin isolée possible.
- [Préparation des textes verbose, lignes 6–58](https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/tool_progress.py#L6-L58) : textes expurgés et bornés côté serveur ; leur présence ne promet pas la sortie intégrale. Conserver les marqueurs de contenu omis.
- [Détection serveur des erreurs d’outil, lignes 191–209](https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/tool_progress.py#L191-L209) : un résultat structuré peut contenir une chaîne `error`, des booléens de résultat ou un code de sortie. Ne pas inventer un message depuis ces deux derniers cas ni les transformer en état global.

Les ancres historiques de l’investigation 3.1 renvoyaient à un intervalle voisin ; les liens ci-dessus ciblent précisément les définitions relues. La disponibilité effective sur le backend privé reste `unverified` ; aucune fixture locale n’est une capture réelle.

## Contrat d’affichage proposé

Liste explicite limitée à `name`, `context`, `args`, `args_text`, `preview`, `result`, `result_text`, `inline_diff` des deux événements connus. Aucun balayage des événements `reasoning.*`, des sidecars assistant ou de clés arbitraires du fallback. Les champs non fournis restent absents. Une erreur d’action demeure distincte de `WorkStateLabel` ; un événement global `error` ne s’attache jamais à un outil par proximité.

Préserver les détails déjà reçus lorsque la fin omet un champ ; un null explicite retire ce champ. Le rendu de JSON conserve ses valeurs et n’exécute aucun contenu. Le choix de priorité entre données et aperçu est soumis à approbation dans la spec. Sans détail utilisable, pas de faux chevron ni de requête réseau pour chercher un contenu inexistant.

## Continuité de 3.1

`ActivityItem` conserve actuellement identité, phases, contexte d’origine via `eventKey` et premier fragment après groupe. Les métadonnées de détail sont encore abandonnées. Réutiliser la corrélation et les copies correctives, sans refaire les identités. Le snapshot textuel ne reconstruit toujours pas les outils ; la persistance locale et le rejeu ne peuvent conserver que les données effectivement reçues.

Le choix manuel d’une action doit survivre à la reconstruction et au repli de son groupe dans la même page. Les lots Otc, le statut live unique et les blocs paresseux restent inchangés. Les composants de détail ne portent aucun contrôleur de transport ni opération d’arrêt.
