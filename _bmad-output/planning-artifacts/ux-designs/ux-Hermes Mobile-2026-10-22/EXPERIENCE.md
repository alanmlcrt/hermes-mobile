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

## Clarification du 23 octobre — Otc seul en conversation

Otc est le seul compagnon animé de la conversation, conformément à la précision d’Alanc. Les lignes d’action gardent leur texte, détails dépliables, focus et preuve de fin reçue, sans illustration décorative ni espace réservé à un dessin. Les poses, regards et chatouilles approuvés sont conservés, ainsi que la pause locale, le mouvement réduit, la suspension et l’unique région live du statut. Le scénario de conversation de la galerie suit ce rendu ; le catalogue développeur demeure une démonstration séparée. Cette décision prévaut sur les compléments historiques ci-dessous.

## Complément approuvé — illustrations d’activité 3.3

### Catalogue complété — story 3.4

Les 17 familles et le repli sont comparables dans la galerie avec leur variante immobile. Le bouton de pause commun reste une commande native et atteignable après agrandissement à 200 %. Le contrôleur de 3.3 immobilise chaque famille sous mouvement réduit, pause, fin reçue, hors viewport, `Offstage`, route couverte et arrière-plan ; il reprend au retour visible sans modifier le travail. Les dessins restent décoratifs auprès de leurs libellés et ne créent aucune région live supplémentaire.

La préparation à trois points n’est montrée que dans le catalogue fictif, sans ajout de ligne dans la conversation. Les événements réels conservent leur mapping `tool`/`unknown`, indépendamment du nom, des arguments ou d’un emoji. [Preuves et limites](../../../implementation-artifacts/story-3-4-verification/verification.md).

Le bouton « Mettre les animations en pause » de la conversation immobilise simultanément Otc et les illustrations d’activité (`ActivityIllustration`), tout comme le mouvement réduit système, la fin reçue (`completed: true`), le défilement hors du viewport, `Offstage` et le passage en arrière-plan. Remplacer une entrée dans `ActivityCatalog` ne modifie ni le décodage serveur (`EventMapping`), ni `ConversationRepository`, ni les contrats Otc.

## Complément approuvé — activités 3.1

Au premier delta/interim non vide après une série d’au moins deux activités, la série se replie en « N activités » et indique combien n’ont pas de fin confirmée. Le choix manuel reste local et stable lors des mises à jour ; aucune reconstruction ou commande de repli ne lance d’appel Hermes ni ne déplace le focus. La fin reçue d’une action ne vaut ni réussite ni fin du travail ; seul `WorkStateLabel` porte le statut du travail. Lignes et commande native restent lisibles à 200 %, avec cible de commande de 48 px, état accessible replié/déplié et sans mouvement nouveau. Les contrats de présence, pause, chatouilles, fonds, suspension et placement Otc demeurent ceux approuvés ci-dessous.

## Contrat courant — lot 4 approuvé

Alanc a retenu les quatre recommandations A (« fait tout ce que tu recommandes »). Ce contrat prévaut sur les pistes et arbitrages historiques de génération ci-dessous.

La soumission et l'acceptation gardent Otc neutre. Un démarrage confirmé lui donne une expression concentrée ; du texte réellement reçu attire son regard vers la réponse, maintenu sans battement par fragment. Toutes les fins ramènent le visage de face puis au repos ; aucune réaction ne distingue la réussite. `WorkStateLabel` annonce immédiatement le statut exact, même pendant une chatouille. Erreur, arrêt, perte de connexion et état inconnu ne produisent aucune réussite inventée.

Les chatouilles sont une réaction locale sans commande de génération. Après la réaction, Otc reprend la pose courante ; une fin survenue pendant celle-ci n'est jamais rejouée plus tard. Les regards autonomes sont supprimés pendant le travail. La pause locale à la page et le mouvement réduit suppriment tout mouvement autonome ; le toucher donne alors une pose fixe temporaire.

Hors écran, route masquée, surface inactive ou arrière-plan : annuler le cycle et la réaction en cours. Au retour, montrer seulement la pose de l'état courant, sans rattrapage. Le rejeu et le snapshot restaurent les données et la pose courante, sans animation des événements passés. Un historique terminé est neutre. Un nouveau tour garde les réservations des anciens tours sans dupliquer « Chatouiller Otc ».

