---
title: 'Story 3.2 — Déplier les détails reçus d’une action'
type: 'feature'
created: '2026-10-22'
status: 'done'
baseline_commit: '98a64891da7672ca3c8c4110370f3ad404a4fdae'
route: 'dispatch'
review_loop_iteration: 0
context:
  - 'C:/Users/alanc/.codex/RTK.md'
  - '{project-root}/_bmad-output/implementation-artifacts/investigation-3-2-details-action.md'
---

<frozen-after-approval reason="intention utilisateur — modification après approbation uniquement sur décision humaine">

## Intent

Consulter les détails reçus de l’outil depuis sa ligne d’activité, en réutilisant la projection et les groupes de 3.1, sans chargement distant au dépliage.

## Boundaries & Constraints

**Toujours :** conserver les identités, fins attestées, reprises et corrections de 3.1. Préserver les quatre lots Otc, `WorkStateLabel`, le repli des groupes, les blocs paresseux et les commandes accessibles. Choix de dépliage indépendant pour chaque action, conservé dans la page pendant les mises à jour et le repli du groupe.

Champs autorisés des événements connus : nom, contexte, arguments, sortie et différence textuelle reçus. Section « Erreur » uniquement si `result.error` est une chaîne non vide. Aucune commande ou erreur déduite d’un nom MCP, d’un texte ou d’un code de sortie. Champs absents/nuls omis ; conserver les valeurs reçues `false`, `0`, listes et objets.

**Jamais :** détails d’un type inconnu, raisonnement privé, exécution du contenu, changement d’état du travail, progression, RPC de détail ou migration destructive. Un snapshot sans détails reste incomplet ; l’installation n’est pas validée.

## I/O & Edge-Case Matrix

| Entrée / action | Résultat exigé |
| --- | --- |
| Début avec arguments puis fin avec sortie | Même action enrichie, état déplié conservé |
| Fin seule, erreur structurée reçue | Afficher seulement les détails présents, aucun début ni échec global supposé |
| Champs absents, nuls ou mal typés | Ne pas créer de détail ni de contrôle sans contenu consultable |
| Type inconnu avec clés ressemblantes | Ligne générique sans détail interprété |
| ID absent | Détails limités à l’événement connu, aucun rapprochement par nom |
| Rejeu, autre tour/profil/epoch | Aucun détail transféré entre actions ; pas de duplication ni d’appel rejoué |
| Projection ancienne / snapshot sans outils | Lecture compatible ; aucun détail reconstitué depuis le texte |
| Sortie longue, code, marqueur de troncature serveur | Contenu consultable sans coupe silencieuse ; aucune promesse de sortie complète |

## Décisions UX approuvées

Après présentation et explication de la spec, Alanc : « fait tout ce que tu recommandes ».

1. Toute la ligne devient une commande de 48 px minimum, avec chevron et état annoncé ; sans détail reçu, elle reste statique.
2. Afficher directement les données reçues en texte/JSON ; textes de secours serveur seulement si la donnée structurée manque. Aucun second dépliage d’aperçu.
3. Validation complémentaire « je valide » : après l’ouverture volontaire d’un détail, le groupe reste ouvert à l’arrivée du premier fragment, même si le détail est ensuite replié. Le groupe conserve sa commande de repli manuel ; les groupes jamais consultés gardent le repli automatique de 3.1.

</frozen-after-approval>

## Code Map

- `lib/models/timeline.dart` : `ActivityItem` sérialisé sans détails aujourd’hui ; enrichissement compatible, identités inchangées.
- `lib/data/conversation_repository.dart` : corrélation et copies de projection ; conserver les détails.
- `lib/data/event_mapping.dart` : source des familles/phases ; décoder les détails des événements connus, jamais du fallback.
- `lib/features/conversation/draft_view.dart` : `_timeline`, groupes et état local ; transmettre détails et commandes aux lignes sans réseau.
- `lib/ui/components/activity_line.dart`, nouveau `lib/ui/components/activity_details.dart` : remplacer la sémantique statique seulement pour les lignes dépliables ; détails en lecture seule et texte sélectionnable.
- `lib/ui/content.dart`, `tokens.dart`, `gallery.dart` : textes, styles et scénarios.

## Tasks & Acceptance

