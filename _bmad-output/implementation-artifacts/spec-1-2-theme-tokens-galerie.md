---
title: 'Story 1.2 : Poser le thème système, les tokens et la galerie de composants'
type: 'feature'
created: '2026-10-21'
status: 'done'
baseline_commit: 'd9a7920fbf71213b354f3e00a086f6167e690cc6'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** L'app n'a ni thème, ni tokens, ni composants. Les écrans des stories 1.4 à 1.7 disperseraient sinon des valeurs visuelles, et le design ne pourrait pas évoluer sans toucher au fonctionnement.

**Approach:** Poser dans `lib/ui` une source unique de tokens, un thème clair/sombre alimenté par Dynamic Color avec une palette de secours, un fichier de libellés séparé, et une galerie de composants lancée par un point d'entrée de développement distinct. Un test interdit les valeurs visuelles littérales hors des fichiers de tokens et de thème.

## Boundaries & Constraints

**Always:**
- Rôles résolus à l'exécution : canvas=`surface`, content=`onSurface`, emphasis=`primary`, emphasis-content=`onPrimary`. Les composants lisent `Theme.of(context).colorScheme` via ces noms, jamais un hexadécimal.
- `DynamicColorBuilder` (dynamic_color 2.1.0, déjà installé) fournit les schémas clair/sombre. S'ils sont `null`, la palette de secours de `lib/ui/theme.dart` s'applique. `themeMode: ThemeMode.system`.
- Littéraux visuels (couleurs, nombres d'espacement, rayons, élévations, tailles d'icônes, durées, tailles de police) uniquement dans `lib/ui/tokens.dart` et `lib/ui/theme.dart`.
- Libellés d'interface uniquement dans `lib/ui/content.dart`. Vocabulaire quotidien.
- La galerie n'entre pas dans l'APK release : point d'entrée séparé `lib/main_gallery.dart`.
- Aucun état exprimé seulement par la couleur ; chaque icône d'action a un nom accessible.

**Décisions d'Alanc :**
- Galerie : deux composants de base, `StatusLabel` (icône + libellé, pour l'indicateur connecté / resynchronisation / hors ligne de 1.6) et `SectionCard` (surface titrée, pour les listes de 1.4 et 1.7).
- Spec gardée entière malgré sa taille (~2 100 tokens).

**Never:**
- Couleur de marque, `ThemeExtension`, moteur de thèmes, sélecteur de thème, paquet de golden tests ou Widgetbook.
- Écrans de connexion, profils ou réseau (stories 1.4 à 1.7).
- Tokens typographiques sur mesure : la hiérarchie reste celle de Material 3 (`textTheme`), non finalisée (UX-DR4).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Dynamic Color | schémas clair/sombre fournis | le thème utilise ces schémas | N/A |
| Sans Dynamic Color | schémas `null` (API < 31) | palette de secours clair/sombre appliquée | N/A |
| Littéral hors tokens | `lib/features/x.dart` contient `Color(0xFF…)`, `EdgeInsets.all(8)` ou `Duration(milliseconds: 200)` | test rouge, fichier et ligne cités | N/A |
| Littéral autorisé | même contenu dans `lib/ui/tokens.dart` | test vert | N/A |

</frozen-after-approval>

## Code Map

- `lib/main.dart` -- graine 1.1 (`MainApp` + « Hello World! ») ; à brancher sur le thème et `content.dart`.
- `lib/ui/README.md` -- dossier existant, rôle « tokens, thème, composants, catalogue ».
- `test/architecture_imports_test.dart` -- modèle à suivre : fonction pure testée sur sources en mémoire, puis balayage de l'arborescence réelle avec `expect(d.existsSync(), isTrue)`.
- `pubspec.yaml` -- `dynamic_color: 2.1.0` déjà présent ; aucun nouveau paquet.
- `.github/workflows/ci.yml` -- exécute déjà `flutter analyze` et `flutter test` ; rien à changer.
- `_bmad-output/planning-artifacts/ux-designs/ux-Hermes Mobile-2026-10-20/DESIGN.md` -- rôles d'exécution ; `fallback: unresolved` (palette provisoire jusqu'à G4).

## Tasks & Acceptance

