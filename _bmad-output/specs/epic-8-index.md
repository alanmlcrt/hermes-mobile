# Epic 8 — Faire travailler mes agents en salon

Livraison du 2026-10-31 : préparation contre le contrat documentaire, sans sonde
authentifiée ni validation de l'installation. « done » indique la fin de cette
préparation autorisée ; G5 et les critères nécessitant Hermes réel restent ouverts.

| story | status | delivery | story_validated |
| --- | --- | --- | --- |
| 8.1 | done | preparation-only | false |
| 8.2 | done | preparation-only | false |
| 8.3 | done | preparation-only | false |
| 8.4 | done | preparation-only | false |
| 8.5 | done | preparation-only | false |
| 8.6 | done | preparation-only | false |
| 8.7 | done | preparation-only | false |

Contrat : [contracts/epic-8](../../contracts/epic-8/README.md).
Essais Alan : [huit points téléphone](../../contracts/epic-8/essais-telephone.md).
Les stories 8.8 et 8.9 figurant dans `epics.md` ne font pas partie de cette livraison.

Vérification locale : `flutter analyze` sans alerte ; `flutter test` : 722 réussis,
17 ignorés. Une suite complète verte avant chaque commit de story. Les tests de
salon utilisent une socket simulée et SQLite ; ils ne prouvent pas Hermes réel.
Le contrat reste `documentary`, toutes les stories restent non validées jusqu'au
retour d'Alan. Fusion fast-forward dans master et validation réelle à faire ensuite.
