---
title: 'Story 3.4 — Compléter le catalogue des familles d’activité'
type: 'feature'
created: '2026-10-23'
status: 'done'
baseline_commit: '3979abb19b5388a689bacf8bce9fadd29b5f4e1b'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/investigation-epic-3-activites.md'
---

<frozen-after-approval reason="intention réservée à l’humain — modification après renégociation uniquement">

## Intent

**Problème :** Le catalogue de 3.3 propose code, outil et repli générique. Il manque les autres familles de la maquette acceptée.

**Approche :** Compléter les 17 familles visuelles et leurs variantes immobiles, comparables dans la galerie. Conserver les seules associations documentées du contrat actuel, sans inventer de classification serveur.

## Boundaries & Constraints

**Toujours :** Catalogue indexé par `ActivityKind`, slot de 24 px, dessins vectoriels et paramètres centralisés dans `ActivityTokens`, textes dans `Content`. Reprendre les motifs de `mockups/simple-conversation.html`, adaptés à cette taille. Conserver le châssis code fixe et le contrôleur de suspension de 3.3 : mouvement réduit, pause, fin reçue, hors écran, route masquée et arrière-plan immobilisent immédiatement les dessins.

**Jamais :** Inférer une famille par nom d’outil, emoji, arguments ou minuterie ; modifier `WorkState`, les identités, détails ou fins d’action depuis un dessin ; ajouter la commande d’arrêt. Préserver les quatre lots Otc et l’unique région live de statut.

**Préparation de réponse :** Son entrée à trois points est démontrée uniquement dans la galerie. En conversation, Otc conserve ce rôle selon la décision 3.3 ; aucune nouvelle ligne de préparation n’est produite. Le repli générique reste distinct sémantiquement, même s’il partage ce motif.

## I/O & Edge-Case Matrix

| Entrée | Résultat attendu | Repli |
|---|---|---|
| Chacune des 17 familles fictives | Dessin et libellé dédiés, animés ou immobiles | Entrée absente : générique |
| Événement inconnu contenant un nom connu | `unknown`, sans qualification supposée | Générique |
| `tool.start` / `tool.complete` | `tool`, même si le nom évoque une autre famille | Mapping inchangé |
| Ancien JSON / famille inconnue | Compatibilité conservée | `unknown` |
| Suspension pendant un cycle | Variante immobile, aucun timer/ticker actif | Reprise au retour visible |

</frozen-after-approval>

## Code Map

- `lib/models/timeline.dart` : étendre `ActivityKind` et son décodage local ; préserver `ActivityItem` et la version de projection.
- `lib/ui/components/activity_catalog.dart` : étendre les entrées, réutiliser `ActivityIllustration` et ses suspensions ; isoler les nouveaux peintres dans `lib/ui/components/activity_family_painters.dart`.
- `lib/ui/tokens.dart`, `lib/ui/content.dart` : géométrie, mouvement et libellés.
- `lib/ui/gallery.dart` : `ActivityPreview`, variantes clair/sombre/200 %/mouvement réduit ; séparer démonstration et événements réels.
- `contracts/event-mapping.json`, `lib/data/event_mapping.dart` : conserver `tool`/`unknown` ; aucune preuve disponible pour une nouvelle association réelle.
- `_bmad-output/planning-artifacts/ux-designs/ux-Hermes Mobile-2026-10-20/mockups/simple-conversation.html` : référence des motifs et mouvements ; contrats courants du 22 octobre prioritaires pour Otc.

## Tasks & Acceptance

**Exécution :**
- [x] `lib/models/timeline.dart`, `lib/ui/content.dart` — Déclarer les 17 familles plus `unknown`, décodage et libellés ; conserver les noms existants.
- [x] `lib/ui/components/activity_catalog.dart`, `lib/ui/components/activity_family_painters.dart`, `lib/ui/tokens.dart` — Ajouter création/modification de fichier (feuille/crayon), recherche/navigation web (loupe/pointeur), lecture (barre), commande (console), recherche de fichier (dossier/loupe), création/analyse d’image (pinceau/cible), mémoire (carnet), délégation (assistants), organisation (liste), compétence (livre), planification (calendrier/horloge), préparation (points). Chaque motif possède un mouvement local et une pose immobile lisible ; conserver code et outil.
- [x] `lib/ui/gallery.dart` — Présenter chaque famille avec libellé et exemples animé/immobile comparables, pause commune, variantes existantes et mention fictive ; garder les contrôles atteignables après agrandissement.
- [x] `test/activity_line_test.dart`, `test/gallery_test.dart`, `test/event_mapping_test.dart` (ou test existant équivalent) — Couvrir toute la matrice, les 17 entrées sans repli involontaire, mouvements et poses, sérialisation, mapping inchangé et suspension de toutes les familles.
- [x] `_bmad-output/implementation-artifacts/story-3-4-verification/`, documents UX courants — Captures comparatives, résultats et limites des vérifications ; actualiser la traçabilité.

**Critères d’acceptation :**
- Given les familles de la maquette, when la galerie est parcourue, then les 17 familles et le repli sont identifiables en clair, sombre, texte 200 % et mouvement réduit, avec variantes immobiles.
- Given un événement réel, when la projection le classe, then seul le contrat détermine sa famille et aucune démonstration ne crée une association serveur.
- Given la conversation existante, when le catalogue est complété, then Otc, détails dépliables, fins reçues et statut accessible conservent leurs comportements.

## Implementation Notes

