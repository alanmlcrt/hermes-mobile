---
name: Hermes Mobile
description: Interface de conversation personnelle avec Hermes, sobre et simple à comprendre.
status: draft
updated: 2026-10-20
language: fr
sources:
  - ../../prds/prd-Hermes-Mobile-2026-10-20/prd.md
  - ../../prds/prd-Hermes-Mobile-2026-10-20/addendum.md
  - .memlog.md
colors: {}
typography: {}
rounded: {}
spacing: {}
components: {}
theme:
  mode: system
  variants: [light, dark]
  android:
    dynamic-colors: true
    minimum-dynamic-api: 31
    runtime-role-bindings:
      canvas: surface
      content: onSurface
      emphasis: primary
      emphasis-content: onPrimary
    fallback: unresolved
---

# Hermes Mobile — Design

## Décisions approuvées — illustrations d’activité 3.3 (22 octobre)

Les trois arbitrages UX de la Story 3.3 sont approuvés par Alanc (« Fait tout ce que tu recommandes », Options A retenues) :
1. **Conciliation `UX-DR13` / lot 4 Otc :** aucune ligne « Préparation de réponse » n’est réintroduite dans le fil de conversation — Otc seul porte la préparation de réponse au niveau du tour conformément au lot 4. Le motif des trois petits points en rotation (dans le slot 24 × 24 px, sans bulle ni grand dessin, immobile en variante fixe) sert d’illustration pour une ligne d’activité `ActivityKind.unknown` et de repli générique du catalogue.
2. **Catalogue dès 3.3 (`code`, `tool`, `unknown`) :** `ActivityCatalog` est indexé exclusivement par `ActivityKind` avec repli générique, sans lire un emoji, un nom d’outil MCP ou une minuterie. Il fournit 3 illustrations : `code` (ordinateur au châssis fixe aux traits épais, lignes de code et curseur mobiles, `UX-DR14`), `tool` (appel d’outil : boîtier, clé oscillante et impulsion) et `unknown` (trois petits points en rotation 24 × 24 px), toutes présentées dans la galerie en clair, sombre, texte 200 % et mouvement réduit.
3. **Fin d’action et pause de la page :** toute ligne avec `completed: true` (« Fin reçue ») ou lorsque la pause de la page est active affiche immédiatement sa variante immobile sans timer ni cycle actif.

## Décisions approuvées — activités compactes 3.1 (22 octobre)

Une ligne par action attestée, avec emplacement d’illustration statique de 24 px, texte multiligne et thème existant. La fin reçue porte un repère neutre et le texte « Fin reçue », accessible comme « Fin d’action reçue » ; aucune couleur de réussite ni second « Terminé ». Les commandes de groupe ont une cible minimale de 48 px. Seules les familles `tool` et `unknown` sont justifiées ; les événements sans ID et les anciennes projections restent génériques.

Cette décision ne rouvre aucun contrat Otc : anatomie v5, fonds locaux, pause, chatouilles, suspension, réservation commune de 64 px et construction paresseuse du fil restent inchangés. Les mentions historiques de points de préparation ci-dessous sont remplacées par le contrat courant du lot 4 : Otc seul en porte l’intention. Aucun catalogue ou mouvement nouveau ne fait partie de 3.1.

Premier cadrage issu des décisions d'Alanc. Les métadonnées `theme` expriment le thème système ; elles ne remplacent pas les tokens visuels encore vides. Ce brouillon ne constitue pas un système de composants prêt à implémenter.

**Base visuelle acceptée pour le premier MVP.** Alanc approuve la direction compacte actuelle et demande de pouvoir la faire évoluer, jusqu’à une refonte ultérieure. Les [références acceptées](mockups/exchange-conversation.html) sont conservées dans `mockups/`. Cette acceptation ne clôt pas les tokens ou surfaces encore ouverts.

## Brand & Style

**Confirmé.** Une apparence sobre, sans couleur de marque particulière. L'interface doit être simple à comprendre et éviter une présentation trop technique. La conversation reste au premier plan ; Hermes réalise le travail.

Muse et Grok Bot sont des références d'intention. Leur palette, leur typographie et leurs écrans n'ont pas été validés pour Hermes. La [recherche](.working/reference-research.md) distingue les observations des choix d'Alanc.

## Colors

**Confirmé.** Le mode clair ou sombre suit automatiquement le téléphone. Sur Android, les couleurs reprennent celles choisies par le système ; aucune couleur de marque fixe n'est demandée.

La correspondance technique est **Dynamic Color**, disponible depuis Android 12, à partir du fond d'écran ou du choix système. Cela ne choisit ni pile technique ni bibliothèque complète de composants. Source : [documentation Android](https://developer.android.com/develop/ui/views/theming/dynamic-colors).

**Interprétation technique à vérifier.** Les liaisons `runtime-role-bindings` décrivent les paires sémantiques système pour fond/texte et accent/texte sur accent. Ce sont des rôles à résoudre à l'exécution, jamais des couleurs hexadécimales figées. Leur application à chaque composant reste à définir.

**Ouvert.** Palette de secours claire/sombre pour les appareils sans couleurs dynamiques ; paires de contraste et usages de l'erreur. `colors` reste vide afin de ne pas faire passer des valeurs non choisies pour un contrat final. Le PRD NFR-1 exige une lecture accessible et des états compréhensibles sans la couleur ; les contrastes restent à vérifier sur les palettes rendues.

