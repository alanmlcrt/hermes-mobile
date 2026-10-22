---
name: Hermes Mobile — expérience du compagnon lapin
status: final
approval-status: planche-v5-validee-animations-a-concevoir
approved-reference: mockups/planche-lapin-v5-proportions.png
updated: 2026-10-22
language: fr
scope: conception uniquement
sources:
  - .memlog.md
  - ../../../brainstorming/brainstorm-compagnon-lapin-hermes-2026-10-22/.memlog.md
  - ../ux-Hermes Mobile-2026-10-20/EXPERIENCE.md
  - ../ux-Hermes Mobile-2026-10-20/DESIGN.md
  - imports/lapin-reference.png
  - https://github.com/ngocdevv/grok-bot-emoji/tree/c4b9859d5fda157fce28ee729dbeaca1bce1668c
---

# Hermes Mobile — Expérience du compagnon

## Foundation

**Validation Alanc : la [planche v5](mockups/planche-lapin-v5-proportions.png) est la première référence visuelle approuvée.** Noir/blanc, proportions des yeux, bouche lisse, oreilles plus courtes sans pli et leur asymétrie sont retenus. Cette approbation clôt le choix du dessin présenté ; les mentions historiques d'essais précédents ne le rouvrent pas. Les animations détaillées, la piste de génération et son articulation avec les trois points restent à concevoir ou arbitrer. Aucune implémentation Flutter n'est réalisée par cette validation.

La [planche v5](mockups/planche-lapin-v5-proportions.png) corrige les yeux jugés trop gros dans v4 ; elle est le support visuel courant, sans modification des comportements. Bouche lisse et oreilles sans pli sont conservées.

**Mise à jour visuelle :** la [planche v4](mockups/planche-lapin-v4-yeux-oreilles.png) explore la demande d'Alanc : yeux et bouche un peu plus grands et oreilles sans pli. Le blanc/noir et les oreilles plus courtes sont conservés. Dans toutes les poses, y compris les chatouilles, l'oreille remue sans pointe repliée ; l'asymétrie vient de son inclinaison. Aucun nouveau comportement n'est introduit.

Application Flutter, Android d'abord et iPhone anticipé. L'interface actuelle repose sur ThemeData/ColorScheme et des composants internes ; elle suit le thème système. Ce complément traite seulement du compagnon, en héritant des [parcours généraux](../ux-Hermes%20Mobile-2026-10-20/EXPERIENCE.md). [DESIGN.md](DESIGN.md) porte l'identité visuelle et les tokens ; aucun code Flutter n'est produit ici.

**Validé par Alanc :** même compagnon et mêmes animations sur tous les profils, nom par profil (Otc pour Alanc), fond personnalisable pastel dépoli à dégradé fixe ; présence en haut du profil et à côté du texte en génération ; repos tranquille avec regards latéraux ; toucher provoquant oreilles remuantes et tentative de retournement.

**Correction validée :** aucun brodage, fil, point de couture ou texture brodée ; la forme de bouche reconnaissable est rendue par un trait graphique lisse et continu, y compris dans les poses animées.

**Proposé :** orchestration des mouvements, valeurs numériques, sous-vue de personnalisation, réactions détaillées et liaison aux événements de génération. Les parcours ci-dessous sont des scénarios inférés pour vérifier la conception ; ils n'ont pas été racontés ou approuvés par Alanc.

Le compagnon accompagne la lecture ; les statuts distants restent exprimés par `work-status`, hérité de `WorkStateLabel`. Aucun mouvement n'affirme que le modèle comprend, réussit ou termine. Le dépôt de référence n'établit aucune liaison à la génération de texte.

## Information Architecture

| Surface | Accès / besoin | Couverture visuelle |
| --- | --- | --- |
| Haut du profil | Dans la surface profil existante ; voir le compagnon et son nom, accéder au fond personnalisable. Placement validé, commande d'édition proposée. | [Contexte profil](mockups/contextes.html). |
| Marge de la réponse | Dans la conversation active, sur le côté du texte en génération. Aucun nouveau niveau de navigation. | [Contexte conversation](mockups/contextes.html). |
| Personnalisation du fond | Sous-vue proposée depuis le profil ; comparer, appliquer ou annuler un fond pour ce profil. Pas d'administration des capacités Hermes. | [Étude de personnalisation](mockups/contextes.html), avec une seule palette d'exemple. |

La [planche des poses](mockups/planche-lapin.png) illustre les états visuels ; la [photo](imports/lapin-reference.png) reste la référence de ressemblance. La présence du compagnon dans l'historique ou hors génération en conversation n'est pas décidée.

