---
title: 'Story 3.3 — Reconnaître l’activité grâce aux illustrations animées'
type: 'feature'
created: '2026-10-22'
status: 'done'
baseline_commit: 'a14b8293c68f5b5392c1603f1357080b5ac834c0'
route: 'dispatch'
review_loop_iteration: 0
context:
  - 'C:/Users/alanc/.codex/RTK.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/investigation-epic-3-activites.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `ActivityLine` affiche encore des icônes Material statiques (`Icons.build_outlined` / `Icons.circle_outlined`) dans le slot de 24 px et ne dispose d’aucun catalogue de présentation indexé par `ActivityKind` avec paramètres de mouvement centralisés, variantes immobiles et suspension hors écran/arrière-plan.

**Approach:** Introduire un catalogue de présentation déclaratif indexé exclusivement par `ActivityKind` (avec repli générique), associé à un composant `ActivityIllustration` peint dans le slot de 24 × 24 px, piloté par les tokens de mouvement et suspendu sous mouvement réduit, pause, hors écran ou arrière-plan, sans jamais modifier le décodage serveur ni les contrats Otc.

## Boundaries & Constraints

**Always:**
- Indexer le catalogue exclusivement par `ActivityKind`, avec une entrée de repli générique ; chaque entrée définit son rendu vectoriel, ses paramètres de mouvement issus de `lib/ui/tokens.dart` et sa variante immobile.
- Conserver tous les littéraux visuels (dimensions, épaisseurs de trait, durées, courbes/amplitudes) dans `lib/ui/tokens.dart` (`test/visual_literals_test.dart`) et les libellés dans `lib/ui/content.dart`.
- Pour l’illustration « code » (`UX-DR14`), garder le châssis de l’ordinateur strictement fixe avec des traits épais ; seuls les lignes de code et le curseur s’animent en mode actif et s’affichent en variante immobile sinon.
- Arrêter/immobiliser immédiatement toute animation (`transientCallbackCount == 0` hors cycle actif) lorsque le mouvement réduit système est activé (`MediaQuery.disableAnimationsOf`), que la surface est en pause ou inactive (`TickerMode`, route non courante), que la ligne est hors écran (viewport/Offstage) ou que l’application passe en arrière-plan (`AppLifecycleState`).
- Utiliser un rythme de cycle compatible avec `pumpAndSettle` (pause par `Timer` entre deux cycles `AnimationController.forward`, annulée dès suspension) sur le modèle éprouvé de `RabbitCompanion`, pour ne bloquer aucun test d’intégration existant.
- Préserver intégralement les 4 lots approuvés d’Otc (`RabbitCompanion`, `ConversationCompanion`, carré 64 px, regards, chatouilles, fonds), `WorkStateLabel` (région live unique hors liste paresseuse), ainsi que les identités, groupes repliables et détails dépliables de 3.1 et 3.2 (y compris le maintien du focus via `_activityKeys`).
- Remplacer une entrée du catalogue ne doit modifier que le catalogue, sans toucher au décodage des événements (`EventMapping`) ni aux appels Hermes.

