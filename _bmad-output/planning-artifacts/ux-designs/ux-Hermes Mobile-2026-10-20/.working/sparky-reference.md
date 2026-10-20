# Sparky — référence d'activité compacte

Source officielle ajoutée par Alanc : [anisayari/sparky](https://github.com/anisayari/sparky). Branche main résolue le 20 octobre 2026 au commit **7f8e9fca0077e1a6199e1495f5c0dfa7a3e0af94**. Lecture ciblée de `app/index.html` via API GitHub, sans exécution du projet. Constats de code uniquement ; aucune application Sparky lancée ni capture interprétée comme preuve du mouvement.

## Ce que fait réellement le code

| Élément | Taille / comportement observé | Preuve épinglée |
| --- | --- | --- |
| Attente de réponse | Exactement **3 points de 7 × 7 px**, espacés de 4 px. Cycle 1,2 s ; décalages 0,2 et 0,4 s. Chaque point passe d'opacité 0,3 à 1 et monte de 3 px. **Ils ne tournent pas** dans Sparky. | [CSS `.typing`, `.dots`, `@keyframes d`, L88–94](https://github.com/anisayari/sparky/blob/7f8e9fca0077e1a6199e1495f5c0dfa7a3e0af94/app/index.html#L88) |
| Création de l'attente | `showTyping` insère uniquement les trois points et un texte d'état facultatif. | [JS L1188](https://github.com/anisayari/sparky/blob/7f8e9fca0077e1a6199e1495f5c0dfa7a3e0af94/app/index.html#L1188) |
| Activité d'outil | Ligne compacte avec cercle incomplet **13 px**, rotation linéaire **1 s**. Carte : padding 9 × 12 px, texte 13,5 px, détails dépliables. À la fin, le cercle devient un point statique de 9 px. | [CSS `.step`, L76–87](https://github.com/anisayari/sparky/blob/7f8e9fca0077e1a6199e1495f5c0dfa7a3e0af94/app/index.html#L76) |
| Passage attente → outil | L'événement outil retire l'attente puis affiche le suivi avec détails et durée. Le résultat arrête ce suivi ; la réponse finale retire aussi l'attente. | [Rendu événements L1221–1236](https://github.com/anisayari/sparky/blob/7f8e9fca0077e1a6199e1495f5c0dfa7a3e0af94/app/index.html#L1221) |
| Web / documents / outils personnalisés | Le même composant d'activité reçoit les événements `search`, `fetch`, `docs`, `tool` ; le résultat clôt l'étape et peut ramener les points d'attente. | [Extension du rendu L1918–1931](https://github.com/anisayari/sparky/blob/7f8e9fca0077e1a6199e1495f5c0dfa7a3e0af94/app/index.html#L1918) |
| Icône ordinateur | Ordinateur SVG **14 px**, statique. Aucune transformation animée du corps de l'ordinateur dans cette définition. | [ICPC L2269](https://github.com/anisayari/sparky/blob/7f8e9fca0077e1a6199e1495f5c0dfa7a3e0af94/app/index.html#L2269) |
| Actions sur ordinateur | Icônes d'action SVG **13 px**, statiques, dans un fond de **22 px**. Lecture = œil, écriture = crayon, danger = triangle. Le mouvement vient d'un **spinner séparé de 11 px**, pas du corps du PC. | [CSS L635–642](https://github.com/anisayari/sparky/blob/7f8e9fca0077e1a6199e1495f5c0dfa7a3e0af94/app/index.html#L635), [icônes/rendu L2279–2287](https://github.com/anisayari/sparky/blob/7f8e9fca0077e1a6199e1495f5c0dfa7a3e0af94/app/index.html#L2279) |
| Spinner partagé | Cercle incomplet, rotation linéaire de 0,9 s ; sa taille générique de 16 px est réduite dans les contextes précédents. | [CSS `.spin`, L246](https://github.com/anisayari/sparky/blob/7f8e9fca0077e1a6199e1495f5c0dfa7a3e0af94/app/index.html#L246) |
| Résultat d'action ordinateur | Le spinner est remplacé par un signe de réussite ou d'erreur, et les résultats longs restent dépliables. | [Événement `cresult`, L2300–2304](https://github.com/anisayari/sparky/blob/7f8e9fca0077e1a6199e1495f5c0dfa7a3e0af94/app/index.html#L2300) |

Le code distingue bien une attente générique et une action explicite. Il ne justifie pas un grand dessin animé pour chaque instant de préparation. Aucun traitement spécifique « ordinateur écrivant du code qui se déplace » n'a été trouvé dans les composants examinés. L'écriture d'une action PC utilise un crayon statique ; il ne faut pas transformer cette observation en affirmation sur tous les usages du produit.

## Application à Hermes : décisions utilisateur et recommandations

- **Demande explicite d'Alanc :** réduire les indicateurs, utiliser seulement trois petits points tournants pendant la préparation de la réponse, garder le corps du PC immobile pendant l'écriture de code.
- **Différence assumée :** les points tournants sont le choix d'Alanc ; Sparky fait rebondir ses points. Ne pas présenter la rotation comme une reproduction de son CSS.
- **Recommandation de composition :** attente générique = trois points seuls, sans grand pictogramme ni carte dédiée. Activité d'outil = petite icône stable près du libellé, détails accessibles ensuite. Les tailles Sparky sont des observations, pas des tokens Hermes validés.
- **Recommandation de mouvement :** pour le code, laisser le châssis, le pied et l'écran du PC fixes ; animer uniquement un curseur ou de courts traits à l'intérieur de l'écran si souhaité. Un mouvement interne suffit à rendre l'icône vivante.
- **Continuité :** remplacer l'indicateur quand un événement réel change l'activité ; ne pas cumuler attente générique et animation d'outil sans raison. Aucun pourcentage ou résultat n'est déduit de l'animation.
- **Accessibilité :** l'immobilité sous mouvement réduit reste à prévoir côté Hermes ; aucun `prefers-reduced-motion` n'a été trouvé dans le fichier Sparky examiné. Ne pas importer cette lacune avec le style.

Les deux spines restent les contrats. Cette recherche n'ajoute ni fonction serveur ni bibliothèque d'interface au projet.