Les trois surfaces ont une référence de composition ; les maquettes restent statiques et ne démontrent ni reconnaissance des gestes, ni mouvement réduit, ni conservation du fond. Le regard latéral et le verre de la planche doivent être améliorés avant validation visuelle ; les tailles CSS de la maquette ne remplacent pas un essai sur téléphone.

## Voice and Tone

Microcopies proposées, courtes et factuelles ; la voix visuelle est définie dans DESIGN.md. Pas de parole spontanée, récompense, reproche ou sollicitation de toucher.

| Usage | Formulation proposée |
| --- | --- |
| Action accessible | « Chatouiller Otc » ; substituer le nom réel du compagnon. |
| Édition du fond | « Arrière-plan », « Appliquer », « Annuler ». |
| Échec de conservation | « L'arrière-plan n'a pas été enregistré. Réessayer. » |
| Nom indisponible | « Compagnon » provisoire ; ne pas attribuer Otc à tous les profils. |

Les libellés d'envoi, travail, réussite, erreur, arrêt et état inconnu restent ceux de l'application. Ne pas remplacer « État inconnu » par une émotion ou « Terminé » par un sourire.

## Component Patterns

Les composants portent exactement les mêmes noms que dans DESIGN.md.Components.

| Composant | Règles comportementales |
| --- | --- |
| `companion` | Repos autonome discret ; toucher volontaire → une réaction aux chatouilles ; aucune action réseau, aucun effet sur saisie, sélection du texte ou génération. Suspendre hors écran. |
| `companion-backdrop` | Fixe pendant toutes les poses ; choix lié au profil actif. Valeur absente → fond de secours proposé, sans toucher à l'identité du lapin. |
| `companion-name` | Résoudre le nom du bot du profil actif ; ne pas confondre avec `Profile.label`, seul champ de libellé actuellement observé. Édition du nom hors périmètre. |
| `work-status` | Afficher l'état réellement connu ; annonces accessibles et commandes de travail héritées. Indépendant du cycle d'animation. |
| `backdrop-editor` | Proposition : prévisualisation locale, Appliquer conserve, Annuler restaure. Le stockage local/serveur et la synchronisation ne sont pas décidés. |

Les détails d'activités et la commande d'arrêt restent accessibles. **Arbitrage ouvert :** les trois points tournants de préparation générique sont déjà validés dans le dossier du 20 octobre ; remplacement ou coexistence avec le lapin à décider avant implémentation.

## State Patterns

### Présence et transitions proposées

Le repos et la nature des chatouilles sont validés ; les cadences suivantes sont des hypothèses de maquette, pas des paramètres finaux.

| État | Déclenchement / sortie | Expression proposée |
| --- | --- | --- |
| Repos de face | Entrée visible ou fin de réaction. | Pose stable ; pauses longues entre petits regards. |
| Regard latéral | Pause de repos écoulée ; retour à face. | Regard droite ou gauche, léger accompagnement de tête. Exemple : pauses 4–8 s, déplacement 300 ms, maintien 700 ms. |
| Chatouilles | Toucher confirmé dans la cible. | Frémissement d'oreilles, tentative de tourner la tête en trois-quarts, retour souple. Exemple : réaction totale 900–1 200 ms. |
| Retour | Fin du toucher/réaction ; état actuel relu. | Reprendre une pose neutre ou la pose de génération encore pertinente ; ne pas rejouer un événement passé. |
| Suspendu | Application en arrière-plan, surface hors écran ou masquée. | Aucun cycle ni minuterie active ; reprise depuis l'état courant, sans rattrapage. |
| Mouvement réduit | Préférence système active, y compris changement en cours de réaction. | Repos totalement fixe ; toucher → pose immobile de chatouilles, puis face. Aucune rotation, oscillation, transition animée ou clignement. |

Proposition de priorité : mouvement réduit / suspension d'abord, toucher volontaire ensuite, expression liée à l'état de travail ensuite, repos enfin. Une réaction déjà engagée n'est pas empilée : ignorer les touches supplémentaires jusqu'au retour stable. Si le travail change pendant les chatouilles, actualiser immédiatement son libellé puis reprendre la bonne pose après la réaction ; la fin réelle ne doit jamais attendre une animation.

### Génération : piste explicitement non validée

