# Lecture de la première planche

Génération par l'outil intégré imagegen, à partir de la photo importée. La planche `../mockups/planche-lapin.png` est une **proposition**, pas un asset de production.

- Identité conservée : tête allongée beige-taupe, petits yeux, nez sombre, bouche à deux courbes, oreille gauche de l'image verticale et droite inclinée.
- Face au repos et chatouilles : la différence de pose est lisible ; les traits de vibration servent uniquement à la planche.
- Regard de côté : différence trop faible avec la face. À accentuer par translation coordonnée des yeux et du museau, sans agrandir les yeux. Ne pas considérer cette pose comme validée.
- Fond pastel : dégradé doux présent ; le voile de verre doit être mieux distingué dans une prochaine itération. Exemple plus explicite dans `../mockups/contextes.html`.
- Les étiquettes 48/64 px dans l'image générée ne prouvent pas les dimensions réelles. Le contrôle SVG dans `contextes.html` expose des tailles déterministes.
- Dessin légèrement modelé dans le bitmap ; la cible documentaire reste un aplat simplifié. Le SVG de contexte explore l'aplat, sans être une variante approuvée.

Les deux fichiers sont des supports de discussion ; aucun choix de cette planche ne devient automatiquement une décision utilisateur.

Correction ultérieure validée par Alanc : aucun brodage, fil ni couture dans le compagnon. Conserver la forme de bouche par un trait lisse. Les dessins de cette livraison utilisent des tracés continus ; la description historique du matériau de la photo n'est pas une consigne de rendu.

Maquette HTML rendue et inspectée dans Chromium via agent-browser ; capture mobile à 390 × 844 dans `contextes-mobile.png`, capture large dans `contextes-desktop.png`. Après correction du texte de palette en thème sombre et des marges de figures, absence de débordement horizontal confirmée à 390 px. Vérification de présentation statique seulement, pas test d'interactions ni essai Flutter/appareil.
