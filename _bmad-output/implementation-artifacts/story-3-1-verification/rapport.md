# Vérification de la story 3.1 — activités compactes

Date : 22 octobre 2026. Implémentation locale et revue indépendante effectuées ; aucun push ni accès au backend personnel.

## Résultat

`ActivityKind` est typé (`tool`, `unknown`). Chaque activité conserve ID opaque, preuves de début/fin, clé stable et réception du premier fragment de réponse. Le repository corrèle uniquement le même ID dans le même fil et tour, conserve l’ordre des actions, garde séparés événements inconnus/anonymes et préserve les métadonnées lors du rattachement du tour zéro. La désérialisation ancienne reste générique sans fin supposée ; aucune migration de base n’est ajoutée.

`ActivityLine` réserve 24 px, accepte le texte multiligne et affiche le repère neutre « Fin reçue » sur preuve reçue. `ActivityGroup` expose une commande native de 48 px, son état accessible et le nombre sans fin confirmée. Le premier delta/interim non vide après au moins deux activités déclenche le repli ; ni texte final seul, ni terminal ne le déclenchent. Le choix manuel demeure dans la page par identité stable et les blocs restent paresseux sous la réservation Otc commune. Aucun appel Hermes ne provient du repli ou du rendu.

La galerie possède un scénario synthétique pilotable : début, deuxième ID, fin reçue, inconnu, réponse, repli/dépliage et remise à zéro. Les contrats et dossiers UX du 20 et 22 octobre documentent les décisions approuvées sans changer les contrats Otc.

Les libellés sont neutres : « Appel d’outil » et « Événement non reconnu ». Ils n’affirment pas qu’une activité historique ou inconnue est en cours et laissent l’autorité du statut à `WorkStateLabel`.

## Commandes et preuves

SDK existant : `C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat`, toutes les commandes via `rtk proxy`.

| Vérification | Résultat | Preuve |
| --- | --- | --- |
| `flutter analyze` final | Aucune anomalie | [analyze.log](analyze.log) |
| `flutter test --reporter expanded` final | 299 tests réussis (après correctifs de revue) | [tests.log](tests.log) |
| Tests ciblés conversation, reprise, galerie et activités | 88 tests réussis avant le dernier cas ajouté ; tous rejoués dans la suite finale | [targeted-initial.log](targeted-initial.log) |
| `flutter test test/support/activity_capture.dart test/activity_line_test.dart --reporter expanded --dart-define=ACTIVITY_CAPTURES=true` | 15 tests réussis ; 32 captures lisibles | [captures.log](captures.log), [planche de contrôle](contact-sheet.png) |
| `flutter build apk --debug` final | Succès | [build-app.log](build-app.log) |
| `flutter build apk --debug --target lib/main_gallery.dart` | Succès | [build-gallery.log](build-gallery.log) |

L’APK courant `build/app/outputs/flutter-apk/app-debug.apk` est celui de l’application (build final après la galerie). La galerie utilise le même chemin de sortie lorsqu’elle est reconstruite.

## Audit de la matrice

Toutes les couvertures ci-dessous ont été exécutées et réussissent dans `tests.log`.

| Entrée | Couverture exécutée |
| --- | --- |
| Même famille, IDs distincts, ordre conservé | `actions distinctes, fin corrélée, fin seule et événements anonymes` |
| Début puis fin, sans réussite supposée | Même test ; état du travail encore `running` après fin d’outil |
| Fin sans début | Même test, ID `opaque-C` avec `started=false`, `completed=true` |
| ID absent / événement inconnu | Même test + `types inconnus et outils : ligne d’activité générique` |
| Doublon / rejeu / isolation | `rejeu outils : fin corrélée et doublon écarté sans renvoi`, `identités cloisonnées par connexion, profil et session`, tour suivant dans le test des actions distinctes |
| Réponse sans fin d’outil | Test des actions distinctes + trois variantes `repli attesté uniquement au fragment non vide` |
| Ancienne projection | `projection ancienne : générique, sans phase ou identité inventée` |
| Historique sans outils | `snapshot textuel sans outils : aucune action reconstruite` |
| Rattachement tardif / persistance | `activité avant accusé RPC rattachée sans supposer le démarrage`, `premier texte avant accusé : repli conservé au rattachement`, relance SQLite dans le test des actions distinctes |

## Interface et continuité Otc