- [x] `timeline.dart`, `event_mapping.dart`, `conversation_repository.dart` aux chemins ci-dessus : liste explicite de champs, fusion des seuls champs présents, null explicite supprimant le champ antérieur, stockage compatible sans nouvelle table. Tests de matrice sous `test/conversation_test.dart` et `test/resync_test.dart`.
- [x] `activity_line.dart`, nouveau `activity_details.dart`, `draft_view.dart`, `content.dart`, `tokens.dart` : appliquer les choix approuvés, sections absentes omises, texte long défilant et code lisible à 200 % ; état local indexé par identité stable, indépendant de l’état du groupe.
- [x] `lib/ui/gallery.dart`, `test/activity_line_test.dart`, `test/gallery_test.dart` : outil avec arguments, sortie longue, erreur reçue, aucun détail, champ partiel, mise à jour et repli du groupe.
- [x] `contracts/README.md`, `contracts/fixtures/tool-*.json`, `test/contracts_test.dart` : documenter les champs et limites ; fixtures synthétiques, aucune disponibilité réelle affirmée.
- [x] Dossiers UX des 20/22 octobre : consigner les décisions approuvées ; rapport et captures sous `story-3-2-verification/`.

Étant donné une action ouverte, quand le fil reçoit une fin, un fragment ou une reconstruction, alors son choix et son focus restent stables, les nouveaux détails apparaissent et aucun appel Hermes n’est déclenché par la vue.

Étant donné 320/375 px, paysage, clavier ouvert, clair/sombre, texte 200 % et mouvement réduit, quand on consulte puis replie les détails, alors les commandes restent atteignables, la sortie lisible et l’état replié/déplié annoncé sans doubler le statut du travail.

## Implementation Notes

Audit avant revue : le repli automatique du groupe au premier fragment pouvait masquer une action ouverte et retirer son focus (`story-3-2-verification/focus-probe.log`). Alanc a validé le maintien du groupe ouvert après consultation volontaire. Appliquer la même règle dans DraftView et la galerie ; tester premier fragment, focus, reconstruction et repli manuel. Les groupes jamais consultés conservent le comportement de 3.1.

Arbre initial propre ; 3.1 terminée au commit `98a64891da7672ca3c8c4110370f3ad404a4fdae`. Approbation de 3.2 reçue après son explication détaillée. Le worker possède les fichiers de cette story ; le coordinateur clôture la revue. Travail partagé : ne pas rétablir les modifications d’autrui. L’entête est la commande ; le corps déplié reste sélectionnable et défilable sans refermer la ligne. Aucun push ni opération distante.

## Spec Change Log

- Décision humaine complémentaire : « je valide » approuve le maintien du groupe ouvert après ouverture d’un détail, sans retirer sa commande manuelle. Préserver le repli automatique des groupes jamais consultés, les identités 3.1, les lots Otc et les détails déjà implémentés. Cette précision résout la perte de focus reproduite avant revue.

## Review Triage Log

Les trois couches ont rendu leurs constats avant ce triage. Le premier lecteur aveugle a signalé avoir lu la spec ; ses dix constats restent enregistrés sous O, mais une nouvelle revue aveugle sans accès à la spec a été effectuée (B). E = cas limites, V = lacunes de vérification. Les reproductions des lecteurs ont été examinées avec les appels et gardes du code ; les lacunes V sont prises avec leurs preuves déposées.

