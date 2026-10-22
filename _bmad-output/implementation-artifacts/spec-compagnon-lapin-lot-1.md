---
title: 'Compagnon lapin — premier lot et galerie'
type: 'feature'
created: '2026-10-22'
status: 'done'
baseline_commit: '19ec36056b36c1be86943bafcce2a16faf3be067'
route: 'dispatch'
review_loop_iteration: 1
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Le compagnon validé dans le dossier UX du 22 octobre n'existe pas encore dans Flutter. Il faut pouvoir observer et éprouver son dessin et ses réactions avant son intégration aux écrans métier.

**Approche :** Créer un composant réutilisable conforme à la planche `planche-lapin-v5-proportions.png`, avec repos, regards latéraux et chatouilles, puis l'exposer dans la galerie développeur existante.

## Boundaries & Constraints

**Toujours :** Respecter le lapin blanc aux petits yeux noirs espacés, nez triangulaire, bouche lisse et oreilles asymétriques sans pli de la v5. Conserver cette anatomie en regardant des deux côtés, sans miroir global. Maintenir une enveloppe stable, un fond fixe et une cible interactive d'au moins 48 px. Fournir activation tactile, clavier et sémantique « Chatouiller [nom] ». Le mouvement réduit système prévaut immédiatement, même pendant une réaction. Suspendre hors écran, lorsque la surface est masquée et en arrière-plan ; reprendre au repos sans rattrapage. La galerie montre les tailles 180, 64 et 48 px, dans les variantes existantes clair/sombre/texte 200 %/mouvement réduit.

**Jamais :** Liaison à la génération, changement des statuts ou des trois points, intégration aux profils/conversations, nouveau champ de profil, persistance du nom ou du fond, éditeur de personnalisation, réseau, nouvelle dépendance ou changement de thème global. Otc est une fixture de galerie, pas le nom attribué à tous les profils. Aucune texture, couture, particule ou fond animé.

## I/O & Edge-Case Matrix

| Situation | Entrée / état | Résultat attendu | Traitement |
| --- | --- | --- | --- |
| Présence | Visible, mouvement autorisé | Repos puis petits regards gauche/droite espacés | Retour face entre les regards |
| Toucher | Activation confirmée | Oreilles remuantes et tentative de détourner la tête, puis repos | Touches supplémentaires ignorées pendant la réaction |
| Défilement | Glissement ou pointeur annulé | Aucune chatouille | Laisser défiler la galerie |
| Mouvement réduit | Préférence active ou activée en cours | Aucun mouvement autonome ; toucher : pose fixe immédiate puis face | Aucun mouvement résiduel |
| Suspension | Arrière-plan, masqué ou hors viewport | Aucun cycle ni minuterie active | Reprise neutre, sans rejouer |
| Libération | Widget retiré pendant une réaction | Aucun rappel après destruction | Annuler contrôleurs et minuteries |

</frozen-after-approval>

## Code Map

- `lib/ui/components/rabbit_companion.dart` — nouveau composant public autonome ; dessin vectoriel Flutter et réactions locales.
- `lib/ui/tokens.dart` — source unique des couleurs, dimensions et durées ; garde-fou `test/visual_literals_test.dart`.
- `lib/ui/content.dart` — libellés accessibles et fixtures séparés des styles.
- `lib/ui/gallery.dart` — `ComponentGallery`, `_VariantFrame`, quatre variantes existantes ; actuellement huit sections.
- `lib/main_gallery.dart` — entrée développeur isolée de `main.dart`.
- `lib/ui/theme.dart` — thème et mouvement réduit existants à respecter.
- `test/gallery_test.dart` — assertions des variantes et absence de débordement.
- Dossier `ux-designs/ux-Hermes Mobile-2026-10-22` — DESIGN, EXPERIENCE et planche v5, référence prioritaire sur les essais antérieurs.

## Tasks & Acceptance

**Exécution :**
- [x] `lib/ui/tokens.dart` — centraliser les réglages du compagnon.
- [x] `lib/ui/content.dart` — ajouter les textes du composant et de l'aperçu.
- [x] `lib/ui/components/rabbit_companion.dart` — implémenter dessin, cycle local, accessibilité, suspension et nettoyage.
- [x] `lib/ui/gallery.dart` — ajouter un aperçu interactif et compact, ainsi qu'une commande de pause accessible ; suspendre les aperçus hors écran.
- [x] `test/rabbit_companion_test.dart` — couvrir les cas de la matrice, activation clavier/sémantique et dimensions stables.
- [x] `test/gallery_test.dart` — adapter les comptes et vérifier la nouvelle section dans les quatre variantes.

