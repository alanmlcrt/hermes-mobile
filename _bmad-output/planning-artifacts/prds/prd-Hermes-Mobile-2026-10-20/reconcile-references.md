# Réconciliation — références Grok et dernières précisions d’Alanc

Date : 2026-10-20. Documents examinés : `prd.md`, `addendum.md`, `.memlog.md` dans ce dossier. Réconciliation des apports ; aucune demande de parité fonctionnelle avec Grok Bot.

## Sources

- Sources fournies : [overview Markdown](https://docs.x.ai/grok-bot/overview.md), [présentation Grok Bot](https://x.ai/bot).
- Le lecteur web refuse le type `text/markdown` du premier lien ; sa [version HTML officielle](https://docs.x.ai/grok-bot/overview), liée au même contenu, a été consultée le 2026-10-20. La présentation a également été consultée.
- Recherche Hermes déjà conservée dans `addendum.md`, rubrique « Hermes : capacités à relier au client ». Elle distingue documentation générale et capacités du serveur effectivement installé ; cette réconciliation ne prétend pas avoir testé l’instance.
- Apport direct d’Alanc : photos, captures, PDF et documents pour des usages ouverts ; possibilité d’arrêter l’agent ; usages de code, d’environnements et d’auto-amélioration déjà portés par Hermes ; application conçue comme moyen de communication avec une belle interface.

## Couverture et destination

| Apport | Destination et couverture | État |
| --- | --- | --- |
| Converser avec l’agent comme dans une messagerie | `prd.md`, « But et utilisateur », FR-4, « Expérience et qualité attendues » | Capturé ; positionnement central explicite. |
| Photos, captures, PDF, documents et usages libres | `prd.md`, FR-5 et FR-6 | Capturé ; les usages restent ouverts, sans promettre tous les formats. |
| Pouvoir arrêter l’agent | `prd.md`, FR-12 | Capturé comme besoin confirmé, avec distinction entre demande et confirmation serveur. |
| Examiner les contrôles possibles de Hermes | `addendum.md`, « Hermes : capacités à relier au client » ; `prd.md`, FR-12 à FR-14 | Capturé ; arrêt confirmé, questions/autorisations et récupération de résultats encore proposés. |
| Préparer des environnements, coder, améliorer les compétences | `prd.md`, « But et utilisateur », « Réussite proposée et limites » ; `addendum.md`, conclusion de la rubrique Hermes | Capturé comme usages de Hermes existant ; aucun moteur local ni IDE mobile ajouté. |
| Belle interface, conversation lisible et suivi | `prd.md`, « Expérience et qualité attendues », FR-7 et NFR-1 | Capturé qualitativement ; forme visuelle déférée à l’UX. |
| Grok : messages, travail persistant et demande d’intervention | `prd.md`, FR-8, FR-13 et références d’expérience ; `addendum.md`, « Grok Bot : inspiration pour le client » | Capturé comme inspiration, pas comme preuve de compatibilité Hermes. |
| Grok : configuration par conversation | `prd.md`, « Découverte des profils » ; `addendum.md`, cadrage des profils | Cohérent avec la préférence explicite d’Alanc pour le profil par défaut ; capacité réelle à vérifier. |
| Grok : cloud, bots en groupe, routines, apprentissage par démonstration et politique Auto Review | `prd.md`, limites ; `addendum.md`, réserve finale de la rubrique Grok | Mis de côté : aucune demande de reproduire ces fonctions dans l’app. La référence ne vaut pas extension du MVP. |

## Écarts restants et traitement proposé

1. **Le rendu « belle interface » reste volontairement non spécifié.** Le PRD préserve l’intention mais ni palette, disposition ni interactions visuelles précises ne sont validées. Destination : travail UX ; conserver cette attente qualitative, sans inventer un style attribué à Alanc.
2. **La chaîne de communication Hermes n’est pas vérifiée sur l’installation réelle.** Les documents cités ne démontrent pas qu’un transport unique expose profils, historique, fichiers, événements et contrôle. Déjà conservé dans le PRD et l’addendum ; à attribuer à l’architecture avant engagement d’implémentation. La demande utilisateur n’est pas omise.
3. **Les hypothèses FR-13 et FR-14 ne sont pas des décisions confirmées.** Le souhait « arrêter l’agent etc. » et la référence Grok justifient leur examen, sans valider automatiquement chaque fonction. Les garder identifiées comme propositions ou décisions de cadrage du mode rapide, avec provenance distincte du besoin confirmé.
4. **Les sources Grok diffèrent sur certains détails commerciaux et plateformes.** La page de présentation est plus étroite que l’overview sur les plateformes. Ces détails n’alimentent aucune exigence du PRD ; aucun arbitrage nécessaire et aucune nouvelle promesse Android dérivée de Grok.

## Conclusion

Aucun apport direct récent n’est perdu. Les comportements demandés sont dans le PRD ; les détails techniques et réserves documentaires sont dans l’addendum ; les fonctions commerciales et d’orchestration propres à Grok sont mises de côté. Les écarts résiduels concernent la conception UX, les propositions explicites et la vérification de l’intégration, pas une fonctionnalité oubliée.
