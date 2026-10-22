---
name: Hermes Mobile — compagnon lapin
description: Complément visuel consacré au compagnon commun aux profils Hermes.
status: final
approval-status: planche-v5-validee-animations-a-concevoir
approved-reference: mockups/planche-lapin-v5-proportions.png
updated: 2026-10-22
language: fr
scope: conception uniquement
sources:
  - .memlog.md
  - ../../../brainstorming/brainstorm-compagnon-lapin-hermes-2026-10-22/.memlog.md
  - ../ux-Hermes Mobile-2026-10-20/DESIGN.md
  - ../ux-Hermes Mobile-2026-10-20/EXPERIENCE.md
  - imports/lapin-reference.png
  - https://github.com/ngocdevv/grok-bot-emoji/tree/c4b9859d5fda157fce28ee729dbeaca1bce1668c
token-status: Direction blanc/noir validée sur v5 ; gris intérieur, pastels et dimensions numériques restent des réglages proposés.
colors:
  rabbit-coat: '#FFFFFF'
  rabbit-ear-inner: '#D9D9D9'
  rabbit-face: '#000000'
  pastel-lavender: '#E6DFF5'
  pastel-peach: '#F5DFD3'
  glass-veil: '#FFFFFF'
typography:
  companion-name:
    note: Hériter de ThemeData.textTheme.titleMedium ; aucun changement de police.
  companion-status:
    note: Hériter du rôle de texte de WorkStateLabel ; texte agrandi système conservé.
rounded:
  sm: 8px
  md: 12px
  lg: 16px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
components:
  companion:
    coat: '{colors.rabbit-coat}'
    ear-inner: '{colors.rabbit-ear-inner}'
    face: '{colors.rabbit-face}'
    profile-size: 180px
    compact-size: 64px
    compact-minimum: 48px
    touch-minimum: 48px
  companion-backdrop:
    start: '{colors.pastel-lavender}'
    end: '{colors.pastel-peach}'
    veil: '{colors.glass-veil}'
    radius: '{rounded.lg}'
  companion-name:
    typography: '{typography.companion-name.note}'
  work-status:
    typography: '{typography.companion-status.note}'
  backdrop-editor:
    gap: '{spacing.md}'
    radius: '{rounded.md}'
---

# Hermes Mobile — Design du compagnon

## Brand & Style

**Validation Alanc : planche v5 approuvée comme première référence visuelle.** Le [dessin validé](mockups/planche-lapin-v5-proportions.png) fixe le compagnon blanc aux traits noirs, les yeux discrets proportionnés, la bouche graphique lisse et les oreilles légèrement raccourcies, sans pli, asymétriques par leur inclinaison. Cette validation remplace les mentions historiques « à valider » du dessin v5 et les directions taupe ou à oreilles pliées. Les itérations ci-dessous sont conservées comme historique. Elle ne valide pas de nouveaux timings, ni la chorégraphie proposée pendant la génération, ni une implémentation Flutter.

**Correction la plus récente :** Alanc juge les yeux de v4 trop gros et demande de respecter les proportions. La [planche v5](mockups/planche-lapin-v5-proportions.png) réduit les yeux en conservant leur espacement, la bouche de v4 et les oreilles raccourcies sans pli. Elle remplace v4 comme support courant de discussion ; l'agrandissement des yeux de v4 n'est pas retenu. Le réglage précis de v5 reste à valider visuellement.

