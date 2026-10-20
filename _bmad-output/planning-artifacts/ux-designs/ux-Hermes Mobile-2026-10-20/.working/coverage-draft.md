# Couverture du premier brouillon — 2026-10-20

Contrôle mécanique Pass 1 de `references/validate.md`, sans dispatch de reviewers. **Brouillons utiles pour poursuivre la conception ; finalisation non acquise.** Sources : `.memlog.md`, tous les fichiers `.working/`, PRD/addendum extraits, cinq exemples configurés, spécification DESIGN.md. Aucun visuel importé ou produit.

| Axe | Couverture et lacunes |
| --- | --- |
| Parcours | EXPERIENCE.md Key Flows contient Alanc et les deux étapes réellement racontées. La suite est explicitement dérivée du PRD. Climax, parcours de connexion, historique, fichiers, arrêt et retour par notification manquent ; couverture non fermée. FR-13/FR-14 ne sont pas engagés. |
| Tokens | `colors`, `typography`, `rounded`, `spacing`, `components` sont volontairement vides. Aucun faux hex ni référence non résolue. Métadonnées `theme` séparées pour clair/sombre système et rôles dynamiques Android. **Bloquant pour un contrat final :** secours hex clair/sombre, usages et contrastes non résolus ; typographie, dimensions et composition non choisies. |
| Composants | Les dix regroupements logiques ont les mêmes noms dans les deux tableaux. Règles source capturées ; anatomie, variantes et apparence insuffisantes pour implémenter. |
| États | Chaque surface logique possède une entrée State Patterns. Chargements, vides, focus, permissions et reprise restent partiellement ouverts ; aucune file d'attente offline inventée. États proposés distingués des exigences. |
| Visuels | Aucun fichier dans imports/, mockups/ ou wireframes/ ; aucun lien orphelin. **Toutes les surfaces sont sans maquette**, choix de couverture non confirmé par Alanc. Les sources de travail sont liées comme recherche, pas comme référence de composition. |

Structure : ordre canonique DESIGN.md et huit sections obligatoires EXPERIENCE.md présents ; Inspiration et Responsive ajoutées car déclenchées. Sources relatives résolubles ; exigences héritées par référence. Pas de choix de stack, bibliothèque UI complète, navigation, couleur fixe ou geste ajouté.

Les brouillons ne doivent pas être présentés comme finalisés. Les clarifications peuvent rester légères : choisir une composition concrète puis combler les lacunes qui conditionnent cette composition, sans redéfinir Hermes.