| Événement réellement disponible | Proposition visuelle | Garde-fou |
| --- | --- | --- |
| Envoi de la demande | Rester neutre ou transition vers concentration si démarrage confirmé. | Envoi ne signifie pas génération commencée. |
| Travail démarré (`running`) | Oreilles légèrement relevées, air concentré ; transition calme de l'ordre de 300 ms proposée. | Ne pas assimiler `running` à la réception du premier caractère. |
| Texte reçu progressivement | Regard vers le bloc de réponse, mouvements discrets moins fréquents qu'au profil. | Pas de battement à chaque token ; ne pas inférer l'état depuis la cadence du texte. |
| Fin réussie confirmée (`succeeded`) | Regard vers le lecteur puis repos, sans rebond obligatoire ; maintien bref proposé. | Absence de nouveau texte ou premier token ≠ fin confirmée. |
| Erreur, arrêté, inconnu | Retour neutre et libellé exact ; aucune expression de victoire ou tristesse imposée. | Silence réseau ≠ réussite, arrêt ou mesure d'avancement. |

Si les événements nécessaires ne sont pas disponibles, conserver le repos ; ne pas simuler une progression. Retour vers l'utilisateur uniquement après la fin appropriée confirmée, sans lui faire attendre la lecture de la réponse.

### États par surface

| Surface / cas | Traitement proposé |
| --- | --- |
| Profil chargé | Nom et fond du profil courant ; même anatomie. |
| Profil en chargement ou nom absent | Slot stable, compagnon neutre ; pas de nom d'un précédent profil. |
| Aucun profil accessible | Hériter de l'état vide du sélecteur ; ne pas créer de compagnon autonome. |
| Fond absent ou invalide | Fond de secours fixe ; aucune disparition du nom ou du visage. |
| Personnalisation ouverte / focus | Aperçu local ; focus visible et ordre des commandes stable. |
| Annulation de personnalisation | Restaurer le fond précédent sans écriture et sans changer le profil. |
| Échec d'enregistrement / hors ligne | Garder l'aperçu éditable et proposer Réessayer ; ne pas affirmer une synchronisation non acquise. Persistance hors ligne à décider. |
| Conversation vide ou historique | Aucun cycle de génération fictif ; présence du lapin hors réponse active encore ouverte. |
| Réponse en cours / fin / échec / arrêté / inconnu | `work-status` reste l'autorité ; appliquer uniquement la piste visuelle si validée et si l'événement existe. |
| Asset indisponible | Réserver le slot sans bloquer le texte, nom/statut conservés ; substitut statique à prévoir lors de la production. |

Aucune permission système nouvelle n'est nécessaire pour toucher le compagnon ou choisir une palette prédéfinie. Importer une image de fond n'est pas demandé et n'entre pas dans cette conception.

## Interaction Primitives

- Proposition : déclencher au relâchement après un toucher reconnu comme activation ; le scroll ou l'annulation du pointeur annule la réaction. Ne pas capturer un glissement vertical du profil ou de la conversation.
- Pas de geste caché obligatoire, d'appui long, de double toucher ou de rotation à manipuler. Un appui maintenu ne prolonge pas indéfiniment les chatouilles.
- La zone interactive mesure au moins `{components.companion.touch-minimum}` ; elle ne chevauche ni réponse sélectionnable ni arrêt du travail. Activation lecteur d'écran/clavier équivalente au toucher.
- Début et fin d'animation gardent la même enveloppe, sans saut du texte ni scroll automatique provoqué par le lapin.
- Proposition de pause : si une boucle autonome est retenue, offrir une commande accessible « Mettre les animations en pause » dans le profil, conservée pour la session ; emplacement et persistance à valider. Le mouvement réduit système reste prioritaire.
- Personnalisation proposée : Retour/Annuler abandonne les changements non appliqués ; Appliquer est distinct du choix de palette. Aucun enregistrement serveur ou modèle de données n'est présupposé.

## Accessibility Floor

Ces exigences de conception sont proposées comme minimum de production ; elles ne constituent pas des tests déjà exécutés sur Flutter.

- Sous mouvement réduit, le lapin reste entièrement statique au repos ; aucun clignement « résiduel ». Le changement de pose au toucher est immédiat et discret ; le fond reste fixe dans tous les modes.
- Le compagnon interactif est annoncé comme bouton, « Chatouiller [nom] », avec une courte indication facultative. Ne pas annoncer chaque regard ou mouvement d'oreille ; jamais de boucle d'annonces.
- `work-status` transmet seul l'information de travail utile ; éviter les annonces doublées entre illustration et libellé. L'ordre de lecture reste nom/contenu/statut/actions selon le contexte existant.
- Cible minimale `{components.companion.touch-minimum}` ; focus distinct sur surface stable, vérifié visuellement selon DESIGN.md. Clavier et actions sémantiques accessibles sans toucher précis aux oreilles.
- À 200 % de texte, laisser le nom se développer et déplacer le slot si nécessaire ; aucune troncature du statut ou superposition au bouton d'arrêt. Le lapin ne monopolise pas la largeur de lecture.
- L'absence d'animation, le fond de secours, le mode sombre et l'indisponibilité de l'asset ne retirent aucune fonction de conversation.

