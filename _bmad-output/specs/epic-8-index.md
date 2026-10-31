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

Vérification locale : `flutter analyze` sans alerte ; `flutter test` : 732 réussis,
17 ignorés. Une suite complète verte avant chaque commit de story. Les tests de
salon utilisent une socket simulée et SQLite ; ils ne prouvent pas Hermes réel.
Le contrat reste `documentary`, toutes les stories restent non validées jusqu'au
retour d'Alan. Fusion fast-forward dans master et validation réelle à faire ensuite.

Premier retour téléphone : le message invitant à activer Bot Mode persiste après
ajout du marqueur et redémarrage d'Hermes. Correctif release 30 : distinguer pilote
indisponible, éligibilité non annoncée et zéro profil éligible, sans inférer la
cause. Diagnostic de capacités visible dans l'app.

Retour d'Alan en release 30 : pilote oui, processus persistant oui, protocole 2,
liste des profils non fournie et 18 méthodes. Constat partiel consigné dans
`contracts/epic-8/observations-app.md`, sans validation des mutations.
Correctif release 31 : lecture des salons indépendante de la liste optionnelle ;
sélection vérifiée via les métadonnées `profiles.list` si cette liste manque.

Alan confirme le fonctionnement du parcours création/envoi sur la release 31,
puis demande une saisie compacte et des mentions nommées. Release 32 : champ
ancré en bas, aide à la demande, suggestions au curseur et noms de profils dans
les mentions ; compatibilité avec les handles des salons déjà créés. Captures
synthétiques et vérifications dans `implementation-artifacts/epic-8-ui`.
Les essais d'arrêt, d'absence prolongée et de notifications restent ouverts.
