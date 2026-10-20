# Réconciliation UX → architecture

Verdict : **ajustements ciblés requis**. La séparation permettant une refonte et l'autorité des événements réels sont bien reprises. Deux contraintes confirmées sont trop condensées pour constituer seules un contrat fiable pour les agents de développement.

## Éléments correctement repris

- `ui-evolution-requirements.md`, « État indépendant du rendu », « Illustrations interchangeables » et critères 2–3 : AD-2/4/5/10 séparent état, protocole et présentation ; les nouveaux rendus ne soumettent pas de travail et les animations ne prouvent pas une fin. Le scénario de vérification final couvre explicitement la refonte sans perte du brouillon ni nouvelle soumission.
- `ui-evolution-requirements.md`, « Styles centralisés », « Thème séparé », « Composants réutilisables », « Contenu indépendant » et « Référence de comparaison » : AD-10 porte source sémantique commune, thème, composants à interfaces explicites, catalogue, libellés séparés et galerie de fixtures. Les valeurs de tokens restent correctement différées.
- `EXPERIENCE.md`, « Interaction Primitives » : AD-4 interdit l'invention de raisonnement ; AD-10 et la convention Activité s'appuient sur un type structuré, avec cas inconnu, sans emoji ni minuterie. Les contrôles de démonstration restent hors produit. Les 17 illustrations ne deviennent pas 17 capacités serveur.
- `DESIGN.md`, « Colors » : AD-10 respecte clair/sombre système et palette dynamique Android. Le secours est centralisé et reste explicitement à décider dans G4/Différé ; aucune palette ou dimension native fictive n'est imposée.

## F1 — Préciser la direction compacte déjà acceptée

**Preuve source :** `DESIGN.md`, « Shapes », dernier ajustement prioritaire : petits indicateurs près du libellé, trois points **tournants sans bulle**, châssis d'ordinateur fixe. `EXPERIENCE.md`, « Interaction Primitives », ajustement confirmé : points immobiles sous réduction des mouvements, préparation générique sans détails inventés et Arrêter accessible quand l'indicateur est réduit.

**Écart :** AD-10 conserve trois points et ordinateur fixe, mais omet taille visuellement compacte, proximité du texte et rotation sans bulle. « Préserver mouvement réduit [...] et Arrêter » ne fixe pas explicitement le cas réduit. Deux agents pourraient reconstruire un grand indicateur ou des points rebondissants malgré le choix confirmé.

**Correction minimale :** préciser dans AD-10 la présentation compacte près du libellé, trois points tournants sans bulle et immobiles sous mouvement réduit, et Arrêter accessible même indicateur réduit. Ne pas convertir les dimensions de maquette en tokens natifs ; conserver DESIGN/EXPERIENCE comme références visuelles.

## F2 — Rendre explicite le socle accessible conservé pendant une refonte

**Preuve source :** `ui-evolution-requirements.md`, « Accessibilité conservée » : texte agrandi, lecteur d'écran, **cibles tactiles**, mouvement réduit et deux thèmes. `EXPERIENCE.md`, « Accessibility Floor » : libellés accessibles des icônes, état autrement que par la couleur ; ordre de lecture, annonces et focus encore ouverts. `DESIGN.md`, « Colors » et « Do's and Don'ts » : contrastes à vérifier et information d'état non exclusivement colorée.

**Écart :** AD-10 reprend texte agrandi/lecteur/mouvement réduit, mais pas les cibles tactiles, les noms accessibles des actions ni l'état non exclusivement coloré. La galerie accessible reste sans mention explicite des variantes clair/sombre. Ces contraintes peuvent disparaître dans une refonte alors qu'elles sont confirmées.

**Correction minimale :** compléter AD-10 ou les conventions communes avec ces obligations et la comparaison clair/sombre, texte agrandi, mouvement réduit. Mentionner la vérification du contraste des palettes rendues avant acceptation des écrans ; ne pas inventer de seuil, de taille de cible ou de token. Le focus et les annonces peuvent rester différés avant les écrans concernés.

## Limites correctement laissées ouvertes

La maquette acceptée ne valide ni transport réel ni FR-13/14 : AD-7 et G1/G4 respectent cette limite. Navigation, composition détaillée, secours de palette et tokens restent ouverts, conformément aux sources. Leur absence de décision finale n'est pas un écart de réconciliation à ce stade.
