# Story 3.2 — remise d’implémentation

**État ultérieur :** voir [l’audit du coordinateur](audit-coordinateur.md). L’arbitrage du premier fragment a été approuvé et corrigé. Les vérifications finales passent : analyse, 308 tests (`tests.log`), matrice DraftView (`captures.log`), 24 captures et deux builds Android debug. Les résultats ci-dessous décrivent la remise initiale du worker ; la revue indépendante suit.

Spec : `../spec-3-2-details-action.md` (source de vérité, corps approuvé inchangé).
Contexte chargé intégralement : RTK et investigation-3-2-details-action.md.
Base annoncée par la spec : `98a64891da7672ca3c8c4110370f3ad404a4fdae`.

## Résultat

- La projection conserve uniquement name/context/args/args_text/preview/result/
  result_text/inline_diff reçus sur tool.start/tool.complete. Une fin fusionne
  les champs présents ; null retire un champ ; false, 0, listes et objets restent
  disponibles. Les champs textuels mal typés sont ignorés. Les copies correctives
  et la sérialisation conservent les détails sans table ni migration.
- Les identités, phases et corrélations de 3.1 sont conservées. Un événement sans
  ID reste indépendant ; le fallback inconnu ne décode aucun détail. Aucun
  rapprochement par nom, aucune interprétation des événements de raisonnement.
- Une ligne avec contenu devient une commande native entière de 48 px minimum,
  avec chevron, focus clavier et état annoncé sur le même nœud sémantique.
  Sans contenu consultable elle reste statique. L’état individuel appartient à
  DraftView, indexé par la clé du brouillon et eventKey, séparé du choix du groupe.
- Le corps est du texte/JSON sélectionnable et défilant dans les deux axes.
  Les données structurées priment sur le secours serveur ; aucune coupe locale,
  aucun lien exécuté, aucun RPC. Seul result.error chaîne non vide produit Erreur,
  sans modifier le statut global. Les marqueurs serveur restent visibles.
- Le suivi automatique de la fin du fil ne se déclenche plus lors d’un simple
  dépliage local : la commande ouverte reste à sa position. Les arrivées de
  projection continuent à suivre le bas si le lecteur y était déjà.
- Galerie, fixtures synthétiques, contrat documentaire et décisions UX des
  dossiers du 20 et 22 octobre mis à jour.

## Vérifications

Flutter **3.47.7**, via `rtk proxy`, sans installation réelle contactée.

| Vérification | Résultat / preuve |
| --- | --- |
| Analyse finale | `analyze.log` |
| Tests ciblés initiaux | 103 réussis (conversation, resync, activity_line, gallery, contracts) |
| Suite complète | **305 réussis**, `full-tests.log` |
| Après derniers ajouts de reset galerie et isolation epoch | **36 réussis**, `final-targeted.log` |
| DraftView réelle avec fakes locaux | **12 combinaisons réussies**, `draft-matrix.log`, `test/support/details_capture.dart` |
| App Android debug | Réussi, `build-app.log` |
| Galerie Android debug | Réussi, `build-gallery.log` |

La matrice couvre 320/375 px et paysage 812×375, clair/sombre, texte 200 %,
mouvement réduit, avec/sans inset clavier simulé. Elle ouvre au clavier, garde le
focus lors de l’enrichissement de fin, contrôle l’état sémantique, replie/réouvre
le groupe puis l’action, vérifie l’absence d’envoi, de rechargement et de trame
Hermes, et atteint horizontalement la fin de la sortie longue.

`captures/` contient 24 PNG lisibles avec polices locales : douze vues de la
commande ouverte et douze de la sortie à son extrémité avec `[truncated]`.
Inspection visuelle effectuée sur les vues clair 320 px et sombre paysage avec
clavier, ainsi que sur la sortie 320 px. En paysage avec clavier, le fil visible
est court et se consulte par défilement ; cela ne constitue pas une coupe des
données reçues. Les autres combinaisons sont vérifiées par les assertions et
conservées pour la revue.

## Limites et reprise par le coordinateur

Aucun développement connu laissé incomplet. La revue indépendante et la clôture
de la spec appartiennent au coordinateur ; aucun commit ni push effectué.
Les captures sont des tests de widgets sur la vraie DraftView avec données
synthétiques et clavier simulé : aucun téléphone physique, TalkBack/VoiceOver
réel, clavier système ou disponibilité effective des champs sur l’installation
Hermes n’est validé. Les snapshots textuels sans outils restent sans détails et
les textes serveur peuvent déjà être expurgés/tronqués.

Une première vérification sémantique a révélé une séparation du nœud de statut et
du nœud dépliable, corrigée et retestée. Une tentative de lancement simultané de
deux commandes Flutter a rencontré le verrou Windows sqlite3.dll ; les commandes
ont ensuite été exécutées séquentiellement et ont réussi.