**Never:**
- Indexer ou choisir une illustration par emoji, nom d’outil MCP, sous-chaîne de `details['name']`, argument ou minuterie.
- Modifier l’état du travail (`WorkState`), `CompanionPhase` ou `completed` depuis une animation ou sa fin de cycle.
- Réaliser le catalogue complet des 17 familles (réservé à la Story 3.4) ou la commande d’arrêt (réservée à la Story 3.5).
- Déclencher un appel réseau ou une écriture de persistance depuis `ActivityLine`, le catalogue ou la galerie.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Catalogue par `ActivityKind` | `ActivityKind` connu (`tool`, `code`, `unknown`) | Illustration correspondante rendue dans le slot 24 × 24 px avec ses tokens de mouvement | Si entrée absente d’une table personnalisée, repli sur l’entrée générique `unknown` sans erreur |
| Isolation des détails bruts | `ActivityKind.tool` avec `details['name'] = 'write_file'` ou emoji | Rendu strictement déterminé par `ActivityKind.tool` ; aucune inférence sur `details` | Aucun changement de famille hors mapping serveur |
| Illustration « code » (`UX-DR14`) | `ActivityKind.code` animé vs immobile | Châssis d’ordinateur fixe aux traits épais ; lignes et curseur animés en cours, fixes en variante immobile | Aucun mouvement du châssis (`illustration-body` fixe) |
| Mouvement réduit / Pause / Fin | `disableAnimations: true`, `paused: true` ou `completed: true` (selon arbitrage) | Variante immobile immédiate, aucun `Timer` ni `AnimationController` actif | Changement dynamique en cours de cycle → arrêt immédiat sans frame résiduelle |
| Hors écran / Arrière-plan / Route masquée | Ligne défilée hors du viewport, `Offstage`, route couverte ou `AppLifecycleState.paused` | Suspension immédiate des cycles et timers ; reprise propre au retour visible | Aucun ticker orphelin ni fuite mémoire au `dispose` |
| Remplacement d’entrée de catalogue | Injection/remplacement d’une entrée dans `ActivityCatalog` | Le nouveau visuel s’affiche sans modifier `EventMapping`, `ConversationRepository` ni `HermesRpc` | Test de non-régression dédié |
| Ancienne projection / valeur inconnue | JSON persisté avec `kind` inconnu ou version ancienne | `ActivityKind.decode` replie sur `ActivityKind.unknown` ; illustration générique rendue | Aucune exception de désérialisation |

## Décisions UX approuvées

Alanc : « Fait tout ce que tu recommandes » (Options A retenues sur les 3 arbitrages).

1. **Conciliation `UX-DR13` / lot 4 Otc :** Aucune ligne « Préparation de réponse » n’est réintroduite dans le fil de conversation — Otc seul porte la préparation de réponse au niveau du tour conformément au lot 4. Le motif des trois petits points en rotation (dans le slot 24 × 24 px, sans bulle, immobile en variante fixe) sert d’illustration pour une ligne d’activité `ActivityKind.unknown` et de repli générique du catalogue.
2. **Catalogue dès 3.3 (`code`, `tool`, `unknown`) :** `ActivityKind` expose `tool`, `code` et `unknown` (sans inventer de règle de mapping serveur non vérifiée : `tool.start`/`tool.complete` restent `tool` dans `contracts/event-mapping.json`). Le catalogue fournit 3 illustrations distinctes : `code` (ordinateur au châssis fixe aux traits épais, lignes et curseur animés, `UX-DR14`), `tool` (appel d’outil animé : machine/clé et impulsion) et `unknown` / repli générique (trois petits points en rotation 24 × 24 px), toutes présentées dans la galerie en clair, sombre, texte 200 % et mouvement réduit.
3. **Fin d’action et pause de la page :** Toute ligne d’activité avec `completed: true` (« Fin reçue ») ou lorsque la pause de la page (`_companionPaused` de `DraftView`) est active affiche immédiatement la variante immobile de son illustration, sans timer ni cycle actif.

</frozen-after-approval>

## Code Map

