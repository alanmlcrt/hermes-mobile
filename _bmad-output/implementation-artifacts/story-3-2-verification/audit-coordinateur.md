# Audit du coordinateur — story 3.2

Le diff complet depuis `98a64891da7672ca3c8c4110370f3ad404a4fdae` a été relu, nouveaux fichiers inclus. Les détails suivent les identités existantes ; aucun changement des composants Otc ou de WorkStateLabel. Les logs de remise ont été convertis en UTF-8 pour permettre leur lecture et leur revue.

## Matrice vérifiée

| Cas | Preuve automatisée |
| --- | --- |
| Début puis fin, fusion et persistance | `conversation_test.dart` : « détails reçus : fusion, null, rejeu et persistance » ; capture DraftView : ouverture puis enrichissement sans perte de focus |
| Fin seule avec erreur reçue | `conversation_test.dart` : « fin seule avec erreur reçue : aucun début ni échec global supposé » |
| Absence, null et types invalides | Tests de fusion et de mapping ; `activity_line_test.dart` : « aucun contenu utilisable : ligne statique sans faux contrôle » |
| Type inconnu / ID absent | `conversation_test.dart` : « détails : inconnu ignoré, sans ID indépendant, types invalides omis » |
| Rejeu / autre tour, profil, session, connexion | Tests d’identités existants enrichis d’arguments distincts ; assertions sur l’absence de transfert ; replay au même seq ignoré |
| Autre epoch et snapshot échoué | `resync_test.dart` : « nouvel epoch et snapshot échoué : aucune fin héritée de l’ancien ID », détails anciens conservés séparément |
| Projection ancienne et snapshot sans outils | `resync_test.dart` : « projection compatible : détails reçus seulement, copies correctives » et « snapshot textuel sans outils : aucune action reconstruite » |
| Sortie longue et marqueur serveur | `activity_line_test.dart` : « sortie longue : deux axes, texte intégral et corps sans repli » ; captures `output-*.png` |

`matrix-audit.log` enregistre 105 tests ciblés réussis avant l’ajout du test de défilement à deux axes. Ce dernier a également passé (18 tests du fichier). La suite complète finale est enregistrée dans `full-tests.log`.

Résultat final après correction validée : **308 tests réussis** (`tests.log`), analyse sans problème, matrice DraftView et 24 captures régénérées (`captures.log`), builds Android debug de l’application et de la galerie réussis. `devices.json` confirme uniquement Windows et des navigateurs disponibles ; aucun téléphone connecté.

Les 24 captures ont été examinées en planche, puis les vues 320 px et paysage avec clavier simulé en taille originale. Le texte reste consultable par défilement. Aucun téléphone, clavier système ou lecteur d’écran physique n’a été testé. La présence des champs sur l’installation Hermes privée reste non vérifiée.

## Arbitrage validé avant correction

Un contrôle supplémentaire a simulé la réception du premier fragment en posant `responseReceived` sur l’action ouverte. Le groupe se replie automatiquement selon 3.1 : son contrôle est démonté et perd le focus. `focus-probe.log` conserve cet échec attendu ; le fichier de test temporaire a été retiré.

Ce cas n’était pas couvert par la seule arrivée d’un résultat d’outil. Alanc a répondu « je valide » à la recommandation de maintenir le groupe ouvert après consultation volontaire d’un détail. La spec et les deux dossiers UX ont été mis à jour avant le correctif.

Le correctif utilise l’identité stable des actions déjà consultées. Le repli manuel du groupe garde la priorité. La galerie applique la même règle. Dix tests ciblés ont passé, dont les douze configurations de DraftView avec premier fragment, focus conservé et repli manuel. La sonde échouée reste une preuve historique avant correction ; le scénario corrigé appartient au test de capture maintenu.

La revue indépendante et la clôture suivent.
