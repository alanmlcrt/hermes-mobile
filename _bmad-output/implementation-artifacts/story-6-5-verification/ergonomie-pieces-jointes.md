# Correctif de présentation des pièces jointes — préparation +24

Retour d'Alanc pendant M02 : les quatre formats sont lus, mais les pièces occupent trop de place après sélection. Le correctif conserve le sélecteur natif, le transport et le stockage existants.

- Chaque pièce utilise une ligne de nom ellipsé et une taille courte, avec icône ou aperçu ; retrait sur la même rangée, cible 48 dp et nom accessible propre au fichier.
- Le nom complet reste annoncé au lecteur d'écran et disponible visuellement par appui long (tooltip). Le MIME brut et « Sélectionné localement » ne sont plus affichés ; cet état reste attaché au nom dans la sémantique. Téléversement, réception à vérifier, reçu, erreur, incertitude et copie manquante restent explicites, avec réessai volontaire.
- La zone des pièces et son avertissement d'analyse d'image occupent au plus 30 % de la hauteur disponible après clavier ; elle défile avec Scrollbar visible et contrôleur géré par la page. Une marge `Spacing.sm` sépare les pièces de la saisie. Avec pièces, le champ montre au plus deux lignes ; le texte intégral reste éditable par défilement.

## Vérification automatisée et rendus synthétiques

`fvm flutter analyze` : aucun problème. Suite complète avant le dernier ajustement Scrollbar/sémantique : 618 réussis, 17 ignorés. Après ces ajustements : 13 tests ciblés réussis (`attachment_compact_test.dart`, `attachment_flow_test.dart`, `support/attachment_compact_capture.dart`) et analyse sans problème.

Les nouveaux tests couvrent nom complet accessible, état local sémantique, retrait nommé de 48 dp, callback de retrait, réessai et callback, tous les états, copie manquante, pièce envoyée sans retrait, clair/sombre, texte 200 %. Le rendu de `DraftView` utilise huit pièces, un écran 375 × 812, inset clavier simulé de 280 dp et mouvement réduit ; il vérifie que champ et envoi restent au-dessus du clavier et que le retrait de la huitième pièce devient accessible après défilement. Les tests existants couvrent aussi la liste en paysage 812 × 375 à 200 %.

Rendus générés par `test/support/attachment_compact_capture.dart` :

- [Clair 100 % avec clavier simulé](captures/composer-light-375-1.0x-clavier.png)
- [Clair 200 % avec clavier simulé](captures/composer-light-375-2.0x-clavier.png)
- [Sombre 100 % avec clavier simulé](captures/composer-dark-375-1.0x-clavier.png)
- [Sombre 200 % avec clavier simulé](captures/composer-dark-375-2.0x-clavier.png)

Ces images sont des rendus de widgets avec données neutres ; elles ne sont **pas** des captures du téléphone et ne valident aucun parcours réel du MVP. Le coordinateur a inspecté les rendus clair 200 % et sombre 100 %, puis construit et installé la release +24. Le rejeu sur téléphone par Alanc reste à faire.

## Livraison sur téléphone

- `fvm flutter build apk --release --build-number=24` : exit 0, assembleRelease 141,9 s.
- APK : 57 576 547 octets, SHA-256 `59ff3364a80fb87c4c00a222720ae9930623ab7b5a28bd044dd555a15397cec4`.
- Installation annoncée puis `adb install -r build/app/outputs/flutter-apk/app-release.apk` : `Success`, sans effacement.
- Version relue par `dumpsys package` à 2026-10-30T16:42:07Z : `fr.hermes_mobile`, versionName 0.1.0, versionCode 24.
- Validation humaine de la présentation compacte : en attente. Les observations précédentes M01/M02 portent sur +23 ; ne pas les attribuer à +24.

Une première tentative de capture en parallèle de la suite a rencontré le verrou Windows de `sqlite3.dll` ; relance séquentielle réussie. Aucun changement système ni de données pour contourner ce verrou.
