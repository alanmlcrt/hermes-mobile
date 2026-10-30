# Réconciliation — référence Grok Bot

Référence utilisateur : [ngocdevv/grok-bot-emoji](https://github.com/ngocdevv/grok-bot-emoji). Lecture du code au commit épinglé `c4b9859d5fda157fce28ee729dbeaca1bce1668c`, le 22 octobre 2026 :

- [grok-orb-scene.tsx](https://github.com/ngocdevv/grok-bot-emoji/blob/c4b9859d5fda157fce28ee729dbeaca1bce1668c/src/components/grok-orb-scene.tsx)
- [grok-orb-expression-picker.tsx](https://github.com/ngocdevv/grok-bot-emoji/blob/c4b9859d5fda157fce28ee729dbeaca1bce1668c/src/components/grok-orb-expression-picker.tsx)

| Observation dans ces composants | Réemploi conceptuel et limite |
| --- | --- |
| Dessin en formes et chemins ; morphing des yeux, séquences de poses, maintien puis interpolation, cadences variées | Référence de simplicité et de continuité. Les oreilles du lapin et ses yeux minuscules requièrent leur propre vocabulaire ; reprendre les déformations exactes du visage Grok n’est pas décidé. |
| Petites translations et rotation du corps, micro-déplacements des yeux | Inspiration pour une présence calme. Amplitudes et timings du lapin restent proposés ; les constantes Grok ne sont pas des exigences Hermes. |
| Particules orbitales et traînées, blanc sur fond sombre | Observés mais non demandés ; aucune obligation de les transporter dans l’identité pastel du lapin. Leur exclusion du premier cadrage est une réduction de portée, pas un refus utilisateur. |
| `expression`, `paused`, `useReducedMotion()` ; le temps d’animation devient statique quand mouvement réduit ou pause | Référence utile pour un état stable en réduction du mouvement. Hermes doit également définir le retour accessible au toucher ; la référence seule ne résout pas cette interaction. |
| Sélecteur d’expressions en grille avec boutons radio ; changement d’expression explicite | Démonstrateur d’expressions. Aucun sélecteur d’humeur n’est demandé pour Hermes. |
| Pas de liaison à un flux de texte dans les deux composants examinés | Ne pas attribuer à cette référence un comportement pendant la génération. Cette lecture ne constitue pas un audit exhaustif du dépôt entier. |
| Scène avec `pointerEvents: 'none'` ; interactions portées par le sélecteur | La réaction chatouilleuse vient de la demande utilisateur ; elle n’est pas attestée dans la scène examinée. |

**Statut.** Le même compagnon et les mêmes animations pour tous les profils sont validés par l’utilisateur. La séquence concentration → regard vers le texte → retour vers l’utilisateur reste une proposition Hermes, pas une décision ni une observation du dépôt. Aucune reprise de code n’est effectuée à cette étape.