- `lib/models/timeline.dart` -- `ActivityKind` (`tool`, `code`, `unknown`) et `ActivityKind.decode` ; conserver la compatibilité ascendante (`fromJson`/`toJson`) et l’immuabilité de `ActivityItem`.
- `contracts/event-mapping.json` & `lib/data/event_mapping.dart` -- Ne pas inventer de mapping par nom d’outil ou emoji ; `tool.start`/`tool.complete` restent `tool`, `unknown` reste `unknown`.
- `lib/ui/tokens.dart` -- Étendre `ActivityTokens` avec les constantes géométriques, épaisseurs de trait (`strokeWidth`), rayons et durées de cycle/repos des illustrations d’activité (aucun littéral visuel hors `tokens.dart`).
- `lib/ui/content.dart` -- Ajouter le libellé d’activité `code` (`Content.activityCode` / `Content.activityLabel(ActivityKind)`) et les libellés de galerie nécessaires, en conservant `Content.activityTool` et `Content.activityUnknown`.
- `lib/ui/components/activity_catalog.dart` (nouveau) -- Catalogue déclaratif `ActivityCatalog` indexé par `ActivityKind` avec fallback générique (`unknown`), paramètres de mouvement issus de `ActivityTokens`, peintres vectoriels (`CustomPainter`) à variante animée (`progress`) et variante immobile (`stationary: true`), plus `ActivityIllustration` gérant cycle, mouvement réduit, `paused`, `completed`, visibilité viewport/Offstage et cycle de vie app (en réutilisant le patron de visibilité de `rabbit_companion.dart`).
- `lib/ui/components/activity_line.dart` -- Remplacer `Icon(Icons.build_outlined / Icons.circle_outlined)` dans le `SizedBox(width: ActivityTokens.illustration, height: ActivityTokens.illustration)` par l’illustration issue de `ActivityCatalog`, recevoir `paused` et `catalog` (optionnel pour test de remplacement), sans changer la sémantique accessible, le repère « Fin reçue », le bouton 48 px ni `ActivityDetails`.
- `lib/features/conversation/draft_view.dart` -- Transmettre `paused: _companionPaused` aux `ActivityLine` sans modifier `_activityKeys`, `_activityExpansion`, `_detailExpansion`, `ConversationCompanion` ni `WorkStateLabel`.
- `lib/ui/gallery.dart` -- Mettre à jour `ActivityPreview` (ou la section activité) pour présenter chaque illustration du catalogue (`code`, `tool`, `unknown`) dans les 4 variantes (`Clair`, `Sombre`, `Texte agrandi 200 %`, `Mouvement réduit`) et permettre de tester la pause et la fin d’action.

## Tasks & Acceptance

**Execution:**
- [x] `lib/models/timeline.dart`, `lib/ui/content.dart`, `lib/ui/tokens.dart` -- Ajouter `ActivityKind.code` (avec décodage compatible replié sur `unknown`), centraliser le libellé par `ActivityKind` dans `Content` et définir dans `ActivityTokens` les géométries, traits épais et durées de cycle/repos des illustrations -- préparer le socle typé et les tokens sans littéral visuel dispersé.
- [x] `lib/ui/components/activity_catalog.dart` (nouveau) -- Implémenter `ActivityCatalog` (indexé par `ActivityKind` avec repli générique `unknown`, remplaçable pour test), les peintres vectoriels (`code` à châssis d’ordinateur fixe + lignes/curseur mobiles, `tool` appel d’outil, `unknown` trois points en rotation 24 × 24 px) avec variante immobile, et le widget `ActivityIllustration` suspendant ses cycles/timers sous mouvement réduit, `paused`, `completed`, hors écran, `Offstage`, route non courante et arrière-plan -- fournir les illustrations animées et leur suspension conformément à `UX-DR12`–`UX-DR15`.
- [x] `lib/ui/components/activity_line.dart`, `lib/features/conversation/draft_view.dart` -- Brancher `ActivityCatalog` dans le slot 24 × 24 px de `ActivityLine`, propager `paused` depuis `DraftView`, et préserver l’exclusion sémantique du dessin (`ExcludeSemantics` / conteneur sémantique existant), le repère « Fin reçue », les détails dépliables et le focus -- intégrer les illustrations dans la conversation sans régression 3.1/3.2 ni Otc.
- [x] `lib/ui/gallery.dart`, `test/activity_line_test.dart`, `test/gallery_test.dart`, `test/conversation_test.dart` -- Exposer chaque illustration du catalogue dans la galerie (clair, sombre, 200 %, mouvement réduit) et couvrir par tests unitaires/widgets toute la matrice : indexation stricte par `ActivityKind` (jamais par `details['name']`/emoji), châssis fixe de `code` et rotation de `unknown`, suspension (mouvement réduit, pause, fin, hors écran, arrière-plan), remplacement d’une entrée du catalogue sans toucher à `EventMapping`/`HermesRpc`, et captures visuelles -- prouver tous les critères d’acceptation et la non-régression.
- [x] `_bmad-output/planning-artifacts/ux-designs/ux-Hermes Mobile-2026-10-20/` et `ux-Hermes Mobile-2026-10-22/` -- Consigner les décisions UX approuvées de la Story 3.3 et déposer le rapport de vérification sous `_bmad-output/implementation-artifacts/story-3-3-verification/` -- maintenir la traçabilité documentaire de l’Epic 3.

