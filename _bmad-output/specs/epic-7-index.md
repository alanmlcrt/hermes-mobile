# Epic 7 — Specs des stories

État au 30 octobre 2026 : les six stories ont un document de spécification. La rédaction est réalisée ; aucune story n’est déclarée implémentée, approuvée ou prête pour développement. Le périmètre post-MVP provient de l’extrait provisoire `../../EPIC-7-REFERENCE.md`, sans modification du plan intégré à master.

| Story | Spécification | État / prérequis |
|---|---|---|
| 7.1 Vérifier les capacités | [Spec Build](../implementation-artifacts/spec-7-1-verifier-rangement-recherche.md) | Draft ; approbation puis essais réels dédiés requis |
| 7.2 Renommer | [SPEC.md](spec-7-2-renommer-conversation/SPEC.md) | Draft ; méthode de titre vérifiée, historique intégré |
| 7.3 Épingler et non lu | [SPEC.md](spec-7-3-epingler-marquer-non-lu/SPEC.md) | Draft ; identités de fins de tour, stockage et listes fiables |
| 7.4 Masquer et retrouver | [SPEC.md](spec-7-4-masquer-retrouver-conversations/SPEC.md) | Draft ; méthode réversible et liste des masquées vérifiées |
| 7.5 Supprimer | [SPEC.md](spec-7-5-supprimer-conversation/SPEC.md) | Draft ; suppression, gardes d’exécution/envoi, nettoyage et notifications |
| 7.6 Rechercher | [SPEC.md](spec-7-6-rechercher-conversation/SPEC.md) | Draft ; cache, portée locale/distante, profils et réconciliation |

Chaque nouvelle spec adopte le contexte commun et possède un compagnon `implementation.md` contenant les tâches, critères Étant donné/Quand/Alors, choix proposés et vérifications. Les chemins techniques sont proposés : la branche actuelle contient un squelette, pas encore les couches attendues de l’epic 6. Aucun numéro de migration ni contrat serveur n’est inventé.

Ordre conseillé : qualifier 7.1 ; intégrer la base epic 6 ; réconcilier les chemins et faire approuver chaque spec avec `bmad-build`. 7.2 et 7.3 peuvent ensuite avancer indépendamment si leurs prérequis sont réunis ; 7.4 prépare la gestion de section, 7.5 réutilise les propriétaires du nettoyage, 7.6 intègre les effets des mutations. Les essais réels utilisent des données dédiées ; un worktree ne sépare pas le serveur ou le téléphone.

Les nouveaux dossiers suivent le format `bmad-spec` (noyau, compagnon, journal canonique). La spec 7.1 conserve son format `bmad-build` et reste inchangée. Aucun `stories.yaml` ni sprint-status n’est généré : le plan partagé n’est pas encore intégré et les points de validation par story n’ont pas été convenus.
