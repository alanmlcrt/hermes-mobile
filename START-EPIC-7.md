# Démarrer l'epic 7

## Prompt à donner au nouvel agent Codex

Utilise `bmad-build` pour commencer l'epic 7, « Ranger et retrouver mes conversations », en ciblant d'abord la story 7.1 : vérifier les capacités de rangement et de recherche sur l'installation réelle. Lis ce brief et `EPIC-7-REFERENCE.md` avant de commencer. Communique en français. Lis et respecte `C:\Users\alanc\.codex\RTK.md` (préfixer les commandes shell avec `rtk`).

## Contexte et périmètre

- Ton dossier de travail est `C:\Users\alanc\orca\workspaces\Hermes Mobile\epic-7`, branche `alanmlcrt/epic-7`, créée depuis `origin/master` au commit `d9a7920fbf71213b354f3e00a086f6167e690cc6`.
- Un autre agent travaille sur l'epic 6 dans `C:\Users\alanc\orca\projects\Hermes Mobile`, branche `epic/6-interventions`. Tu n'es pas seul sur le projet : ne modifie pas ce dossier, ne change pas sa branche et ne touche pas à ses changements non commités. Adapte ton travail aux changements qui seront intégrés ultérieurement.
- La base de ce worktree ne contient pas encore l'ajout des epics post-MVP au plan. `EPIC-7-REFERENCE.md` est un extrait de travail copié du plan de l'autre checkout le 30 octobre 2026, susceptible d'évoluer. Ne prétends pas qu'il s'agit d'un plan déjà intégré à master. N'écrase pas le plan partagé avec cet extrait.
- Le plan place l'epic 7 après l'epic 6. Commence par l'investigation 7.1 et les travaux réellement indépendants. Identifie les dépendances avant toute implémentation qui suppose les changements de l'epic 6.

## Résultat attendu pour 7.1

Vérifier les méthodes réellement exposées par Hermes pour les titres, le masquage, l'archivage, la suppression et la recherche. Consigner paramètres, réponses, erreurs, capacités détectées, effets sur les listes et autres clients, et fixtures anonymisées dans les artefacts appropriés. Distinguer les résultats observés des hypothèses. Si l'installation réelle n'est pas accessible, préparer les essais et signaler précisément ce qui reste à vérifier ; ne pas valider la story sur des simulations.

Utiliser un profil et des conversations de test dédiés. Les worktrees ne séparent ni le serveur Hermes ni le téléphone/émulateur : ne pas supprimer ou masquer les conversations utilisées par l'autre agent, et ne pas interrompre ses essais. Utiliser des ports et données locales distincts si nécessaire.

## Intégration ultérieure

Conserver les changements sur cette branche, avec des artefacts propres à l'epic 7. L'epic 6 doit être intégré avant l'epic 7. Récupérer ensuite la base mise à jour, résoudre les conflits éventuels (adaptateur, repository, migrations, routes et documents communs), puis vérifier l'ensemble. Ne pas fusionner ou publier automatiquement pour commencer cette investigation.

## État de préparation

Ce worktree et ces deux documents ont été préparés sans lancer d'agent et sans installer de dépendances ni exécuter de tests.