**Acceptance Criteria:**
- Given le catalogue de présentation indexé par `ActivityKind`, when une activité (`tool`, `code`, `unknown`) est affichée dans `ActivityLine`, then son illustration 24 × 24 px provient du catalogue avec ses paramètres de mouvement issus de `ActivityTokens`, sa variante immobile et le repli générique, sans jamais lire un emoji, un nom d’outil MCP ou une minuterie pour choisir la famille.
- Given l’activité `code`, when elle est animée, then le châssis de l’ordinateur reste strictement fixe avec des traits épais et seuls les lignes de code et le curseur bougent ; given une activité `unknown`, when elle est animée, then trois petits points tournent dans le slot 24 × 24 px sans bulle ni grand dessin, tandis qu’Otc reste seul porteur de la préparation de réponse du tour.
- Given le mouvement réduit activé, la pause de la page, une action terminée (`completed: true`), une ligne hors écran ou l’application en arrière-plan, when l’illustration est rendue, then elle affiche sa variante immobile sans timer ni animation active et aucune animation ne modifie `WorkState` ni ne décide qu’un outil est terminé.
- Given un remplacement d’entrée dans `ActivityCatalog`, when l’activité est affichée, then seul le catalogue change sans modification de `EventMapping`, `ConversationRepository` ou `HermesRpc`, et la galerie présente chaque illustration en clair, sombre, texte 200 % et mouvement réduit.

## Implementation Notes

- `ActivityCatalog` (`lib/ui/components/activity_catalog.dart`) associe exclusivement chaque `ActivityKind` (`tool`, `code`, `unknown`) à une `ActivityCatalogEntry` (durées `cycle` / `rest` issues de `ActivityTokens` et constructeur de `CustomPainter` avec paramètres `progress` et `stationary`), avec repli automatique sur `unknownEntry`.
- `CodeActivityPainter` dessine un châssis d'ordinateur fixe (`ActivityTokens.codeMonitor`, pied et base aux traits épais `ActivityTokens.strokeWidth`) et anime uniquement les trois lignes de code et le curseur vertical (`UX-DR14`).
- `ToolActivityPainter` dessine un boîtier machine aux traits épais, une clé oscillante autour de `ActivityTokens.toolPivot` et une impulsion de signal.
- `UnknownActivityPainter` dessine trois petits points en rotation dans le slot 24 × 24 px sans bulle ni grand dessin (`UX-DR13`), immobiles en variante fixe, tandis qu'Otc reste seul porteur de la préparation de réponse du tour (lot 4).
- `ActivityIllustration` utilise un rythme de cycle espacé de `ActivityTokens.rest` (600 ms, compatible `pumpAndSettle`) et un `RenderProxyBox` d'observation de composition (`_ActivityPaintVisibility`) couplé aux `ScrollPosition` ancêtres, `Offstage`, `TickerMode`, `ModalRoute`, `AppLifecycleState`, `MediaQuery.disableAnimationsOf`, `paused` et `completed` pour annuler immédiatement tout timer et `AnimationController` hors cycle actif (`transientCallbackCount == 0`).

### Audit de couverture de la matrice I/O & Edge-Case

