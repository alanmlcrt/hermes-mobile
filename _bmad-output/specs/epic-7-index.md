# Epic 7 — Specs des stories

État au 31 octobre 2026 : 7.2 à 7.6 sont implémentées **en préparation seulement** (`story_validated: false`) ; 7.3 à 7.6 l’ont été en mode rapide, hors workflow bmad, à la demande d’Alanc. 7.1 n’a pas été jouée : aucune méthode Hermes de l’epic n’est qualifiée sur installation. Procédure de test : [`../implementation-artifacts/epic-7-tests-manuels.md`](../implementation-artifacts/epic-7-tests-manuels.md). Le périmètre post-MVP provient de l’extrait provisoire `../../EPIC-7-REFERENCE.md`, sans modification du plan intégré à master.

| Story | Spécification | État / prérequis |
|---|---|---|
| 7.1 Vérifier les capacités | [Spec Build](../implementation-artifacts/spec-7-1-verifier-rangement-recherche.md) | Sonde livrée ; **essais réels non joués** (accès et profil dédié requis) |
| 7.2 Renommer | [Spec Build](../implementation-artifacts/spec-7-2-renommer-conversation.md) | Implémentée (73349a3), préparation seulement : `session.title` non qualifiée |
| 7.3 Épingler et non lu | [SPEC.md](spec-7-3-epingler-marquer-non-lu/SPEC.md) | Implémentée (bb23229), local au téléphone ; purge AC-7/8 non faite |
| 7.4 Masquer et retrouver | [SPEC.md](spec-7-4-masquer-retrouver-conversations/SPEC.md) | Implémentée (3f3e694), préparation seulement : `session.set_hidden` non qualifiée |
| 7.5 Supprimer | [SPEC.md](spec-7-5-supprimer-conversation/SPEC.md) | Implémentée (3f3e694), préparation seulement : `session.delete` non qualifiée ; « à vérifier » sans preuve automatique |
| 7.6 Rechercher | [SPEC.md](spec-7-6-rechercher-conversation/SPEC.md) | Implémentée (3f3e694), locale uniquement ; recherche serveur non activée |

Chaque nouvelle spec adopte le contexte commun et possède un compagnon `implementation.md` contenant les tâches, critères Étant donné/Quand/Alors, choix proposés et vérifications. Les chemins techniques sont proposés : la branche actuelle contient un squelette, pas encore les couches attendues de l’epic 6. Aucun numéro de migration ni contrat serveur n’est inventé.

Ordre conseillé : qualifier 7.1 ; intégrer la base epic 6 ; réconcilier les chemins et faire approuver chaque spec avec `bmad-build`. 7.2 et 7.3 peuvent ensuite avancer indépendamment si leurs prérequis sont réunis ; 7.4 prépare la gestion de section, 7.5 réutilise les propriétaires du nettoyage, 7.6 intègre les effets des mutations. Les essais réels utilisent des données dédiées ; un worktree ne sépare pas le serveur ou le téléphone.

Les nouveaux dossiers suivent le format `bmad-spec` (noyau, compagnon, journal canonique). La spec 7.1 conserve son format `bmad-build` et reste inchangée. Aucun `stories.yaml` ni sprint-status n’est généré : le plan partagé n’est pas encore intégré et les points de validation par story n’ont pas été convenus.