Les tests d’activités couvrent thèmes clair/sombre, 320/375 px, paysage 812 × 375, échelles 100/200 %, clavier simulé et mouvement réduit. Le contrôle est utilisable au clavier avec état sémantique replié/déplié ; le libellé de fin d’action et la réservation de 24 px sont vérifiés. Le test `reconstruction du groupe : choix et focus stables, aucune action distante` vérifie repli automatique, choix manuel, conservation du focus lors de nouveaux contenus/fins et absence d’envoi.

Les 32 captures ont été inspectées en planche, avec inspection agrandie des variantes étroites à 200 %, du paysage et des conversations complètes. Les premières captures Ahem ont été remplacées par Roboto/Segoe UI et MaterialIcons lisibles. Les 24 captures de composant montrent les états replié/déplié ; les huit captures `draft-*` montrent la vraie `DraftView` avec Otc et la saisie, dans les deux thèmes, à 320/375 px, 200 % et clavier simulé. Par exemple : [conversation sombre repliée](captures/draft-dark-320-200-keyboard-collapsed.png), [conversation claire dépliée](captures/draft-light-375-200-keyboard-expanded.png).

La suite complète rejoue les tests des quatre lots Otc : dessin, fonds locaux, pause, chatouilles, suspension, placement, réponse et construction paresseuse. Aucun fichier du compagnon, du thème, de l’outbox ou du protocole d’historique n’a reçu de changement fonctionnel. Le formatage accidentel hors périmètre a été retiré avant remise.

## Correctifs de revue

Appliqués et couverts par trois nouveaux tests : activités provisoires (tour zéro) normalisées avant démarrage/acceptation, sans reprendre la fin d’un ancien même ID (B1/B2/E1) ; corrélation limitée au contexte d’origine porté par la clé d’événement, y compris après un snapshot échoué sur un nouvel epoch (B3) ; galerie sans ajout d’activité après réponse (B7) ; marqueur « Fin reçue » vérifié dans `DraftView` (V1). Constats B4–B6, B8–B10 rejetés avec justification dans la spec.

## Limites explicites

- Aucun essai réel TalkBack/VoiceOver sur téléphone : les preuves sont des tests sémantiques et clavier Flutter. Le clavier des captures est simulé par `MediaQuery.viewInsets` ; aucune capture de téléphone n’est revendiquée.
- La présence réelle des événements `tool.start`/`tool.complete` et de leurs IDs sur l’installation personnelle reste non vérifiée. Les fixtures sont synthétiques et la source épinglée est documentaire ; aucun backend personnel n’a été contacté.
- Le snapshot textuel actuel ne reconstitue pas les outils ; cette limite reste explicite dans les contrats et l’UX. Le choix de dépliage est local à la page, pas une préférence persistée après sa fermeture.
- Les scripts de capture manuelle suivent les outils locaux existants et référencent les chemins de polices/SDK de cette machine ; les tests ordinaires n’exigent pas ces chemins.
- Les détails d’action, nouvelles illustrations/animations et l’arrêt restent hors périmètre, conformément aux stories 3.2 à 3.5.

## Revue et vérification parent

Trois revues indépendantes Orca (défauts, cas limites, lacunes de vérification) ont été reçues et triées dans la spec, constat par constat. Les patches retenus portent sur l’attribution provisoire avant accusé/démarrage, l’isolation après changement d’epoch et snapshot échoué, la vérification du marqueur de fin au point d’intégration DraftView et la fidélité des commandes de galerie après réponse. Les autres constats et leurs réfutations ou motifs de rejet sont consignés ; aucun travail différé.

Le parent a relu le diff unifié complet, inspecté la planche et les captures étroites/200 % ainsi que les conversations complètes. Un [journal de matrice séquentiel](matrix-audit.log) établit les scénarios par leur nom (88 tests ciblés après patches de données). Le cas de placement provisoire après l’historique a également été exécuté isolément avec succès avant la suite finale. [Inventaire Flutter des appareils](devices.json) : Windows et navigateurs uniquement, aucun téléphone connecté.

La remise initiale du worker comptait 296 tests. Bilan final parent sur l’arbre corrigé : analyse sans anomalie, **299 tests réussis**, **15 tests de capture réussis**, **32 captures lisibles**, builds debug galerie puis application réussis. L’APK courant correspond à l’application. Le placement des activités provisoires après l’historique et l’absence de réservation Otc supplémentaire sont également vérifiés.