| Scenario | Couvert par |
|----------|-------------|
| Catalogue par `ActivityKind` (`tool`, `code`, `unknown` + repli) | `test/activity_line_test.dart` (`catalogue par ActivityKind : repli générique et isolation de details[name] / emoji`), `test/gallery_test.dart` |
| Isolation des détails bruts (`details['name'] = 'write_file 💻'`) | `test/activity_line_test.dart` (`catalogue par ActivityKind...`), `test/conversation_test.dart` (`DraftView : pause de la page...`) |
| Illustration « code » (`UX-DR14`), « tool » & « unknown » (`UX-DR13`) | `test/activity_line_test.dart` (`illustration code (UX-DR14), tool et unknown : châssis fixe aux traits épais, lignes/curseur mobiles, clé/signal mobiles et 3 points en rotation`) |
| Mouvement réduit / Pause / Fin (`completed: true`) / Resynchronisation | `test/activity_line_test.dart` (`suspension immédiate...`), `test/gallery_test.dart` (`activité : ajout code, pause/reprise...`), `test/conversation_test.dart` (`DraftView : pause de la page...`) |
| Hors écran / Arrière-plan / Route masquée / `Offstage` | `test/activity_line_test.dart` (`suspension immédiate : mouvement réduit, pause, completed, Offstage, hors viewport et arrière-plan`) |
| Remplacement d'entrée de catalogue sans toucher `EventMapping`/`HermesRpc` | `test/activity_line_test.dart` (`remplacement d’une entrée dans ActivityCatalog sans toucher au décodage ni au transport`) |
| Ancienne projection / valeur inconnue | `test/activity_line_test.dart` (`ActivityKind.decode`), `test/conversation_test.dart` |

## Spec Change Log

## Review Triage Log

