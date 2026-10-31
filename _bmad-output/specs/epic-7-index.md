# Epic 7 — Specs des stories

État au 31 octobre 2026 : **epic validée.** 7.2 à 7.6 sont implémentées et validées par les essais d’Alanc sur téléphone contre son Hermes installé (APK release 25/26) ; 7.3 à 7.6 ont été faites en mode rapide, hors workflow bmad. 7.1 est validée partiellement : sonde non jouée, mais les méthodes utilisées sont confirmées par ces essais. Limites restantes : `../implementation-artifacts/deferred-work.md`. Procédure de test : [`../implementation-artifacts/epic-7-tests-manuels.md`](../implementation-artifacts/epic-7-tests-manuels.md).

| Story | Spécification | État / prérequis |
|---|---|---|
| 7.1 Vérifier les capacités | [Spec Build](../implementation-artifacts/spec-7-1-verifier-rangement-recherche.md) | Validée partiellement : méthodes confirmées par les essais app ; sonde, archive et recherche serveur non vérifiées |
| 7.2 Renommer | [Spec Build](../implementation-artifacts/spec-7-2-renommer-conversation.md) | Validée (73349a3) |
| 7.3 Épingler et non lu | [SPEC.md](spec-7-3-epingler-marquer-non-lu/SPEC.md) | Validée (bb23229, 62abbb7 accueil) ; purge AC-7/8 reportée |
| 7.4 Masquer et retrouver | [SPEC.md](spec-7-4-masquer-retrouver-conversations/SPEC.md) | Validée (3f3e694) |
| 7.5 Supprimer | [SPEC.md](spec-7-5-supprimer-conversation/SPEC.md) | Validée (3f3e694) ; « à vérifier » sans preuve automatique reportée |
| 7.6 Rechercher | [SPEC.md](spec-7-6-rechercher-conversation/SPEC.md) | Validée (3f3e694), locale uniquement ; recherche serveur reportée |

Chaque nouvelle spec adopte le contexte commun et possède un compagnon `implementation.md` contenant les tâches, critères Étant donné/Quand/Alors, choix proposés et vérifications. Les chemins techniques sont proposés : la branche actuelle contient un squelette, pas encore les couches attendues de l’epic 6. Aucun numéro de migration ni contrat serveur n’est inventé.

Ordre conseillé : qualifier 7.1 ; intégrer la base epic 6 ; réconcilier les chemins et faire approuver chaque spec avec `bmad-build`. 7.2 et 7.3 peuvent ensuite avancer indépendamment si leurs prérequis sont réunis ; 7.4 prépare la gestion de section, 7.5 réutilise les propriétaires du nettoyage, 7.6 intègre les effets des mutations. Les essais réels utilisent des données dédiées ; un worktree ne sépare pas le serveur ou le téléphone.

Les nouveaux dossiers suivent le format `bmad-spec` (noyau, compagnon, journal canonique). La spec 7.1 conserve son format `bmad-build` et reste inchangée. Aucun `stories.yaml` ni sprint-status n’est généré : le plan partagé n’est pas encore intégré et les points de validation par story n’ont pas été convenus.