## Inspiration & Anti-patterns

La [variante v3 noir et blanc](mockups/planche-lapin-v3-noir-blanc.png), demandée par Alanc avec des oreilles légèrement plus petites, explore un compagnon blanc à traits noirs. Cette variation d'apparence ne change ni les gestes ni les états ; le fond pastel fixe reste illustré. Le choix final du dessin reste ouvert.

La [planche affinée v2](mockups/planche-lapin-v2.png) est le support visuel courant : regard de côté mieux différencié, chatouilles et exemple de panneau dépoli fixe. Elle ne change aucun comportement validé et ne démontre pas les transitions animées.

La [référence Grok Bot au commit étudié](https://github.com/ngocdevv/grok-bot-emoji/tree/c4b9859d5fda157fce28ee729dbeaca1bce1668c) inspire le dessin simplifié, les poses et leurs transitions. C'est un démonstrateur d'expressions, pas une preuve de comportement pendant une réponse. Ni particules, ni traînées, ni morphing de grands yeux ne sont validés pour ce lapin.

La ressemblance vient de la photo, pas d'un personnage Grok recouvert d'oreilles. Éviter les relances pour obtenir de l'attention, le mouvement synchronisé à chaque token et les émotions interprétées comme état technique.

## Responsive & Platform

Même compagnon aux deux emplacements ; amplitude plus contenue et pauses plus longues dans la conversation proposées. Le profil conserve la lecture complète de la silhouette ; la conversation utilise `{components.companion.compact-size}` avec test du minimum `{components.companion.compact-minimum}`. Sous ce seuil, déplacer le slot plutôt que réduire les yeux à des pixels confondus.

RTL : placer la marge selon le sens de lecture et orienter le regard vers le texte ; préserver l'asymétrie physique des oreilles. Petit écran, clavier ouvert ou grande police : passage du slot avant le texte proposé, à confirmer avec la maquette. Aucun écran desktop ou breakpoint tablette nouveau. App en arrière-plan et sous-vue masquée : même suspension sur Android et iOS.

## Key Flows

Scénarios de vérification **inférés**, et non récits utilisateur validés.

### Alanc — Retrouver Otc et le chatouiller

1. Alanc ouvre son profil ; Otc apparaît en haut, avec le nom distinct du libellé du profil.
2. Il observe un regard latéral calme, puis touche le compagnon.
3. **Climax proposé :** les oreilles remuent et la tête essaie de se détourner ; Alanc reconnaît son lapin sans changer d'écran.
4. La pose revient au repos sans déplacer les contenus.

Échec/alternative : un glissement pour lire le profil ne déclenche rien ; mouvement réduit → pose fixe immédiate ; asset absent → profil et nom utilisables.

### Alanc — Choisir le fond de ce profil

1. Alanc ouvre « Arrière-plan » depuis le haut du profil, accès proposé.
2. Il compare une palette pastel fixe derrière le même lapin.
3. **Climax proposé :** Appliquer conserve ce fond pour le profil courant ; le nom et l'anatomie restent identiques.
4. Un autre profil présente son propre nom et son fond, avec le même compagnon.

Échec : si l'enregistrement échoue, conserver l'édition et proposer Réessayer ; Annuler restaure. L'endroit de stockage et la disponibilité après redémarrage restent à trancher avant de garantir l'étape 3.

### Alanc — Lire une réponse avec une présence discrète

1. Alanc envoie une demande ; le statut décrit l'envoi réel.
2. Si la piste génération est retenue, le démarrage confirmé relève légèrement les oreilles ; le texte reçu attire le regard du lapin.
3. Alanc lit et peut toucher le compagnon sans modifier ni interrompre le travail.
4. **Climax proposé :** après réussite réellement confirmée, Otc regarde Alanc puis se repose ; la réponse et son statut restent immédiatement lisibles.

Échec : erreur, arrêt ou déconnexion → libellé exact et pose neutre, jamais de fausse fin. Revenir d'arrière-plan montre l'état courant sans rejouer les animations manquées. La présence des trois points doit être arbitrée avant réalisation de ce parcours.

## Arbitrages de conception restants

Valider visuellement la tête sans corps, la ressemblance, les couleurs et les échelles ; confirmer ou modifier la piste de génération ; décider du lien avec les trois points existants, du fond dans la marge conversation et de la personnalisation détaillée. Nom par profil et fond par profil nécessiteront un contrat de données distinct du modèle `Profile` actuel. Ces ouverts n'empêchent pas de discuter la première planche, mais empêchent de qualifier ce dossier de contrat Flutter final.
