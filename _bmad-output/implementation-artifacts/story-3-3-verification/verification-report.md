# Rapport de vérification — Story 3.3 : Reconnaître l’activité grâce aux illustrations animées

## 1. Arbitrages UX validés par Alanc

Alanc a validé les trois recommandations (« Fait tout ce que tu recommandes », Options A retenues) :
1. **Conciliation `UX-DR13` / lot 4 Otc :** aucune ligne « Préparation de réponse » n'est ajoutée au fil de conversation — Otc seul porte la préparation de réponse au niveau du tour conformément au lot 4. Le motif des trois petits points en rotation (dans le slot 24 × 24 px, sans bulle ni grand dessin, immobile en variante fixe) illustre `ActivityKind.unknown` et sert de repli générique du catalogue.
2. **Catalogue dès 3.3 (`code`, `tool`, `unknown`) :** `ActivityCatalog` est indexé exclusivement par `ActivityKind` avec repli générique, sans lire un emoji, un nom d'outil MCP, une sous-chaîne de `details['name']` ou une minuterie. Il expose 3 illustrations (`code` : châssis d'ordinateur fixe aux traits épais, lignes et curseur mobiles ; `tool` : boîtier machine, clé oscillante et impulsion ; `unknown` : trois petits points en rotation 24 × 24 px), toutes présentées dans la galerie en clair, sombre, texte 200 % et mouvement réduit.
3. **Fin d'action et pause de la page :** toute ligne avec `completed: true` (« Fin reçue ») ou lorsque la pause de la page (`_companionPaused` dans `DraftView`) est active affiche immédiatement sa variante immobile sans timer ni cycle actif.

## 2. Vérifications automatisées et builds

- `flutter analyze --no-pub` : `No issues found!`
- `flutter test` : l'intégralité de la suite de tests passe, y compris :
  - `test/visual_literals_test.dart` (aucun littéral visuel hors `lib/ui/tokens.dart` et `lib/ui/theme.dart`)
  - `test/activity_line_test.dart` (indexation par `ActivityKind`, repli générique, isolation de `details['name']`/emoji, châssis fixe de `code` vs lignes/curseur mobiles, rotation des 3 points de `unknown`, suspension immédiate sous mouvement réduit / pause / `completed` / `Offstage` / hors viewport / route couverte / arrière-plan avec `transientCallbackCount == 0`, remplacement d'entrée dans `ActivityCatalog` sans toucher à `EventMapping` ni à `HermesRpc`)
  - `test/gallery_test.dart` (présentation des 3 illustrations dans les 4 variantes `Clair`, `Sombre`, `Texte agrandi 200 %`, `Mouvement réduit`, non-régression Otc)
  - `test/conversation_test.dart` (propagation de la pause de la page vers `ActivityLine`, préservation de `WorkStateLabel` et des 4 lots Otc)
  - `test/action_details_page_test.dart` et `test/activity_details_regression_test.dart` (non-régression 3.1/3.2)
- Builds APK debug :
  - `flutter build apk --debug -t lib/main.dart`
  - `flutter build apk --debug -t lib/main_gallery.dart`
- Captures visuelles générées sous `_bmad-output/implementation-artifacts/story-3-3-verification/captures/` (24 captures : clair/sombre, largeurs 320/375/812 px, échelles 1.0/2.0, états déplié/replié).