**Execution:**
- [x] `lib/ui/tokens.dart` -- classes `const` : `Spacing`, `Radii`, `Elevations`, `IconSizes`, `Motion` (durées) ; extension `ColorRoles on ColorScheme` (`canvas`, `content`, `emphasis`, `emphasisContent`) -- source unique.
- [x] `lib/ui/theme.dart` -- `ThemeData buildTheme(ColorScheme? dynamicScheme, Brightness)` : schéma dynamique sinon secours `ColorScheme.fromSeed(seed neutre, dynamicSchemeVariant: neutral)` ; `Motion` respecte `MediaQuery.disableAnimationsOf` -- thème central.
- [x] `lib/ui/content.dart` -- libellés (titre de l'app, sections et données fictives de la galerie, noms accessibles) -- UX-DR22.
- [x] `lib/ui/components/status_label.dart`, `lib/ui/components/section_card.dart` -- `StatusLabel(icon, label)` et `SectionCard(title, child)`, ne lisant que tokens, rôles et `textTheme` -- réutilisables.
- [x] `lib/ui/gallery.dart` + `lib/main_gallery.dart` -- chaque composant rendu en quatre variantes : clair, sombre, `TextScaler.linear(2.0)`, `disableAnimations: true` (surcharges `Theme` / `MediaQuery`) -- UX-DR23.
- [x] `lib/main.dart` -- `DynamicColorBuilder` → `buildTheme` clair/sombre, `ThemeMode.system`, libellé tiré de `content.dart`.
- [x] `test/visual_literals_test.dart` -- fonction `literalViolations(path, source)` testée sur la matrice, puis balayage de `lib/**` hors `lib/ui/tokens.dart` et `lib/ui/theme.dart` -- garde-fou.
- [x] `test/theme_test.dart` -- `buildTheme(null, …)` = secours ; `buildTheme(schéma, …)` = schéma fourni ; rôles mappés -- matrice.
- [x] `test/gallery_test.dart` -- pump de la galerie : chaque composant présent 4 fois, aucune exception à 200 % (débordement compris).

**Acceptance Criteria:**
- Given Android 12+ avec couleurs dynamiques, when l'app démarre en clair puis en sombre, then les composants prennent les couleurs du téléphone via les quatre rôles.
- Given une valeur de `Spacing` ou un rôle modifié dans `lib/ui`, when la galerie est relancée, then tous ses composants reflètent le changement.
- Given `fvm flutter run -t lib/main_gallery.dart`, when la galerie s'ouvre, then chaque composant s'affiche en clair, sombre, 200 % et mouvement réduit, avec des données fictives.
- Given `flutter build apk --release`, when on l'inspecte, then l'APK démarre sur `lib/main.dart` et la galerie n'y est pas.

## Implementation Notes

- **Écart (pont `material_ui`)** : avec Flutter 3.47.7, dynamic_color 2.1.0 renvoie des `ColorScheme` du paquet `material_ui` (Material découplé du SDK), type distinct de `package:flutter/material.dart`. L'app reste sur `flutter/material` (comme flutter_markdown_plus) ; `lib/ui/dynamic_color_bridge.dart` recopie chaque rôle non déprécié. `material_ui: 1.8.0`, déjà résolu en transitif, est déclaré en dépendance directe pour l'importer (aucune nouvelle résolution ; lockfile : `transitive` → `direct main`). À valider par Alanc.
- `motionDuration(context, d)` (theme.dart) applique `MediaQuery.disableAnimationsOf` ; `SectionCard` l'utilise via `AnimatedSize`.
- La galerie rend les trois états de `StatusLabel` (connecté, resynchronisation, hors ligne) dans chaque variante.
- Vérifié : `flutter analyze` sans problème, `flutter test` 26/26, `flutter build apk --release` (clé locale) produit ; libellés de la galerie absents de `libapp.so`.

## Spec Change Log

## Review Triage Log

| # | Source | Constat | Verdict | Preuve | Route |
|---|--------|---------|---------|--------|-------|
| 1 | blind, gap, edge | garde anti-littéraux : `SizedBox(height: 8)`, `width:`, `Color(<décimal>)` non détectés | medium | aucun motif `height`/`width`/`Color(\d` ; l'AC « un test empêche les littéraux » est contournable par la forme d'espacement la plus courante | patch |
| 2 | blind, gap, edge | `//` dans une chaîne masque la fin de ligne ; `/* */` non retiré | low | cas rare (URL + littéral sur la même ligne) ; le correctif demande un mini-lexeur | rejet |
| 3 | blind, gap, edge | arguments lus jusqu'à la première `)` | low | appel imbriqué suivi d'un littéral dans un `EdgeInsets` : rare ; il faudrait un appariement de parenthèses | rejet |
| 4 | blind, gap | test de galerie : surcharges sombre / 200 % / mouvement réduit jamais vérifiées | medium | retirer `textScaler` ou `disableAnimations` laisse le test vert (seuls libellés et nombres sont comptés) | patch |
| 5 | gap | `SectionCard` : durée de `AnimatedSize` sous mouvement réduit non testée | medium | seul `motionDuration` est testé isolément | patch |
| 6 | blind, gap | aucun test de `MainApp` (thème sombre, accueil) | medium | aucune référence à `MainApp` dans `test/` | patch |
| 7 | blind | carte de couleur `surface` sur fond `surface` | low | `cardTheme.color: scheme.canvas` = fond du `Scaffold` ; M3 utilise `surfaceContainerLow` par défaut ; retirer la surcharge suffit | patch |
| 8 | blind | `main_gallery.dart` convertit chaque schéma deux fois | low | correction directe | patch |
| 9 | blind | variantes non combinées (sombre + 200 %) | low | l'intent demande quatre variantes, pas leurs combinaisons | rejet |
| 10 | blind | icône de `StatusLabel` non mise à l'échelle du texte | low | comportement par défaut des icônes Material ; libellé lisible | rejet |
| 11 | blind, edge | `buildTheme` ignore `brightness` si un schéma dynamique est fourni | low | les appelants passent toujours un schéma de même luminosité | rejet |
| 12 | blind | tokens inutilisés (`Spacing.xl`, `Radii.lg`…) | false | échelle de tokens = livrable UX-DR1, consommée par 1.4–1.7 ; aucun préjudice nommé | rejet |
| 13 | blind | « Resynchronisation » = jargon | false | libellé d'état prévu par l'epic (`connecté`, `resynchronisation`, `hors ligne`) | rejet |
| 14 | blind | spec absente du diff | false | exclusion volontaire du diff de revue | rejet |
| 15 | blind | graine de secours provisoire non suivie | false | suivie par la story de l'epic 6 (validation G4, UX-DR3) | rejet |
| 16 | edge | littéraux hex/`1_000` dans les arguments | low | improbable pour des valeurs visuelles | rejet |
| 17 | edge | `motionDuration` hors `MediaQuery` lève une exception | false | composants toujours sous `MaterialApp` ; échec bruyant, non atteignable | rejet |
| 18 | edge | un seul des deux schémas dynamiques fourni | maybe-false | dynamic_color fournit les deux ou aucun sur Android ; à vérifier dans le code natif du plugin ; au plus low | rejet |
| 19 | edge | échelle système > 2 dans la variante 200 % | low | cas improbable dans une galerie de développement | rejet |
| 20 | edge | rôles dépréciés (`background`…) non recopiés | low | Flutter les dérive de `surface` ; aucun widget M3 ne les lit | rejet |
| 21 | edge | galerie jamais testée avec schémas dynamiques | low | `buildTheme` avec schéma est testé ; la galerie ne fait que transmettre | rejet |

## Design Notes

Secours : `ColorScheme.fromSeed(seedColor: <gris neutre>, brightness: …, dynamicSchemeVariant: DynamicSchemeVariant.neutral)` donne une palette sobre, sans couleur de marque, cohérente avec Material 3. Les valeurs sont provisoires jusqu'à G4.

Détection des littéraux (heuristique par regex, assumée) : `Color(0x`, `Colors.`, `EdgeInsets.*(<nombre>`, `BorderRadius.circular(<nombre>`, `Radius.circular(<nombre>`, `fontSize: <nombre>`, `elevation: <nombre>`, `size: <nombre>`, `Duration(… <nombre>`. `0` est toléré.

## Verification

**Commands:**
- `fvm flutter analyze` -- expected: aucun problème
- `fvm flutter test` -- expected: tous verts
- `fvm flutter build apk --release` -- expected: APK produit

**Manual checks (if no CLI):**
- Alanc lance la galerie sur son Pixel 8 Pro (`fvm flutter run -t lib/main_gallery.dart`) et bascule le mode sombre du téléphone : les couleurs suivent le fond d'écran.