Le carré de 64 px est présent dès l'acceptation et reste après le terminal. Il est latéral si la largeur utile atteint 360 px avec texte inférieur à 150 %, sinon avant le texte. L'ouverture du clavier ne change pas ce choix. Le fond reste la surface neutre du thème. Le lapin remplace l'intention des trois points ; les activités et le statut restent présents.

Le regard suit le contenu : vers la droite en placement latéral, vers le bas lorsque la réponse est dessous, sans miroir des oreilles. Le seuil de 150 % est évalué à la taille réelle du corps de réponse, même avec un agrandissement non linéaire. La pause reste dans le fil, près du dernier compagnon, accessible par défilement à 200 %. Les blocs longs d'un même tour gardent leur construction paresseuse et un retrait commun ; ils ne créent aucune interaction supplémentaire. Une activité reçue avant le démarrage appartient à la demande déjà acceptée. La reprise reconstruit le regard depuis le texte courant de l'historique, même sans partiel explicite.

## Contrat courant — lots 1 et 2

La v5 approuvée est prioritaire sur toutes les études historiques ci-dessous. `RabbitCompanion` reprend ce dessin, ses réactions et sa suspension ; la galerie conserve son aperçu. Le lot 2 place le compagnon avant les contenus existants de « Mes profils », à 180 pixels logiques, sur le dégradé fixe `RabbitTokens.backdrop`. Le nom apparaît en vrai texte sur une surface sémantique du thème, hors du pastel, avec retour à la ligne à 200 %, et une commande de pause accessible.

**Clarification utilisateur : Otc est le nom constant du compagnon pour chaque profil sélectionné.** Les profils Hermes gardent leurs propres libellés ; aucun profil n'est renommé ni identifié comme Alanc. Aucun champ serveur, correspondance de noms ou usage de `isDefault` n'est requis. Un nom de présentation absent ou blanc donne « Compagnon », visuellement et dans l'action accessible.

La sélection doit être présente dans le snapshot courant. Pendant un chargement, une sélection précédemment vérifiée sur la même connexion garde une enveloppe stable, sans ancien libellé de profil. Sans sélection vérifiable ou avec une liste vide, les états métier restent seuls. Changer de profil ou de serveur réinitialise la pose au repos. Hors viewport, route masquée, arrière-plan ou surface conservée avec `active: false`, les cycles sont suspendus ; le mouvement réduit est immédiat.

La personnalisation du fond, la génération et les trois points sont hors du lot 2. Les propositions historiques les concernant ne constituent pas le contrat de cette intégration. `contextes.html` est une étude ancienne archivée ; ses couleurs, son dessin et sa personnalisation ne priment pas sur v5 ni sur le présent contrat.


## Foundation

**Validation Alanc : la [planche v5](mockups/planche-lapin-v5-proportions.png) est la première référence visuelle approuvée.** Noir/blanc, proportions des yeux, bouche lisse, oreilles plus courtes sans pli et leur asymétrie sont retenus. Cette approbation clôt le choix du dessin présenté ; les mentions historiques d'essais précédents ne le rouvrent pas. Les animations détaillées, la piste de génération et son articulation avec les trois points restent à concevoir ou arbitrer. Aucune implémentation Flutter n'est réalisée par cette validation.

La [planche v5](mockups/planche-lapin-v5-proportions.png) corrige les yeux jugés trop gros dans v4 ; elle est le support visuel courant, sans modification des comportements. Bouche lisse et oreilles sans pli sont conservées.

**Mise à jour visuelle :** la [planche v4](mockups/planche-lapin-v4-yeux-oreilles.png) explore la demande d'Alanc : yeux et bouche un peu plus grands et oreilles sans pli. Le blanc/noir et les oreilles plus courtes sont conservés. Dans toutes les poses, y compris les chatouilles, l'oreille remue sans pointe repliée ; l'asymétrie vient de son inclinaison. Aucun nouveau comportement n'est introduit.

Application Flutter, Android d'abord et iPhone anticipé. L'interface actuelle repose sur ThemeData/ColorScheme et des composants internes ; elle suit le thème système. Ce complément traite seulement du compagnon, en héritant des [parcours généraux](../ux-Hermes%20Mobile-2026-10-20/EXPERIENCE.md). [DESIGN.md](DESIGN.md) porte l'identité visuelle et les tokens ; aucun code Flutter n'est produit ici.

**Validé par Alanc :** même compagnon et mêmes animations sur tous les profils, nom constant Otc indépendant des profils, fond pastel fixe pour le lot 2 ; présence en haut du profil et à côté du texte en génération ; repos tranquille avec regards latéraux ; toucher provoquant oreilles remuantes et tentative de retournement.

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