**Critères d'acceptation :**
- Étant donné la v5, quand les poses sont comparées visuellement en grand et compact, alors les proportions et les traits distinctifs restent reconnaissables et les oreilles entières.
- Étant donné une largeur de téléphone ou un paysage et un texte agrandi à 200 %, quand l'aperçu est affiché dans les deux thèmes, alors aucun débordement ni chevauchement n'apparaît.
- Étant donné une préférence de mouvement réduit ou une pause, quand l'aperçu est observé, alors son fond et son repos restent fixes et les commandes demeurent utilisables.

## Implementation Notes

- Vérification finale parent après patches : analyse sans anomalie, suite complète 233 tests réussis, APK debug galerie recompilé (23,9 s), diff sans erreur d'espacement. Revue terminée : bounds transformés, actions désactivées hors disponibilité et reprise de route corrigés ; nettoyage documentaire historique différé. Aucun appareil connecté pour valider TalkBack/clavier physique.

- Reconstruction après revue : observation de composition des couches retenues sans polling, dépendances Scrollable, halo creux, légère perspective et traits compacts ajustés. Tests ajoutés pour déplacement d'ancêtre, remplacement de contrôleur, thème pendant pose fixe, reprise utilisable, pause effective des aperçus et limites peintes. Analyse propre, 231 tests réussis, APK galerie compilé ; goldens compagnon et focus inspectés.

- `RabbitCompanion` accepte explicitement le nom, la taille, `paused` et `active` ; nom blanc/absent → « Compagnon ». Aucun modèle de profil ni stockage n'a été modifié.
- Contrat de surface conservée : le propriétaire doit fournir `active: false` pour une sous-vue masquée via `Offstage`, un onglet conservé ou une autre technique qui ne désactive pas `TickerMode`. Le composant suspend automatiquement sur `TickerMode` désactivé, route non courante, arrière-plan et sortie des viewports de défilement ancêtres. Chaque reprise repart de face, avec un nouveau délai complet.
- Géométrie, palette et durées regroupées dans `RabbitTokens` ; dessin vectoriel sans miroir global. Le fond de galerie est un dégradé pastel précomposé fixe. Focus noir avec halo blanc pour conserver une limite visible sur surface claire, sombre ou pastel.
- Réaction tactile au relâchement confirmé via `InkWell`, activation clavier native et action sémantique équivalente ; réactions supplémentaires ignorées. Mouvement réduit ou pause : réaction fixe limitée dans le temps. Préférence système changée pendant la réaction : arrêt immédiat et retour face.
- Référence effectivement chargée : dossier `_bmad-output/planning-artifacts/ux-designs/ux-Hermes Mobile-2026-10-22`, DESIGN, EXPERIENCE et bitmap v5. Le frontmatter `context: []` ne liste aucun fichier supplémentaire.

## Spec Change Log

- Revue 1 : corriger les dépendances de visibilité et la géométrie de pose, le focus et l'optique compacte. Éviter des cycles hors écran, une reprise bloquée, un fond blanchi au focus et des détails trop fins. KEEP : anatomie blanche/noire v5, oreilles asymétriques sans miroir, composants/chaînes/tokens séparés, isolation métier, durées et priorités de mouvement réduit, pause accessible, tests existants et build galerie. Le code précédent est sauvegardé hors dépôt dans `C:/Users/alanc/AppData/Local/Temp/hermes-rabbit-preserved` ; réutiliser ses éléments KEEP pour reconstruire les fichiers corrigés après le retour au baseline.

## Review Triage Log

