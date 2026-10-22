# Captures du lot 4

22 octobre 2026, Flutter 3.47.7 sous Windows. Génération : `rtk C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat test --no-pub test/support/lot4_capture.dart`.

Huit captures des poses inspectées : clair/sombre, 320/412 × 812 pixels logiques, échelle 100/200 %. Trois poses successives (neutre, concentration, lecture), fond neutre, oreilles entières et aucun chevauchement. À 200 %, la liste se poursuit hors cadre ; elle reste défilable. Le placement latéral est visible à 412 px, et le placement avant le texte à 320 px et à 200 %.

Deux captures supplémentaires montrent les commandes réelles du scénario de galerie à 200 %, en sombre, à 375 × 812 et 812 × 375 pixels logiques. Le focus clavier sur la pause est visible ; les libellés se développent sans débordement. Le golden `test/goldens/rabbit_work_poses.png`, également inspecté, protège repos, concentration, lecture latérale et lecture verticale aux tailles 48/64 px.

Le harness compare le composant de présentation avec du vrai Markdown, sans serveur. Il utilise Segoe UI et les icônes Material du SDK local ; chemins Windows explicites dans le script. Les captures ne prétendent pas montrer la totalité de la page métier ni un clavier système réel. Les tests de widgets couvrent séparément paysage, insets du clavier, pause, sémantique, transitions et stabilité géométrique. Pas d'appareil Android/iOS connecté : TalkBack/VoiceOver réels non essayés.

Builds debug application et galerie réussis. La référence visuelle prioritaire reste `planche-lapin-v5-proportions.png` du dossier UX du 22 octobre.