Les trois surfaces ont une référence de composition ; les maquettes restent statiques et ne démontrent ni reconnaissance des gestes, ni mouvement réduit, ni conservation du fond. Les critiques de regard et de verre concernaient les premières études, désormais archivées ; les tailles CSS de la maquette ne remplacent pas un essai sur téléphone.

## Voice and Tone

Microcopies proposées, courtes et factuelles ; la voix visuelle est définie dans DESIGN.md. Pas de parole spontanée, récompense, reproche ou sollicitation de toucher.

| Usage | Formulation proposée |
| --- | --- |
| Action accessible | « Chatouiller Otc » ; substituer le nom réel du compagnon. |
| Édition du fond | « Arrière-plan », « Appliquer », « Annuler ». |
| Échec de conservation | « L'arrière-plan n'a pas été enregistré. Réessayer. » |
| Nom indisponible | « Compagnon » si nom injecté absent ou blanc ; en production Otc reste constant sur chaque profil sélectionné. |

Les libellés d'envoi, travail, réussite, erreur, arrêt et état inconnu restent ceux de l'application. Ne pas remplacer « État inconnu » par une émotion ou « Terminé » par un sourire.

## Component Patterns

Les composants portent exactement les mêmes noms que dans DESIGN.md.Components.

| Composant | Règles comportementales |
| --- | --- |
| `companion` | Repos autonome discret ; toucher volontaire → une réaction aux chatouilles ; aucune action réseau, aucun effet sur saisie, sélection du texte ou génération. Suspendre hors écran. |
| `companion-backdrop` | Dégradé pastel fixe issu des tokens existants, indépendant du profil et du réseau. |
| `companion-name` | Afficher la constante de présentation Otc ; ne pas confondre avec `Profile.label`, seul champ de libellé actuellement observé. Édition du nom hors périmètre. |
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
| Profil chargé | Otc, distinct du libellé métier du profil courant ; fond fixe et anatomie v5. |
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

La [variante v3 noir et blanc](mockups/planche-lapin-v3-noir-blanc.png), demandée par Alanc avec des oreilles légèrement plus petites, explore un compagnon blanc à traits noirs. Cette variation d'apparence ne change ni les gestes ni les états ; le fond pastel fixe reste illustré. Cette étude est archivée ; la v5 approuvée clôt le dessin.

La [planche affinée v2](mockups/planche-lapin-v2.png) est une étude ancienne archivée, remplacée par v5 : regard de côté mieux différencié, chatouilles et exemple de panneau dépoli fixe. Elle ne change aucun comportement validé et ne démontre pas les transitions animées.

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
4. Cette proposition de fond est hors lot 2 ; un autre profil conserve le même compagnon nommé Otc, distinct de son libellé métier.

Échec : si l'enregistrement échoue, conserver l'édition et proposer Réessayer ; Annuler restaure. L'endroit de stockage et la disponibilité après redémarrage restent à trancher avant de garantir l'étape 3.

### Alanc — Lire une réponse avec une présence discrète

1. Alanc envoie une demande ; le statut décrit l'envoi réel.
2. Si la piste génération est retenue, le démarrage confirmé relève légèrement les oreilles ; le texte reçu attire le regard du lapin.
3. Alanc lit et peut toucher le compagnon sans modifier ni interrompre le travail.
4. **Climax proposé :** après réussite réellement confirmée, Otc regarde Alanc puis se repose ; la réponse et son statut restent immédiatement lisibles.

Échec : erreur, arrêt ou déconnexion → libellé exact et pose neutre, jamais de fausse fin. Revenir d'arrière-plan montre l'état courant sans rejouer les animations manquées. La présence des trois points doit être arbitrée avant réalisation de ce parcours.

## Arbitrages de conception restants

Le dessin v5 est approuvé et prioritaire. Restent hors lot 2 : confirmer ou modifier la piste de génération ; décider du lien avec les trois points existants, du fond dans la marge conversation et de la personnalisation détaillée. Otc est une constante de présentation et ne nécessite aucun contrat serveur. Une éventuelle personnalisation du fond demanderait une décision ultérieure distincte du modèle `Profile` actuel. Ces ouverts n'empêchent pas de discuter la première planche, mais empêchent de qualifier ce dossier de contrat Flutter final.