| Revue 1 | Verdict | Preuve et traitement |
| --- | --- | --- |
| B1 — visibilité après layout | medium | Seuls scroll, métriques, dépendances et update déclenchent le contrôle ; un enfant constant déplacé par un ancêtre garde une visibilité obsolète. bad_spec, renforcer le suivi sans boucle permanente. |
| B2 — remplacement ScrollPosition | medium | La collecte par visite des états n'établit aucune dépendance sur la position ; controller remplacé avec enfant constant : abonnement périmé. bad_spec. |
| B3 — halo focus | medium | BoxShadow sans flou peint un rectangle blanc plein derrière une surface transparente, donc blanchit le pastel. bad_spec. |
| B4 — tentative de retournement | medium | La tête garde le même ovale frontal et le visage est seulement translaté ; la joue n'est pas présentée comme dans la v5. bad_spec, différencier légèrement la perspective. |
| B5 — optique compacte | medium | Trait du visage 2,8 × 48/240 = 0,56 px, sans compensation ; contour 0,24 px. bad_spec, épaissir optiquement sans grossir les yeux. |
| B6 — changement de thème pendant pose fixe | low | didChangeDependencies appelle _sync qui annule toute réaction lorsque mouvement réduit actif. Correction directe de synchronisation à intégrer dans la reconstruction. |
| B7 — table de teinte historique | low | Document utilisateur préexistant : la table garde taupe malgré priorité v5 blanche explicite. defer, incohérence documentaire hors nouveau code. |
| B8 — ancienne maquette de contexte | low | Source utilisateur préexistante liée depuis les contrats ; SVG historique taupe et oreille pliée. defer, signaler comme étude antérieure lors d'un futur nettoyage documentaire. |
| B9 — variantes hors viewport non éprouvées | false | SingleChildScrollView/Column calcule toutes les tailles hors écran ; les erreurs de layout sont remontées. Le test change bien orientation et échelle et construit le sombre à 200 %. Ajouter néanmoins inspection par variante avec les tests renforcés. |
| B10 — poses compactes et limites peintes | medium | Golden compact au repos seulement ; le rectangle du widget ne démontre pas l'absence de dessin hors enveloppe. bad_spec, renforcer les échantillons et la preuve peinte. |
| V1 — pause galerie non observée | medium | Supprimer paused:_paused ne ferait échouer aucune assertion ; gap vérifié. patch de tests à inclure dans la reconstruction. |
| V2 — reprise utilisable non observée | medium | Un _foreground restant faux satisfait le test qui vérifie seulement gaze==0 au retour. patch de tests à inclure. |
| E1 — déplacement sans reconstruction | medium | Même cause démontrée que B1 : enfant constant, layout ancêtre changé, aucune notification consommée. Grouper B1/E1, bad_spec. |
| Revue 2 B1 — bounds transformés | medium | localToGlobal du coin + taille locale ne couvre pas scale/rotation ; remplacer directement par transformation du rectangle complet. patch. |
| Revue 2 B2 — viewport transformé | medium | Même calcul incomplet pour le rectangle de viewport ; même correction, grouper avec B1 et E1 revue 2. patch. |
| Revue 2 B3 — interaction inactive | medium | active:false laisse Semantics/InkWell actifs alors que _tickle ne fait rien. Correction directe : désactiver action et focus lorsque indisponible. patch. |
| Revue 2 B4 — taille sous contrainte | low | Les appelants du lot fournissent 48/64/180 et Wrap réserve la place ; minimum documenté et assert. Parent arbitrairement trop contraint hors galerie : défaut de contrat potentiel mais improbable ici, rejeté car imposer une nouvelle politique de layout ajouterait de la complexité. |
| Revue 2 B5 — preuve des timers | false | Les branches de suspension appellent _cancel, qui annule explicitement _timer et stoppe _motion ; aucun cycle hors écran avéré. Les tests de pose ne suffisent pas seuls mais le code établit la cancellation. |
| Revue 2 B6 — ancien abonnement | false | didChangeDependencies retire les listeners de toutes les anciennes positions avant de vider le set et d'ajouter les nouvelles ; l'abonnement périmé décrit ne subsiste pas. |
| Revue 2 B7 — scroll imbriqué non testé | low | Couverture de la boucle ancêtre limitée au cas simple ; aucun défaut constaté, galerie à un seul scroll. Rejeté : étendre les fixtures imbriquées ajouterait une complexité non justifiée pour ce lot. |
| Revue 2 B8 — états lifecycle non testés | false | Tous les états autres que resumed partagent exactement le même prédicat et la même branche de suspension, déjà exercée par paused ; aucune branche spécifique manquante. |
| Revue 2 B9 — toutes commandes en paysage | low | Les variantes partagent le même layout, testé sous les deux dimensions ; parcours de commandes couvert séparément. Rejeté : matrice d'interactions supplémentaire peu utile sans défaut démontré. |
| Revue 2 B10 — historique UX | low | carried : documents utilisateur préexistants avec priorité v5 explicite, incohérences déjà différées en revue 1 B7/B8 ; aucun nouvel ajout différé. |
| Revue 2 V1 — reprise de route non prouvée | medium | Gap vérifié : assertions uniquement neutres après pop ; compléter par toucher et premier regard après délai. patch. |
| Revue 2 E1 — scale/rotation | medium | Même cause que B1/B2 revue 2 ; transformation du rectangle entier règle le coin transformé avec taille locale. patch. |

