# Captures du lot 2

Captures Flutter produites le 22 octobre 2026 par les tests de widgets avec Flutter 3.47.7, à partir du code de production et au repos, mouvement réduit activé. Les états métier sont synthétiques (`one.example`, profils Principal/Travail). Aucun serveur personnel n’a été contacté.

- `profiles-{light,dark}-{100,200}.png` : surface « Mes profils », 375 × 812 pixels logiques, texte à 100 % ou 200 %, thème indiqué dans le nom.
- `long-name-{light,dark}-landscape-200.png` : nom de compagnon long injecté, 700 × 375 pixels logiques, texte 200 % ; le contenu et la pause restent accessibles par défilement, vérifiés par les tests.

Le test de widget couvre aussi un libellé de profil long en thème sombre avec texte à 200 %. Ce cas n’a pas de capture dédiée.

Le texte utilise Segoe UI chargé dans le harness de capture pour éviter la police de test Ahem. Les icônes Material ne sont pas chargées dans ces captures et apparaissent comme des carrés ; cela ne représente pas le rendu de l’APK. Ces PNG sont des preuves d’inspection ponctuelles, pas de nouveaux goldens du lapin.

Vérifications : suite complète Flutter 237/237 ; tests de profils couvrant les sélections vérifiées, le chargement stable, les états vides, le reset de pose, la pause, le mouvement réduit immédiat, les noms absents/longs, le viewport, les routes et le cycle de vie. Builds APK debug application et galerie réussis.
