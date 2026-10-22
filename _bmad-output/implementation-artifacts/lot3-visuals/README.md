# Vérification visuelle du lot 3

Captures produites par `flutter test test/support/lot3_capture.dart` avec Flutter 3.47.7, viewport 375 × 812, mouvement réduit, police Segoe UI et icônes Material chargées dans le harness.

Les fichiers `editor-*-top`, `editor-*-commands`, `editor-*-focus` et `editor-*-palette-focus` montrent le haut, les commandes, le focus clavier du compagnon et celui d'une palette. `panel-*` montre le panneau enregistré. Les variantes couvrent clair/sombre et texte 100/200 %. Les tests de widgets couvrent aussi 700 × 375, le clavier, la sélection sémantique, les erreurs et les retours.

Complément après revue : `palette-lavender_peach-*`, `palette-mint_sky-*` et `palette-rose_lilac-*` montrent chacune des trois palettes, y compris le défaut Lavande et pêche, en clair/sombre et texte 100/200 %. Les captures antérieures sont conservées. Inspection du défaut en clair 100 % et sombre 200 %, de Menthe et ciel en clair 100 % et de Rose et lilas en sombre 200 % : couleurs distinctes, visage net et oreilles entières.

Inspection : visage net, oreilles entières, voile limité au fond, texte et boutons sur surfaces du thème, sélection nommée, aucun chevauchement ni débordement observé. Le dessin du lapin et ses tokens d'anatomie n'ont pas été modifiés.

Limites : captures de widgets, sans validation TalkBack ni appareil Android réel. Les exports ne constituent pas des goldens supplémentaires de l'anatomie.