Résolution revue 2 : B1/B2/E1 corrigés par MatrixUtils.transformRect aux deux calculs et régression de scale aux bords ; B3 corrigé par désactivation de l'action, du focus et sémantique disabled ; V1 complété par réaction et regard après retour de route. Les 21 tests ciblés puis les 233 tests complets passent. Aucun problème fonctionnel retenu non corrigé ; incohérences historiques des sources UX déjà différées.

## Design Notes

Rendu vectoriel natif pour adapter la même anatomie aux différentes tailles. Les réglages initiaux restent ajustables : pause de 6 s entre regards, trajet de 300 ms, maintien de 700 ms, chatouilles de 1 100 ms. Ce sont des choix d'implémentation issus des plages proposées par l'UX, sans nouvelle chorégraphie de génération. Fond pastel fixe d'exemple dans la galerie ; nom fourni explicitement, avec « Compagnon » en secours.

Reconstruction après revue : suivre les limites réellement peintes lors d'un layout ou déplacement d'ancêtre (enfant constant compris), sans minuterie/polling hors écran. Les abonnements de scroll doivent suivre le remplacement d'une ScrollPosition via une vraie dépendance ; prouver le remplacement du contrôleur par un test. Préserver la pose fixe de chatouilles lors d'un changement de thème sans changement de disponibilité. Dessiner le halo de focus en anneau sans remplir son centre ; golden ciblé sur pastel. Donner à la tête/visage une légère perspective de retournement reconnaissable, sans inverser les oreilles. Adapter les traits en compact pour rester lisibles ; étendre le golden aux regards et chatouilles 48/64, et contrôler les limites peintes aux amplitudes extrêmes. Tester les lapins visibles de la galerie après Pause puis Reprendre (pas seulement le libellé) ; après reprise lifecycle, tester toucher et reprise autonome après délai complet. Parcourir visiblement les quatre variantes pour les vérifications de galerie.

## Verification

Exécution du 22 octobre 2026 : `fvm` n'est pas présent dans le PATH de cette session. Commandes lancées avec `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat` (SDK exact du `.fvmrc`). Analyse sans anomalie ; suite complète de 224 tests réussie, puis 20 tests ciblés réussis après ajout du test route masquée et du focus contrasté. APK debug galerie compilé. Les tests couvrent aussi le texte système à 200 % en clair/sombre, portrait 375 px et paysage, pause, suspension et nettoyage.

Rendu inspectable : `test/goldens/rabbit_companion.png` (face, gauche, droite, chatouilles, 64/48 px), généré puis comparé visuellement à la v5. Oreilles entières, asymétrie conservée, petits yeux espacés, nez et bouche lisse reconnaissables ; déplacement du regard limité pour garder les yeux dans le visage. Le golden verrouille ce rendu vectoriel et ne prétend pas reproduire les ombrages du bitmap.

Limite : `adb devices` ne liste aucun appareil ni émulateur. Contrôles interactifs sur appareil (notamment TalkBack, clavier physique et inspection du mouvement) non réalisés ; les preuves actuelles sont les tests Flutter, le PNG inspecté et la compilation Android.

- `rtk proxy fvm flutter analyze` — aucune erreur.
- `rtk proxy fvm flutter test` — tests nouveaux et existants réussis, frontières d'import et tokens compris.
- `rtk proxy fvm flutter build apk --debug -t lib/main_gallery.dart` — galerie compilable sur Android.
- Comparaison visuelle du rendu avec la v5 ; contrôles du focus, des tailles compactes et de la suspension après défilement. Consigner toute vérification sur appareil non réalisable.
