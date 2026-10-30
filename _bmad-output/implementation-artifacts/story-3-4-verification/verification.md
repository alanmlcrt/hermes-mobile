# Vérification — catalogue des familles d’activité 3.4

23 octobre 2026. Vérifications locales synthétiques, sans connexion à l’installation personnelle Hermes.

## Résultat fonctionnel

Le catalogue déclare 17 familles et `unknown` : `code`, `fileCreate`, `tool`, `webSearch`, `fileRead`, `command`, `webBrowse`, `fileEdit`, `fileSearch`, `imageCreate`, `memory`, `delegate`, `organize`, `imageAnalyze`, `skill`, `schedule`, `preparation`. Les noms existants `code`, `tool`, `unknown` sont conservés. Le décodage JSON local reconnaît les nouvelles valeurs sans modifier `ActivityItem` ni la version de projection. Une ancienne projection sans version et une famille inconnue se replient sur `unknown`.

La galerie présente chaque famille avec libellé et paire animée/immobile ; une pause commune contrôle le scénario et les démonstrations. Les nouveaux motifs reprennent feuille/crayon, loupe/pointeur, lecture, console, dossier, image, carnet, assistants, liste, livre et calendrier/horloge dans le slot existant de 24 px. Géométrie et paramètres de mouvement sont dans `ActivityTokens`. `preparation` est sémantiquement distinct de `unknown` et reste une démonstration de galerie ; aucune nouvelle ligne de conversation ne la produit.

## Commandes et résultats

- `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat analyze --no-pub` : aucune anomalie ; contrôle final après corrections de revue : 6,0 s.
- `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat test test/activity_catalog_test.dart test/activity_line_test.dart test/gallery_test.dart test/event_mapping_test.dart` : 56 tests verts avant l’ajout du contrôle supplémentaire de la galerie à 200 %.
- `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat test --no-pub` : 345 tests verts après corrections de revue (28 s), garde-fou des tokens compris.
- `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat test --no-pub test/support/activity_catalog_capture.dart` : captures comparatives synthétiques générées, sans débordement détecté.
- `rtk git diff --check` : aucune erreur.
- `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat build apk --debug --no-pub --target lib/main.dart` : succès final après revue (22,4 s), copie conservée à `build/app/outputs/flutter-apk/story-3-4-main-debug.apk`.
- `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat build apk --debug --no-pub --target lib/main_gallery.dart` : succès final après revue (20,0 s), copie conservée à `build/app/outputs/flutter-apk/story-3-4-gallery-debug.apk`.

Les trois couches de revue ont été triées dans la spécification. Corrections intégrées : enveloppes des pièces mobiles, pinceau, aiguille fixe et protection des contours/mouvements par tests. Aucune remarque différée.

## Matrice couverte

| Entrée / condition | Preuve locale |
| --- | --- |
| 17 familles + repli | Entrées dédiées, libellés distincts, aller-retour JSON ; peinture non vide à 24 px pour les 18 valeurs. |
| Mouvement et pose | Comparaison des pixels à quatre phases animées distinctes : la pose reste stable et le rendu animé évolue. Commandes Canvas enregistrées sur 33 phases : contours fixes hors transformations mobiles et enveloppes dans le slot, demi-trait inclus. |
| Entrée absente | Catalogue vide : chaque valeur résout le repli générique. |
| Nom connu dans événement inconnu | Test de chaque nom fictif avec arguments et emoji : `unknown`. |
| `tool.start` / `tool.complete` | Test de chaque nom fictif : `tool`, sans nouvelle association. Fichiers `contracts/event-mapping.json` et `lib/data/event_mapping.dart` inchangés. |
| Suspension pendant un cycle | Suite existante exécutée pour chaque famille : mouvement réduit, pause, fin reçue, `Offstage`, hors viewport, arrière-plan et route couverte ; reprise au retour, aucun ticker actif en suspension. |
| Galerie à 200 % | Toutes les paires parcourues à 320 px ; pause atteignable, cible native ≥48 px et absence de débordement. |
| Conversation / Otc | Suite complète existante : détails, fin reçue, repli du groupe, statuts, réservation/poses Otc et interaction locale. Aucun changement dans ces composants ou repositories. |

## Captures

[Dossier des 56 captures](captures/) produit par `test/support/activity_catalog_capture.dart`. Fenêtre de 320 × 740 px, police Segoe UI chargée pour éviter la police de test : clair, sombre, texte 200 %, mouvement réduit et sombre + 200 % + réduit. Chaque ligne compare un exemple piloté par le contrôleur existant avec sa pose immobile. Les captures avec mouvement montrent une phase ponctuelle, pas une preuve vidéo de fluidité.

Exemples inspectés visuellement : [clair / lecture](captures/light-fileRead.png), [sombre / texte 200 % / mouvement réduit](captures/dark-large-reduced-fileEdit.png). Les libellés se replient et les paires restent lisibles ; les contrôles sont vérifiés séparément en haut du scénario.

## Limites

Aucun test physique sur téléphone ni essai TalkBack n’a été réalisé. Les tests de widget/sémantique et les captures ne prouvent ni l’annonce vocale sur appareil, ni la fluidité/performance de ses animations. Aucune capacité de l’installation personnelle Hermes n’est validée par ces données. Le mapping réel reste volontairement limité à `tool`/`unknown`. La commande d’arrêt reste hors story 3.4.