**Direction courante après itérations :** Alanc préfère la variante blanc/noir aux oreilles raccourcies (« c'est déjà mieux »), puis demande un essai plus mignon avec yeux et bouche un peu agrandis, et explicitement aucune oreille pliée. La [planche v4](mockups/planche-lapin-v4-yeux-oreilles.png) illustre cet essai : pointes arrondies dépliées, asymétrie conservée par l'inclinaison. Cette demande corrige les descriptions historiques de pointe pliée ; les dimensions exactes des yeux et de la bouche restent à apprécier sur l'image. Les tokens taupe et premières planches ci-dessous documentent les études antérieures, sans décrire les couleurs de la direction courante.

**Validé par Alanc.** Un dessin simplifié dans l'esprit de Grok Bot, reconnaissable comme le lapin fourni. La tête, les petits yeux sombres, la bouche et les longues oreilles asymétriques portent son identité. Le même lapin et les mêmes animations servent tous les profils ; le nom varie, **Otc** pour celui d'Alanc. Le fond est personnalisable par profil, avec verre dépoli/flou, pastels et dégradé fixe.

**Correction validée : aucun brodage dans le compagnon.** Ni fil, ni points de couture, ni texture brodée. La bouche conserve une forme reconnaissable avec un tracé graphique lisse et continu ; la matière de la peluche ne doit pas être reproduite.

**Proposition à juger sur la première planche.** Dessiner la tête et les oreilles seules, en aplats doux. Garder le caractère du doudou sans détailler tissu usé, coutures, vêtements ni corps. Ce cadrage, les teintes exactes, proportions et valeurs numériques ci-dessous ne sont pas des décisions utilisateur.

Ce dossier complète les [contrats généraux du 20 octobre](../ux-Hermes%20Mobile-2026-10-20/DESIGN.md). Le code actuel utilise Flutter, ThemeData et les rôles de ColorScheme ; le thème clair/sombre et Dynamic Color de l'interface sont hérités. La palette du lapin constitue une proposition d'illustration, pas une nouvelle palette globale.

Les deux contrats de ce dossier prévalent sur ses maquettes et imports en cas de conflit ; une proposition reste une proposition dans chaque support. Aucun développement Flutter n'est autorisé à cette étape.

## Colors

**Validé :** douceur pastel du fond ; **proposé :** tous les hexadécimaux du frontmatter et leur emploi précis.

| Token | Usage proposé |
| --- | --- |
| `{colors.rabbit-coat}` | Aplat principal beige-taupe, interprétation du doudou. |
| `{colors.rabbit-ear-inner}` | Intérieur des deux oreilles, plus clair sans texture satinée détaillée. |
| `{colors.rabbit-face}` | Petits yeux, nez triangulaire et bouche ; conserver cette même encre aux différentes poses. |
| `{colors.pastel-lavender}` / `{colors.pastel-peach}` | Exemple unique de dégradé pastel fixe ; aucune palette par défaut approuvée. |
| `{colors.glass-veil}` | Voile translucide sur le dégradé ; opacité et flou à comparer visuellement. |

Les traits noirs sur le visage blanc offrent un contraste théorique de 21:1. La silhouette blanche sur les pastels nécessite une limite extérieure lisible, comme dans la planche v5 ; vérifier à taille réelle. Objectifs de contrôle : traits significatifs et focus au moins 3:1, texte ordinaire au moins 4,5:1. Ces objectifs ne valent pas mesure du rendu final.

Les noms et statuts utilisent les rôles sémantiques du thème, sur une surface stable, hors des nappes floues. Ne jamais choisir leur encre d'après la couleur pastel seule. Les illustrations restent identiques en clair/sombre ; vérifier le bord du panneau dans les deux modes, sans recolorer le lapin par profil.

## Typography

Hériter des styles de texte Flutter existants : `{typography.companion-name.note}` et `{typography.companion-status.note}`. Aucune police ni taille de texte nouvelle. Le nom est du vrai texte, jamais intégré à l'image ; il accepte les noms longs et le texte agrandi. Le nom du compagnon n'est pas le champ existant `Profile.label` : aucun renommage de profil n'est déduit.

## Layout & Spacing

Les tokens `{spacing.xs}` à `{spacing.xl}` reprennent `Spacing` dans `lib/ui/tokens.dart`. Les dimensions de proposition sont exprimées en pixels logiques Flutter, sans engagement sur les pixels de l'asset exporté.

| Emplacement validé | Composition proposée / limite |
| --- | --- |
| Tout en haut du profil | Panneau pastel avant les autres contenus ; lapin entier tête + oreilles, enveloppe de 160–200 px, référence `{components.companion.profile-size}` ; nom adjacent ou dessous. |
| Sur le côté du texte en génération | Slot réservé de `{components.companion.compact-size}` ; minimum `{components.companion.compact-minimum}` si la colonne reste lisible ; oreilles intégralement visibles. |

Conserver une enveloppe extérieure stable dans toutes les poses : les oreilles ne poussent pas le texte. Prévoir un écart de `{spacing.sm}` entre slot et réponse. Le compagnon n'est pas une icône de 24 px ; ne pas écraser le visage pour gagner une colonne. Si l'espace manque, proposer le slot au-dessus du premier bloc de réponse, décision responsive encore à valider.

La [maquette des deux contextes](mockups/contextes.html) cadre placement et échelle ; ce n'est ni un nouvel écran global approuvé ni une interface connectée.

## Elevation & Depth

**Validé :** fond fixe à effet verre dépoli/flou. **Proposé :** grandes masses pastel sous un voile clair translucide, panneau arrondi, lapin net au premier plan. Le flou concerne le fond seul ; aucun flou sur yeux, bouche, nom ou statut. Les reflets ne bougent pas. Un dégradé précomposé fixe peut servir d'équivalent visuel si le flou réel nuit aux performances ou au contraste ; solution à comparer, pas choix technique arrêté.

L'interface environnante conserve ses élévations existantes ; aucune ombre animée ni particule ajoutée.

## Shapes

La [photo importée](imports/lapin-reference.png) fixe l'identité : tête ovale allongée, joues arrondies, petites marques oculaires espacées, nez sombre triangulaire relié à deux courbes de bouche, oreilles longues et différentes. Vue de face, l'oreille à gauche de l'image monte plus verticalement ; celle de droite s'ouvre davantage sur le côté. Préserver cette asymétrie dans toutes les poses ; ne pas retourner automatiquement tout le dessin pour orienter le regard.

**Proportions proposées pour comparaison :** tête autour de la moitié de la hauteur totale, oreilles occupant l'autre moitié ; petits yeux suffisamment espacés pour rester distincts. Ne pas imposer un ratio définitif avant comparaison à la photo. Le nez soutient la reconnaissance, sans remplacer les quatre traits prioritaires demandés.

En compact, simplifier l'intérieur des oreilles et épaissir optiquement les traits du visage ; conserver les deux yeux séparés, le nez et la bouche. Éviter de gros yeux brillants, des oreilles courtes/symétriques ou une grimace qui efface le visage. Les rayons `{rounded.sm}`, `{rounded.md}`, `{rounded.lg}` héritent de `Radii` ; ils concernent les surfaces d'interface, pas l'anatomie.

## Components

| Composant | Règles visuelles |
| --- | --- |
| `companion` | Même dessin aux deux échelles ; cinq poses ci-dessous ; fond et enveloppe stables. La zone tactile peut excéder le dessin sans le grossir. |
| `companion-backdrop` | Dégradé pastel fixe et voile dépoli ; personnalisation du fond seulement, aucune variante d'anatomie ou de personnalité. Son application au slot conversation reste à arbitrer. |
| `companion-name` | Vrai texte via `{typography.companion-name.note}` ; Otc pour Alanc, valeur du profil actif ailleurs ; identité distincte du nom du profil. |
| `work-status` | Libellé et icône existants conservés comme autorité d'état ; rôle `{typography.companion-status.note}`. Une expression du lapin ne code pas une réussite ou une erreur. |
| `backdrop-editor` | Sous-vue proposée : aperçu net, choix pastel identifiables par texte, sélection visible autrement que par couleur ; commandes héritées de l'interface. |

### Poses de la première planche

| Pose | Statut / construction |
| --- | --- |
| Face au repos | Validé : présence tranquille. Proposition : tête verticale, yeux ouverts, bouche neutre et oreilles naturelles asymétriques. |
| Regard latéral | Validé : petits regards à droite/gauche. Proposition : yeux déplacés discrètement, tête accompagnant légèrement ; ne pas agrandir les yeux. |
| Chatouilles | Validé : oreilles qui remuent, tentative de retournement. Proposition : frémissement puis joue présentée en trois-quarts, une oreille en retard, bouche conservée. |
| Exemple pastel | Validé : nature du fond. Proposition : pose de face sur lavande/pêche ; comparer également le dessin compact. |
| Concentration / retour | Proposition génération uniquement : oreilles légèrement relevées, regard vers le texte, puis vers le lecteur ; hors série validée. |

La [planche lapin](mockups/planche-lapin.png) sert à juger ressemblance et poses, sans approuver automatiquement ses réglages. Le cadrage tête/oreilles doit être comparé à la photo avant déclinaison d'assets de production. Les transitions et variantes immobiles sont précisées dans [EXPERIENCE.md](EXPERIENCE.md#state-patterns).

**Limites observées de cette première planche :** le regard latéral se distingue trop peu de la face ; accentuer le déplacement coordonné des yeux et du museau sans grossir les yeux. Le verre dépoli est encore peu marqué et le modelé dépasse l'aplat visé. Les mentions 48/64 px du bitmap ne prouvent aucune taille réelle. La [maquette de contexte](mockups/contextes.html) propose un SVG en aplat, des hauteurs CSS contrôlées de 48/64 px et un panneau plus explicite ; elle n'est ni un test sur appareil ni une preuve de conformité native.

### Points ouverts avant contrat de production

**Variante demandée ensuite par Alanc :** [planche v3 noir et blanc](mockups/planche-lapin-v3-noir-blanc.png), compagnon blanc à traits noirs, intérieurs d'oreilles gris clair et oreilles légèrement raccourcies, toujours asymétriques. Cette exploration conserve la bouche lisse sans brodage et le fond pastel personnalisable. Le raccourcissement demandé au générateur était d'environ 15–20 %, sans constituer une mesure du résultat. La palette taupe reste une étude antérieure ; le choix final entre variantes n'est pas encore confirmé. Les tokens taupe ci-dessus ne décrivent pas la variante v3.

**Affinage visuel du 22 octobre :** la [planche v2](mockups/planche-lapin-v2.png) accentue le regard latéral par un léger trois-quarts et distingue mieux le panneau dépoli du fond pastel, en gardant le visage net et la bouche lisse sans brodage. Elle devient le support courant de discussion ; la première planche reste conservée comme historique. Les mentions « Compact » et « Très petit » sont indicatives, pas des mesures. Un léger modelé demeure dans le bitmap ; l'aplat strict et la lecture sur appareil restent à vérifier. Cette révision ne constitue pas une validation utilisateur des propositions.

La planche doit encore faire valider la ressemblance, le cadrage sans corps, la palette et les deux échelles. La proposition de génération n'est pas approuvée. La coexistence ou le remplacement des trois points tournants déjà validés le 20 octobre reste à décider ; leur suppression n'est pas déduite de l'apparition du lapin.

## Do's and Don'ts

| À respecter | À éviter |
| --- | --- |
| Préserver tête, yeux, bouche et asymétrie des oreilles. | Transformer le lapin en mascotte générique à gros yeux. |
| Dessiner une bouche lisse et continue, sans matière. | Reproduire brodage, fils, points ou coutures du doudou. |
| Garder le même compagnon et les mêmes poses pour tous. | Créer une couleur, silhouette ou personnalité par profil. |
| Tenir le fond et le slot fixes pendant les animations. | Déplacer le texte avec les oreilles ou animer le dégradé. |
| Vérifier la lecture à 48/64 px, texte agrandi et dans les deux thèmes. | Valider une grande planche comme preuve suffisante de lisibilité compacte. |
| Distinguer les directions validées des réglages proposés. | Interpréter une maquette comme approbation utilisateur. |