Catalogue complété sans modification du mapping ni du contrôleur de suspension. Audit du diff effectué ; les cinq lignes de la matrice sont couvertes par `activity_catalog_test.dart`, `event_mapping_test.dart` et les tests de suspension paramétrés de `activity_line_test.dart`, exécutés avec succès dans la suite de 344 tests. La galerie à 320 px/200 % et les captures ont aussi été vérifiées. Résultats et limites : [rapport](story-3-4-verification/verification.md).

Après revue : amplitudes corrigées, tête de pinceau précisée, petite aiguille fixe et commentaires traduits. Les tests comparent quatre phases raster et enregistrent les commandes Canvas sur 33 phases, avec demi-trait dans l’enveloppe et contour fixe hors transformations mobiles. Ces assertions couvrent Blind 4/5/8/10, Edge 1 et Verification 1 ; les corrections sont intégrées. Nouvelle analyse sans anomalie et suite complète de 345 tests verte ; captures régénérées et inspectées.

Clôture : les deux APK debug finaux ont été reconstruits avec succès après revue (application 22,4 s ; galerie 20,0 s). Aucun élément différé. Essais téléphone/TalkBack et installation personnelle Hermes non réalisés, conformément aux limites du rapport.

## Spec Change Log

## Review Triage Log

| Source | Remarque | Verdict | Preuve et traitement |
|---|---|---|---|
| Blind 1 | Captures finales identiques | false | En bas du document, plusieurs familles tiennent intégralement dans le même viewport. Les images communes montrent bien chacune des lignes visées ; une capture distincte par ligne n’est pas nécessaire à la comparaison. |
| Blind 2 | Cinq familles capturées dans certaines variantes | false | Les captures sont des viewports, pas des vignettes isolées. `light-tool` montre notamment outil, code, création, recherche et lecture ; `light-unknown` couvre les dernières familles. Le même parcours couvre clair, sombre et réduit ; toutes les entrées sont aussi parcourues par les tests. |
| Blind 3 | Polices du générateur liées au poste | low | Le script de captures local échouerait ailleurs sans adaptation, comme les générateurs antérieurs. Il est hors découverte automatique des tests et le rapport le décrit comme local ; rendre les polices portables demanderait des paramètres ou assets supplémentaires pour un usage occasionnel. Rejet selon la règle des défauts faibles non quotidiens dont la correction ajoute de la complexité. |
| Blind 4 | Loupe web hors emprise | low | À phase négative, x=29+3, augmenté du demi-trait, dépasse le repère 32. Correction directe des amplitudes ; vérifier aussi les autres enveloppes. Route patch. |
| Blind 5 | Création d’image au crayon au lieu du pinceau | low | Le polygone ressemble à un crayon ; le motif approuvé nomme un pinceau. Modifier directement le tracé de sa tête. Route patch. |
| Blind 6 | Géométrie visible à travers les éléments superposés | low | Le dessin au trait laisse effectivement voir les intersections, mais les motifs restent reconnaissables sur les captures à 24 px. Ajouter masques, couleurs de fond ou surfaces au constructeur complexifierait ce rendu décoratif pour un bénéfice cosmétique. Rejet selon la règle des défauts faibles. |
| Blind 7 | Lecture sinusoïdale au lieu de paliers | low | La barre traverse les lignes dans un mouvement local lisible ; reproduire les paliers de la maquette nécessiterait un pilotage spécifique. L’adaptation à 24 px conserve le motif approuvé. Rejet selon la règle des défauts faibles dont la correction ajoute de la complexité. |
| Blind 8 | Les deux aiguilles tournent ensemble | low | Les deux segments figurent dans le chemin mobile, ce qui rigidifie leur angle. Déplacer directement la petite aiguille dans le tracé fixe ; le mouvement local de l’horloge suffit à l’adaptation du calendrier. Route patch. |
| Blind 9 | Page coulissante plutôt que basculante | low | Le livre reste fixe et seule sa page se déplace. Une bascule autour du dos demanderait de nouveaux paramètres de transformation pour cette approximation décorative. Rejet selon la règle des défauts faibles. |
| Blind 10 | Un seul instant animé testé | medium | Un faux rendu animé constant pourrait passer le test actuel. Comparer plusieurs phases et vérifier les contours fixes. Route patch. |
| Blind 11 | Table et chemins publics mutables | false | Aucun consommateur ne retire une entrée ni ne modifie un Path après initialisation : catalogue et peintre ne font que les lire. Le crash décrit exige une mutation absente de tous les chemins exécutables du projet. |
| Edge 1 | Note mémoire hors slot | low | L’extrait cité par le relecteur est inexact, mais le code réel utilise une amplitude 4 : y=3−4 dépasse bien le repère. Réduire directement l’amplitude en incluant le demi-trait. Route patch. |
| Verification 1 | Contours fixes non protégés par un test | medium | Lacune vérifiée : déplacer le dessin du contour après les transformations mobiles laisserait les tests actuels verts. Ajouter une assertion de rendu/commandes Canvas pour protéger sa position. Route patch, racine commune avec Blind 10. |
| Audit parent | Commentaires ajoutés en anglais | low | Quelques commentaires de nouveaux fichiers ne respectent pas la langue du workflow. Traduction directe. Route patch. |

## Verification

- `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat analyze --no-pub` — aucune anomalie.
- `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat test` — suite verte, garde-fou des tokens compris.
- Builds APK debug `lib/main.dart` et `lib/main_gallery.dart` — succès.
- Captures à petit écran, 200 %, clair/sombre et mouvement réduit ; validation sur téléphone/TalkBack rapportée séparément, jamais déduite des tests synthétiques.