| ID | Constat | Verdict, preuve et route |
| --- | --- | --- |
| O1 | Valeur structurée blanche remplacée par un vieux secours | medium, patch : `present()` convertit la chaîne en absence avant le `??`. Le champ reçu doit garder la priorité. |
| O2 | Sections sans clé échangeant leurs positions de lecture | medium, patch : les Scrollable sont rapprochés par index lors de l’insertion d’Arguments avant Sortie ; identifier chaque section. |
| O3 | Clavier sans nouvel objet de projection : fin du fil masquée | medium, patch : la garde `timelineChanged` exclut cette reconstruction ; reproduction indépendante E2/B6. Conserver aussi l’ancrage lors du changement de viewport. |
| O4 | Enrichissement volumineux faisant disparaître la commande focalisée | medium, patch : une nouvelle projection déclenche le saut en bas malgré la lecture d’un détail focalisé. Ne pas suivre automatiquement pendant cette consultation. |
| O5 | Détails imbriqués et restaurés modifiables | low, patch : le wrapper externe ne protège pas les objets JSON imbriqués ; la projection peut être modifiée via ces références sans copie repository. Geler les données aux frontières existantes, sans changer les constructeurs publics. |
| O6 | Scénario principal hors découverte des tests | medium, patch : le fichier de capture n’a pas le suffixe `_test.dart` et CI lance `flutter test`. Ajouter une entrée portable découverte normalement. |
| O7 | Chemins de polices locaux obligatoires | low, patch : le scénario charge inconditionnellement les polices Windows avant ses assertions. Rendre la génération visuelle optionnelle. |
| O8 | Défilement testé par jumpTo plutôt que gestes | low, patch : les tests prouvent les dimensions mais pas le pan tactile à travers le texte sélectionnable. Ajouter des glissements. |
| O9 | Indépendance de deux détails et retour après éviction non testés | low, patch : le scénario n’ouvre qu’une action. Ajouter la séquence dans les tests portables. |
| O10 | Consultation puis fermeture avant premier fragment non testée | low, patch : le scénario conserve le détail ouvert ; ajouter sa fermeture avant réponse pour vérifier le maintien du groupe consulté. |
| B1 | Arguments/résultat blancs affichant le secours | medium, patch : même défaut constaté par une sonde indépendante ; priorité fondée sur présence de la valeur structurée. |
| B2 | Patch textuel vide conservant l’ancien contexte | medium, patch : le décodeur omet `context: ''`, donc la fusion garde le texte précédent. Conserver la chaîne reçue, l’omettre seulement au rendu. |
| B3 | Alias mutables et restauration non protégée | low, patch : sonde reproduite aux mêmes frontières que O5. Geler JSON reçu, copié et restauré. |
| B4 | Ajout d’une section transférant l’offset de Sortie | medium, patch : la sonde transfère 200 px vers Arguments. Clé stable par section. |
| B5 | Une action devenant groupe perd son focus | medium, patch : l’ajout d’ActivityGroup change le parent du premier ActivityLine malgré son eventKey stable. Clé globale privée par identité existante ; aucun changement des lots Otc. |
| B6 | Ancrage au clavier perdu | medium, patch : sonde avec projection identique, écart de 78 px en bas après changement d’inset. Même défaut que O3/E2. |
| B7 | Scénario DraftView absent du lancement CI | medium, patch : même lacune que O6/V1, entrée de test découverte et indépendante des polices. |
| B8 | Capture couplée à Windows et un SDK absolu | low, patch : même dépendance que O7 ; les captures locales deviennent explicitement optionnelles, les assertions restent portables. |
| B9 | Débordement des détails sans indication de défilement | low, patch : les captures étroites coupent les lignes/colonnes sans barre visible. Ajouter les barres natives avec contrôleurs privés. |
| B10 | Sélection/copier et gestes non vérifiés | low, patch : compter SelectableText et appeler jumpTo ne prouve pas le comportement tactile ou le presse-papiers. Ajouter un scénario d’interaction. |
| E1 | Focus perdu lors du passage solitaire → groupe | medium, patch : sonde indépendante sur le changement de parent décrit en B5. Garder l’identité de l’élément focalisable. |
| E2 | Fin du fil non suivie à l’ouverture du clavier | medium, patch : sonde indépendante ; même garde que O3/B6. |
| V1 | Conservation des détails sans protection CI | medium, patch : lacune déposée avec recherche des imports et commande CI ; entrée `_test.dart` portable requise. |
| V2 | Absence d’assertion sur l’offset lors du dépliage local | medium, patch : le test appelle ensureVisible après ouverture, masquant un saut éventuel. Vérifier l’offset avant tout déplacement de test. |

Groupes par cause : priorité structurée O1/B1 ; fusion des chaînes vides B2 ; identité des sections O2/B4 ; ancrage au viewport O3/B6/E2 ; lecture focalisée O4 ; gel JSON O5/B3 ; découverte et polices O6/O7/B7/B8/V1 ; gestes et copie O8/B10 ; indépendance O9 ; consultation refermée O10 ; identité de l’action B5/E1 ; affordances B9 ; assertion d’offset V2. Tous sont des corrections privées localisées ou des tests, sans nouvelle capacité Hermes ni surface publique. Aucun report.

## Verification

Flutter 3.47.7 via `rtk proxy` : analyse, tests ciblés puis suite complète, builds debug app/galerie. Captures lisibles et vérification sémantique/clavier sur la vraie DraftView ; distinguer ces preuves des essais de téléphone et de disponibilité réelle non réalisés.

Vérification finale après correction validée : analyse propre, 308 tests réussis (`tests.log`), matrice DraftView réussie (`captures.log`), 24 captures lisibles, builds Android debug app et galerie réussis. Voir [audit du coordinateur](story-3-2-verification/audit-coordinateur.md).

Après application des 24 correctifs de revue (tous contrôlés un par un dans le code) : analyse propre, **317 tests réussis**, matrice DraftView et 24 captures régénérées, builds Android debug app et galerie réussis. Aucun report. Suivis mineurs non bloquants : le test O4 pourrait affirmer explicitement que le fil est en bas avant l'enrichissement ; `_activityKeys` de DraftView n'est jamais purgée ; chemins de polices absolus conservés derrière `DETAIL_CAPTURES`. Téléphone physique, lecteur d'écran et disponibilité réelle des champs sur l'installation Hermes non vérifiés.