## Typography

La lisibilité des longs messages et du code, ainsi que le texte agrandi, sont exigés par le PRD FR-4/NFR-1. Police, tailles, graisses et hiérarchie ne sont pas encore choisies ; aucun token typographique n'est finalisé.

## Layout & Spacing

Conversation et suivi synthétique prioritaires ; détails accessibles à la demande (PRD FR-7). Navigation, composition des surfaces, densité et espacements restent ouverts. Aucun tiroir, onglet ou découpage d'écran n'est imposé.

## Elevation & Depth

Aucune règle d'ombre ou de profondeur choisie.

## Shapes

Pour les animations de chargement, Alanc demande des objets simples et reconnaissables : ordinateur avec lignes de code, page vierge qui se remplit et machine appelant un outil. Rayons et formes des autres composants restent à préciser.

La direction simplifiée reçoit un retour positif ; Alanc demande ensuite des traits plus épais et davantage de dynamisme. La maquette propose des traits SVG de 3,4 unités, une saisie séquencée et des réactions brèves de l’outil. Ces valeurs restent des réglages de la proposition visuelle.

**Dernier ajustement prioritaire :** Alanc juge les illustrations trop grandes. Les indicateurs sont désormais petits, placés près du libellé ; la préparation de réponse comporte seulement trois points tournants, sans bulle ni grand dessin. Le châssis de l’ordinateur reste fixe ; seules les lignes et le curseur de code bougent. La [référence Sparky](.working/sparky-reference.md) inspire l’échelle et la présentation compacte des activités. Sa propre animation de points rebondit ; la rotation est le choix explicite d’Alanc. Dans la maquette : emplacement d’illustration 64 × 44 px, SVG des trois points 24 × 24 px ; ces dimensions d’aperçu ne constituent pas encore des tokens natifs finalisés.

La [scène animée complète](.working/exchange-conversation.html), demandée ensuite par Alanc, montre ces indicateurs dans un échange fictif : message, appels d’outils compacts, préparation de réponse, réponse progressive et fichier résultat. Elle illustre la composition dans le fil ; ses commandes de lecture restent hors interface produit.

## Components

Le tableau fixe les intentions visuelles connues. Les dimensions et variantes restent à définir ; les comportements vivent dans [EXPERIENCE.md](EXPERIENCE.md#component-patterns).

### Évolutivité du design

**Contrainte confirmée pour le développement.** Centraliser les styles dans des tokens sémantiques et assembler l’interface à partir de composants réutilisables. Le thème et les illustrations d’activité doivent pouvoir être remplacés sans modifier la communication avec Hermes ni la gestion des conversations. Les durées, amplitudes et variantes immobiles des animations appartiennent au catalogue de présentation. Reprendre les [règles et critères de vérification](ui-evolution-requirements.md) dans l’architecture et les stories concernées ; ne pas construire un moteur de personnalisation disproportionné pour le MVP.

**Référence MVP, évolutive.** La [maquette simplifiée](mockups/simple-conversation.html) propose [17 illustrations d’activité](.working/activity-catalogue.md) : code, création et modification de fichier, appels d’outil, recherche et navigation web, lecture, commande, recherche de fichier, création et analyse d’image, mémoire, délégation, organisation, compétence, planification et préparation de réponse. Retenir les derniers ajustements compacts décrits ci-dessus : ordinateur fixe et trois points tournants pour la préparation. La [recherche sur les outils Hermes](.working/hermes-tool-activity-research.md) distingue les associations vérifiées des métaphores proposées. La [maquette Anatomy](.working/anatomy-conversation.html) est conservée comme direction rejetée : rendu trop complexe. La [première maquette](.working/direction-conversation.html) conserve l’historique de la composition.

| Composant logique | Intention visuelle capturée / limite du brouillon |
| --- | --- |
| Connexion | Erreurs compréhensibles ; présentation à définir. |
| Choix du profil | Profil utilisé identifiable ; présentation à définir. |
| Historique | Conversations distinguables ; présentation à définir. |
| Conversation | Messages longs, mise en forme et code lisibles ; forme à définir. |
| Saisie et envoi | Saisie compréhensible avec clavier affiché ; composition à définir. |
| Pièce jointe | Fichier identifiable ; aperçu d'image proposé par le PRD. |
| Suivi et détails | Synthèse lisible, détails techniques dépliables ; apparence à définir. |
| Arrêt | Distinguer demande et confirmation ; apparence à définir. |
| Notification de fin | Conversation concernée identifiable ; contenu précis à définir. |
| Intervention / résultat | FR-13/FR-14 proposés ; aucun traitement visuel arrêté. |

## Do's and Don'ts

| À respecter | À éviter |
| --- | --- |
| Suivre le thème et les couleurs du téléphone selon les capacités Android. | Introduire une couleur de marque sans choix d'Alanc. |
| Garder les détails techniques accessibles à la demande. | Faire de la sortie technique la présentation principale. |
| Conserver une information d'état lisible dans les deux modes. | Communiquer un état uniquement par sa couleur. |

Les contrats DESIGN.md et EXPERIENCE.md prévalent sur les futurs visuels en cas de conflit.