| Source | Finding | Verdict | Evidence & Routing |
|--------|---------|---------|-------------------|
| `edge-case-hunter` | Aucun défaut d'edge case signalé (`[]`) | `false` | Aucune anomalie soulevée après traçage complet du diff et des consommateurs. |
| `blind-hunter` #1 | `RepaintBoundary` redondant sous `_ActivityPaintVisibility` (`isRepaintBoundary => true`) dans `lib/ui/components/activity_catalog.dart` | `low` | Le patron `_ActivityPaintVisibility` suit `_PaintVisibility` de `rabbit_companion.dart` (callbacks de composition groupés par `_visibilityQueued`), mais le widget `RepaintBoundary` interne créait une seconde couche `OffsetLayer` inutile par ligne. Corrigé (`patch`) en supprimant le `RepaintBoundary` redondant. |
| `blind-hunter` #2 | `didChangeAppLifecycleState` appelle `setState(_sync)` même si `_foreground` ne change pas dans `lib/ui/components/activity_catalog.dart` | `low` | Les transitions `inactive -> hidden -> paused` déclenchaient un `setState` sans changement de `_foreground`. Corrigé (`patch`) par garde `if (_foreground == foreground) return;`. |
| `blind-hunter` #3 | Intervalles de progression des lignes (`0.0..0.35`, `0.25..0.65`, `0.55..0.9`) décalés des seuils du curseur (`0.3`, `0.6`) dans `CodeActivityPainter` | `low` | Le curseur passait à la ligne suivante légèrement avant la fin de l'extension de la ligne courante. Corrigé (`patch`) en alignant les seuils via `ActivityTokens.codeLine1End`, `codeLine2End`, `codeLine3End`. |
| `blind-hunter` #4 | Longueurs de lignes différentes entre `progress == 1.0` et `stationary == true` dans `CodeActivityPainter` | `low` | À la fin d'un cycle, le passage à `stationary == true` réduisait les 3 lignes de `1.5..2.0` unités. Corrigé (`patch`) en utilisant `codeLine1MaxWidth`, `codeLine2MaxWidth`, `codeLine3MaxWidth` en mode fixe et en fin de cycle. |
| `blind-hunter` #5 | `toolShaftEnd` (`24.5`) dépasse dans `toolJawArc` (`22.5`) et constantes de fraction d'arc / seuils de keyframes locales aux peintres | `low` | `toolShaftEnd` dépassait de 2 unités dans l'ouverture de la mâchoire et les facteurs `0.35` / `1.3` étaient codés en dur dans `ToolActivityPainter`. Corrigé (`patch`) en réglant `toolShaftEnd` à `Offset(22.5, 16)` et en déplaçant `toolJawStartFactor`, `toolJawSweepFactor` et `codeLine*End` dans `ActivityTokens`. |
| `blind-hunter` #6 | `ExcludeSemantics` englobait les libellés du catalogue de `ActivityPreview` dans `lib/ui/gallery.dart` alors que `ActivityIllustration` seul est décoratif | `low` | Déplacer `ExcludeSemantics` à l'intérieur de `ActivityIllustration.build` et utiliser `GalleryContent.activityCatalogItem(kind)` dans `lib/ui/gallery.dart` expose les libellés du catalogue à l'accessibilité tout en excluant le `CustomPaint` décoratif. Corrigé (`patch`). |
| `blind-hunter` #7 | Question sur l'immobilisation d'actions sans fin confirmée lors de la fin d'un tour dans `DraftView` | `false` | La Décision UX 3 approuvée et la Story 3.1 stipulent explicitement qu'une fin de tour ne marque jamais une action sans `tool.complete` comme terminée (`completed` reste `false`) et que l'immobilisation dépend de `completed: true` ou de la pause de la page (`_companionPaused || vm.resyncing`). |
| `blind-hunter` #8 & `verification-gap` #1 | `ToolActivityPainter` (`wrenchAngle`, `signalX`) non vérifié pendant un cycle d'animation actif dans `test/activity_line_test.dart` | `medium` | Le test de cycle d'animation ne montait que `code` et `unknown`. Corrigé (`patch`) en montant aussi `ActivityKind.tool` dans `test/activity_line_test.dart` et en vérifiant `stationary`, `wrenchAngle` et `signalX` avant, pendant et après `ActivityTokens.cycle`. |
| `blind-hunter` #9 & `verification-gap` #3 | Contrôles `GalleryContent.activityCode` et `GalleryContent.pauseActivities` / `resumeActivities` non exercés dans les tests | `medium` | Aucun test n'actionnait ces deux nouveaux boutons de `ActivityPreview`. Corrigé (`patch`) dans `test/gallery_test.dart` et `test/activity_line_test.dart` (y compris la désactivation de `activityCode` après réponse). |
| `blind-hunter` #10 & `verification-gap` #2 | Transition active -> pause et `vm.resyncing` dans `DraftView` (`test/conversation_test.dart`) + chemin de captures 3.1 dans `test/activity_line_test.dart` | `medium` | Dans `test/conversation_test.dart`, la pause était déclenchée avant la fin de `ActivityTokens.rest` et `resyncingKeys` n'était pas testé avec une `ActivityLine`. Corrigé (`patch`) en avançant dans un cycle actif avant pause, en testant `memory.resyncingKeys.add(k)` et en écrivant les captures dans `story-3-1-verification/captures` et `story-3-3-verification/captures`. |
| `blind-hunter` #11 | Helper `Content.activity(bool tool)` inutilisé et doublon de libellé `GalleryContent.activityCode` dans `lib/ui/content.dart` | `low` | `Content.activity(bool)` n'avait plus d'appelant après `Content.activityLabel(ActivityKind)`. Corrigé (`patch`) en supprimant `Content.activity` et en distinguant `GalleryContent.activityCode` (`'Ajouter code'`). |

## Verification

**Commands:**
- `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat analyze --no-pub` -- expected: `No issues found!`
- `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat test` -- expected: tous les tests passent, y compris `visual_literals_test.dart`, `activity_line_test.dart`, `gallery_test.dart`, `conversation_test.dart` et `action_details_page_test.dart`
- `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat build apk --debug -t lib/main.dart` et `-t lib/main_gallery.dart` -- expected: builds APK debug application et galerie réussis
