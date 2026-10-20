# Vérification du catalogue animé

20 octobre 2026 — `../simple-conversation.html`, 17 illustrations.

- Sources amont : 27 outils/émojis vérifiés au commit référencé dans `../hermes-tool-activity-research.md`. Correspondances proposées et limites dans `../activity-catalogue.md`.
- Navigateur réel : chacune des 17 sélections produit un SVG animé, un libellé et un exemple de demande définis ; le sélecteur et la carte sélectionnée correspondent.
- Pause : animations de la conversation réellement en état `paused`.
- Démo automatique : premier passage de code à création de fichier observé après 4,8 secondes ; arrêt puis sélection manuelle vérifiés.
- Réduction des mouvements après rechargement : aucune animation, pause et démo automatique désactivées.
- À 390 px : pas de débordement horizontal ; 17 options accessibles dans le sélecteur. Le catalogue est défilant.
- Capture de l’ensemble du catalogue sombre inspectée ; capture claire de l’aperçu inspectée. Débordement des lignes du navigateur corrigé par un viewport SVG interne découpé.
- Maquette ouverte dans le navigateur par défaut ; aucune connexion à Hermes ni ressource externe.

Le classement réel d’événements et la disponibilité des capacités du Hermes personnel restent hors de cette maquette. Les commandes de démonstration ne représentent pas des tâches réelles.
