---
name: Hermes Mobile
description: Refonte visuelle unifiée (accueil, conversation, conversations d'un profil, réglages du profil).
status: implemented
updated: 2026-10-23
language: fr
supersedes: ../ux-Hermes Mobile-2026-10-20/DESIGN.md (partie visuelle ; le comportement des activités reste décrit là-bas)
mockup: https://claude.ai/artifact/Qrz7LYtymob1XV64c6yYZ1
sources:
  - sources/acceuil/code.html
  - sources/conversation/code.html
  - sources/conv-setting/code.html
  - mockups/
code:
  tokens: lib/ui/tokens.dart
  theme: lib/ui/theme.dart
  fonts: assets/fonts/ (Inter 400/500/600/700, OFL)
colors:
  light:
    background: '#F7F8FA'
    card: '#FFFFFF'
    bubble: '#EDEFF2'
    chip: '#EDEFF2'
    code: '#E3E6EA'
    line: '#E3E6EA'
    outline: '#C9CED6'
    ink: '#111418'
    muted: '#5B6470'
    error: '#C62828'
  dark:
    background: '#0E1013'
    card: '#171A1F'
    bubble: '#1C2026'
    chip: '#22262C'
    code: '#2A2F36'
    line: '#2A2F36'
    outline: '#3A4049'
    ink: '#EEF0F3'
    muted: '#9AA3AE'
    error: '#FF8A80'
  scrim: '#73080A0E'
  accents:
    indigo: '#4F57E8'
    blue: '#1D6FD1'
    violet: '#7152E8'
    teal: '#00796B'
    orange: '#C2410C'
    raspberry: '#C2306A'
  on-accent: '#FFFFFF'
typography:
  family: Inter
  wordmark: headlineSmall, 700
  screen-title: titleMedium, 600
  row-title: titleMedium, 600
  body: bodyMedium / bodyLarge, 400
  meta: labelMedium / bodySmall, muted
  section-label: labelMedium, 600, MAJUSCULES, muted
rounded:
  sm: 8
  md: 12
  lg: 16      # lignes surlignées, cartes internes
  xl: 24      # cartes de réglages
  bubble: 22  # bulles de message
  pill: 28    # saisie, feuille du bas (haut)
  full: stadium  # boutons, pastilles, capsules d'activité
spacing: [4, 8, 16, 24, 32]
sizes:
  header-button: 44
  avatar: { list: 52, header: 34, sheet: 44, welcome: 64, settings: 88 }
  send-button: 40
  composer-min-height: 52
  swatch: { target: 56, dot: 30, ring: 3 }
  bubble-max-width: 85%
  sheet-max-height: 85%
theme:
  mode: system
  variants: [light, dark]
  dynamic-colors: false
---

# Hermes Mobile : design

Ce dossier décrit le design en place depuis la refonte du 23 octobre 2026. Pour faire évoluer un écran, partir d'ici (voir « Faire évoluer » en bas).

| Dossier | Contenu |
|---|---|
| `sources/` | Les trois ébauches d'origine fournies par Alanc (accueil, conversation, réglages). |
| `mockups/` | Maquette harmonisée validée (fichiers du canevas, lien `mockup` ci-dessus). |
| `captures/` | Rendu réel de l'app Flutter, clair et sombre (`test/support/grok_capture.dart`). |
| `imports/` | Références Grok d'une étape précédente, pour mémoire. |

## Direction

Les trois ébauches avaient chacune leur style : accueil blanc et SF Pro avec avatars orange, conversation gris froid en Inter, réglages crème et brun en Be Vietnam Pro. La refonte garde la forme de chaque écran et applique partout un seul langage :

1. **Une police, Inter**, embarquée dans l'app.
2. **Des neutres gris-bleu** repris de l'ébauche conversation : fond très clair, cartes blanches, encre quasi noire. En sombre, tout s'inverse, sans teinte crème.
3. **Une seule couleur vive : celle du profil.** Elle se retrouve partout où le profil apparaît : avatar, pastille d'en-tête, bouton d'envoi, coche des activités terminées, icônes et pastilles des réglages, conversation en cours dans la liste. Les bulles restent neutres.
4. **Les mêmes formes partout :**
   - boutons ronds de 44 px sur fond `chip` ;
   - capsules (stadium) pour les pastilles et les activités ;
   - bulles de 22 px ;
   - cartes de 24 px avec un filet `line`.

## Mouvement

- **Arrivée des éléments :** les nouveaux éléments du fil (messages, activités) arrivent en fondu avec un léger glissement vers le haut (`Appear`, 300 ms, easeOutCubic). Le fil déjà présent à l'ouverture ne s'anime pas.
- **Indicateur de travail :** la bulle « Hermes travaille » apparaît et disparaît en fondu, et disparaît dès que la réponse commence à s'écrire.
- **Pages :** transition en fondu glissé (`FadeForwardsPageTransitionsBuilder`).
- **Mouvement réduit :** tout devient immédiat.

## Couleur du profil

- 6 couleurs : indigo, bleu, violet, sarcelle, orange, framboise. Chacune garde un contraste d'au moins 4,5:1 avec le blanc.
- **Par défaut :** une couleur stable tirée de l'identifiant du profil (`ProfileAccent.defaultFor`).
- **Choix :** dans Réglages du profil, puis Apparence. Le choix est enregistré sur le téléphone, par serveur, connexion et profil (table SQLite `profile_accents`, migration 9).
- **Dans le code :** `AccentScope` place la couleur dans `colorScheme.secondary`, et les composants la lisent avec `scheme.accent`.

## Nom du profil

Le nom affiché est toujours celui du profil Hermes : son `display_name`, sinon son identifiant (`lib/data/hermes_adapter.dart`). L'app ne permet jamais de le renommer. Les réglages l'indiquent par « Nom repris du profil Hermes ».

## Composants

| Composant | Rendu | Code |
|---|---|---|
| Avatar de profil | Disque à la couleur du profil, initiale blanche en 600. Décoratif : le nom est toujours écrit à côté. | `ui/components/profile_avatar.dart` |
| Bouton d'en-tête | `IconButton.filledTonal`, 44 px, fond `chip`, icône encre, avec une infobulle. | thème `iconButtonTheme` |
| Pastille du profil | Capsule `card` avec filet `line` : avatar 34 px, nom, chevron. Elle ouvre les conversations du profil. Le profil est annoncé (région live). | `draft_view.dart` `_profilePill` |
| Bulle de Hermes | Fond `bubble`, 22 px, Markdown, 85 % de la largeur au maximum. | `message_bubble.dart` |
| Bulle d'Alanc | Fond encre (`primary`), texte inversé, 22 px, alignée à droite. | `message_bubble.dart` |
| Capsule d'activité | Capsule `card` avec filet : dessin de la famille, puis libellé en 600 ; une fois terminée, coche à la couleur du profil et « Fin reçue ». Elle sert quand l'appel n'a ni détail ni résumé. | `activity_line.dart` |
| Carte d'outil | Carte `card` avec filet, arrondie à 16 px. Elle contient le dessin, le nom de l'outil (commande, lecture de fichier, recherche web…) et son état. En dessous, l'appel en chasse fixe (`$ commande`, chemin, requête). Elle se déplie sur les détails (nom, arguments, sortie, diff) en blocs de code. | `activity_line.dart`, `activity_details.dart` |
| Groupe d'actions | Capsule `card` avec filet « N actions terminées » ou « N actions · M en cours », qui replie ou déplie les cartes. | `activity_group.dart` |
| Hermes travaille | Bulle `bubble` avec les trois points animés (illustration `unknown`) et le texte d'état. Pour un échec, un arrêt ou un état inconnu : icône et libellé. | `work_state_label.dart` |
| Saisie | Pilule `card` avec filet, 52 px minimum. Indication « Écrire à <profil> ». Bouton d'envoi rond de 40 px à la couleur du profil, gris (`chip`) s'il est désactivé. | `composer.dart` |
| Feuille du bas | Fond `card`, haut arrondi à 28 px, poignée `line`, voile `scrim`, 85 % de la hauteur au maximum. | thème `bottomSheetTheme`, `routes.dart` `_SheetPage` |
| Carte de réglages | `Card` (24 px, filet) avec un intertitre en majuscules `muted` et son icône à la couleur du profil. | `profile_settings_view.dart` `_Section` |
| Pastille de couleur | Cible de 56 px, disque de 30 px ; une fois choisie, anneau de la couleur et coche blanche. Annoncée comme bouton sélectionné dans un groupe exclusif. | `profile_settings_view.dart` `_Swatch` |

## Écrans et navigation

```
Accueil ──(profil)──▶ Conversation ──(pastille du nom)──▶ Conversations du profil (feuille)
   │                      │  ◀──(flèche) Accueil                │
   │                      └──(+)──▶ Nouvelle conversation       ├──(ligne)──▶ cette conversation
   │                                                            ├──(Nouvelle conversation)
   └──(réglages)──▶ Mes profils  ◀──(Tous les profils)──  Réglages du profil ◀──(réglages)──┘
```

- **Accueil** (`/`, `home_view.dart`)
  - En-tête : « Hermes » et un bouton réglages, qui ouvre « Mes profils ».
  - Une ligne par profil : avatar 52 px, nom, dernière conversation, heure.
  - Toucher un profil rouvre sa dernière conversation, ou en démarre une s'il n'en a pas.
- **Conversation** (`/draft/…`, `/c/…`, `draft_view.dart`)
  - En-tête : flèche retour vers l'accueil, pastille du profil, « + » pour une nouvelle conversation (sur une conversation existante), filet sous l'en-tête.
  - Une conversation neuve affiche l'avatar 64 px, « Comment puis-je t'aider ? » et des suggestions.
  - On ne change pas de profil depuis une conversation : le choix se fait sur l'accueil.
- **Conversations du profil** (`/history/<profil>?current=<session>`, feuille du bas, `history_view.dart`)
  - En-tête : avatar 44 px, nom, nombre de conversations, actualiser, réglages du profil.
  - Bouton « Nouvelle conversation » en encre, sur toute la largeur.
  - Liste groupée par date ; la conversation ouverte est teintée de la couleur du profil.
- **Réglages du profil** (`/profile/<profil>`, `profile_settings_view.dart`)
  - Carte d'en-tête : avatar 88 px, nom, « Nom repris du profil Hermes ».
  - Apparence : couleur du profil.
  - Profil : identifiant, connexion (bouton « Changer »), « Tous les profils ».
  - Volontairement absents : nouvelle conversation et historique, déjà accessibles depuis la pastille du nom.
- **Mes profils** (`/profiles`) et **Connexion** : mêmes écrans qu'avant, habillés par le thème.

## Hors périmètre (retiré des ébauches)

Ces fonctions sont retirées parce que le serveur Hermes ne les fournit pas. Elles reviendront avec la fonction correspondante :
- pièces jointes (« + ») et micro ;
- fichiers et médias ;
- sons et alertes ;
- mémoire et instructions ;
- effacer ou bloquer l'agent ;
- favoris et recherche de l'accueil.

**Otc** (le lapin) est retiré de la conversation et de « Mes profils » le temps de sa refonte :
- son code est conservé (`rabbit_companion.dart`, `conversation_companion.dart`, l'éditeur d'arrière-plan) ;
- il est toujours visible dans la galerie de composants ;
- ses tests d'intégration sont en pause (`skip: otcRemoved`) et reviendront avec lui.

## Événements de Hermes

- **Outils reconnus :** la famille d'un outil vient de son nom (`ActivityKind.forTool`). Par exemple, `terminal` devient une commande, `read_file` une lecture, `web_search` une recherche, `browser_*` une navigation, etc. Un nom inconnu reste « Utilisation d'un outil ».
- **Signaux masqués :** les signaux internes que l'app ne connaît pas ne sont plus affichés dans le fil (usage des tokens, raisonnement, notifications…). Avant, ils s'affichaient en « Événement non reconnu », parfois deux fois par réponse.

## Accessibilité (inchangée)

- Cibles tactiles d'au moins 44 px.
- Contraste du texte d'au moins 4,5:1, y compris le blanc sur les couleurs de profil.
- Texte à 200 %.
- Mouvement réduit respecté : les trois points sont immobiles.
- Aucune information portée par la seule couleur : coche doublée de « Fin reçue », profil sélectionné nommé.
- Les valeurs visuelles ne vivent que dans `tokens.dart` et `theme.dart`, ce que vérifie `test/visual_literals_test.dart`.

## Faire évoluer

1. Modifier ou ajouter l'écran dans la maquette (lien `mockup`) ou en HTML dans `sources/`.
2. Reporter ici les valeurs qui changent (en-tête YAML et tableaux).
3. Les reporter dans `lib/ui/tokens.dart` (et dans `theme.dart` pour les rôles Material), jamais dans un composant.
4. Régénérer les captures avec `flutter test test/support/grok_capture.dart --dart-define=OUT=<dossier>`, puis les copier dans `captures/`.
5. Noter la décision dans le journal ci-dessous.

## Journal

- **23/10/2026 :**
  - Refonte unifiée validée sur maquette puis intégrée dans l'app.
  - Feuille « Conversations du profil » ouverte depuis la pastille du nom.
  - Nom des profils repris de Hermes, jamais modifiable dans l'app.
  - Nouvelle conversation et historique retirés des réglages du profil, car déjà accessibles ailleurs.
  - Otc mis en pause.
  - Le lancement ouvre l'accueil, même pendant le chargement des profils.
  - Signaux internes masqués, outils nommés par famille, cartes d'outils, animations d'arrivée.
