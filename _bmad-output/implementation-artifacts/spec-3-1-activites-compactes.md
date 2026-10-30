---
title: 'Story 3.1 — Voir les activités en lignes compactes'
type: 'feature'
created: '2026-10-22'
status: 'done'
baseline_commit: 'f7e4b1ab53f6882d0d128003cbcf95515c9d36ab'
route: 'dispatch'
review_loop_iteration: 1
context:
  - 'C:/Users/alanc/.codex/RTK.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/investigation-epic-3-activites.md'
---

<frozen-after-approval reason="intention utilisateur — modification après approbation uniquement sur décision humaine">

## Intent

Afficher chaque activité reçue dans le fil sans fusionner des actions distinctes : ligne courte, emplacement d’illustration, fin uniquement attestée, groupe consécutif repliable au passage à la réponse. Commencer par 3.1 ; traiter ensuite 3.2 à 3.5 séparément.

## Boundaries & Constraints

**Toujours :** réutiliser `ActivityLine`, thème, tokens et galerie. `WorkStateLabel` reste l’unique autorité du travail. Préserver les quatre lots Otc : anatomie, fonds, pause, chatouilles, suspension, placement et construction paresseuse du fil. Aucun retour des points de préparation remplacés par Otc.

Identité d’action : connexion/profil/session + tour + `tool_id` opaque. Famille issue du mapping, jamais d’un emoji ou d’une supposition sur un nom MCP. Une fin d’outil n’est ni une réussite ni une fin de travail. Champs absents : aucune inférence. Contrat documentaire et fixtures ne valent pas validation de l’installation.

**Jamais :** détails dépliables d’action (3.2), nouvelles animations/catalogue (3.3–3.4), commande d’arrêt (3.5), progression, raisonnement privé, migration destructive, réseau depuis la vue. Aucun appel Hermes causé par un repli ou une reconstruction.

## I/O & Edge-Case Matrix

| Entrée | Résultat exigé |
| --- | --- |
| Deux outils de même famille, IDs distincts | Deux actions, ordre reçu conservé |
| Début puis fin de même ID | Une action mise à jour ; aucune réussite supposée |
| Fin sans début | Action attestée par la fin, aucun début inventé |
| ID absent / événement inconnu | Entrée générique conservée ; aucune association par nom ou proximité |
| Doublon de séquence / rejeu | Pas de duplication ; identités isolées par tour et contexte |
| Réponse sans fin d’outil | Aucune fin déduite du texte ou du terminal du tour |
| Ancienne projection sans métadonnées | Lecture compatible, activité générique sans fin supposée |
| Reprise par historique sans outils | Ne pas reconstruire d’actions imaginées ; limitation explicite |

## Décisions UX approuvées

Alanc : « tout ce qui est recommandé ».

1. Repère neutre et texte visible « Fin reçue », avec libellé accessible. Aucun vert de réussite ni « Terminé » concurrent du statut du travail.
2. Au premier texte reçu après un groupe d’au moins deux activités consécutives (`message.delta` ou `message.interim` non vide), replier en « N activités », en indiquant combien restent sans fin confirmée. Conserver le choix manuel pendant les mises à jour et ne jamais déplacer automatiquement le focus.

</frozen-after-approval>

## Code Map

- `lib/models/timeline.dart` : enrichir `ActivityItem`, introduire `ActivityKind` typé et désérialisation compatible ; ne pas changer `WorkState`/`CompanionPhase`.
- `lib/data/event_mapping.dart`, `contracts/event-mapping.json` : distinguer début/fin, familles `tool`/`unknown` seulement. Sources et limites dans l’investigation.
- `lib/data/conversation_repository.dart` : `_reduce`, `accepted`, `_apply`, rejeu/snapshot ; préserver les métadonnées au rattachement du tour zéro, les curseurs et la sérialisation.
- `lib/ui/components/activity_line.dart`, `status_label.dart` : base existante générique ; `draft_view.dart::_timeline` intègre les groupes dans les blocs paresseux d’Otc.
- `lib/ui/content.dart`, `tokens.dart`, `gallery.dart` : textes, dimensions et scénarios de présentation centralisés.

## Tasks & Acceptance

- [x] `contracts/README.md`, `capabilities.json`, `fixtures/tool-*.json`, `test/contracts_test.dart` : documenter les champs vérifiés dans la source, fixtures explicitement synthétiques, disponibilité réelle non vérifiée.
- [x] `timeline.dart`, `event_mapping.dart`, `event-mapping.json`, `conversation_repository.dart` aux chemins ci-dessus : identité, phase et conservation générique ; tests `event_mapping_test.dart`, `conversation_test.dart`, `resync_test.dart` pour toute la matrice, persistance et isolation comprises.
- [x] `activity_line.dart`, nouveau `lib/ui/components/activity_group.dart`, `draft_view.dart`, `content.dart`, `tokens.dart` : lignes statiques, groupe et choix approuvés ; slot 24 px, texte multiligne, commandes 48 px, état de dépliage local indexé par identité stable.
- [x] `lib/ui/gallery.dart`, `test/gallery_test.dart`, nouveau `test/activity_line_test.dart` : scénarios manuels début/fin, IDs distincts, inconnu, fin absente, réponse et repli ; clair/sombre, 320/375 px, paysage, clavier, texte 200 %, mouvement réduit et sémantique/clavier.
- [x] Dossier UX du 20 octobre, `DESIGN.md` et `EXPERIENCE.md` : consigner les décisions approuvées sans modifier les contrats Otc.

Étant donné un groupe reconstruit pendant une réponse, quand de nouveaux fragments arrivent, alors le choix manuel de dépliage et le focus restent stables sans appel réseau.

Étant donné petit écran, clavier ouvert et texte agrandi, quand on parcourt les activités et leur synthèse, alors libellés et commandes restent lisibles et atteignables ; le lecteur d’écran annonce repli/dépliage et fin d’action sans doubler le statut du travail.

## Implementation Notes

Approbation complète : « approuver et continuer. tu peux faire toute la storie ». L’implémentation possède les fichiers de cette story ; le coordinateur conserve la responsabilité de la revue finale. Travail partagé : préserver les modifications d’autrui. Exécution séquentielle, aucun push ni opération distante.

Après revue, patches parent : les activités provisoires sont normalisées avant le démarrage et l’acceptation, y compris au tour suivant ; elles restent après l’historique, sans réservation Otc anticipée. La corrélation vérifie l’epoch d’origine, ou la génération en l’absence d’epoch, porté par la clé d’événement persistée. Les tests couvrent les deux courses d’accusé et la reprise échouée après changement d’epoch. La conversation complète vérifie désormais aussi le texte et la sémantique de fin ; la galerie désactive les ajouts après réponse jusqu’à Recommencer. Aucun statut métier, API publique ou contrat Otc modifié par ces patches.

## Spec Change Log

## Review Triage Log

| Constat | Verdict, preuve et traitement |
| --- | --- |
| B1 — début avant accusé, démarrage puis fin | medium, patch : `_startTurn` laisse le début au rang zéro ; la fin crée une autre ligne. Normaliser le provisoire avant corrélation ; régression de cet ordre exact. |
| B2 — activité du tour suivant avant accusé | medium, patch : après un terminal, `max(turns,userTurns)` désigne encore l’ancien tour et un ID réutilisé peut reprendre sa fin. Garder les débuts sans acceptation au rang provisoire zéro ; rattachement avant démarrage/acceptation. Aucun nouveau statut du travail. |
| B3 — corrélation entre epochs | medium, patch : une reprise réussie remplace les activités, mais si l’historique échoue après le changement de binding, les anciens IDs restent affichés. Des événements du nouvel epoch peuvent alors hériter de leurs fins. Vérifier le contexte d’origine porté par la clé d’événement avant toute corrélation ; tester un redémarrage suivi d’un échec de snapshot. |
| B4 — focus lors du changement Row/Column Otc | low, rejeté : un changement de largeur/échelle peut recréer le bouton, immédiatement refocalisable, sans perte de choix ni de contenu. Le scénario quotidien demandé couvre les mises à jour du fil, déjà testé ; préserver un FocusNode à travers ce changement demanderait une API ou un mécanisme de reparentage supplémentaire. |
| B5 — position de lecture lors du repli | low, rejeté : retirer les lignes peut déplacer la position dans ce groupe, conséquence du repli automatique approuvé ; les contenus hors groupe restent dans le fil et la réponse devient visible. Une compensation d’ancrage ajoute un comportement non requis, au-delà d’une correction directe. |
| B6 — recherche linéaire des clés | low, rejeté : le callback parcourt les entrées pour les enfants effectivement montés du ListView paresseux. Aucun ralentissement quotidien démontré ; ajouter un index secondaire dépasse une correction directe utile ici. |
| B7 — galerie ajoute une activité après réponse | low, patch : la démo la range dans le groupe déjà replié, contrairement au fil réel. Désactiver les ajouts après réponse jusqu’à Recommencer ; les fins restent pilotables. |
| B8 — chemins de capture propres à cette machine | low, rejeté : scripts manuels locaux comme les lots précédents ; les tests ordinaires ne chargent pas ces polices. Une configuration de portabilité ajoute une surface hors usage quotidien ; limites documentées. |
| B9 — absence de TalkBack/VoiceOver réel | false quant à un défaut de livraison revendiquée : le rapport sépare explicitement sémantique/clavier Flutter et essais mobiles absents. `flutter devices --machine` ne trouve aucun téléphone ; aucun succès réel n’est déclaré. |
| B10 — installation non observée | false quant à l’usage des fixtures comme preuve réelle : README, capacités et rapport déclarent `actual=unverified`, les fixtures synthétiques et l’absence de contact avec le backend privé. Aucun contournement ni disponibilité réelle affirmée. |
| E1 — doublon au rattachement pré-acceptation | medium, patch : même séquence reproduisible que B1 ; normaliser les activités provisoires avant le démarrage et conserver leurs métadonnées. |
| V1 — marqueur de fin non vérifié au point d’intégration | medium, patch : le test de composant ne couvre pas l’argument `completed` de DraftView. Ajouter au test de conversation existant les assertions de texte et de sémantique sur une action finie et une action sans fin. |

Groupement : B1/B2/E1 ont pour cause commune l’attribution des activités provisoires ; correction privée bornée aux états démontrés, sans nouvelle API. B3, B7 et V1 sont trois patches indépendants. Aucun arbitrage d’intention nouveau ni travail différé.

## Verification

SDK Flutter 3.47.7 existant, commandes via `rtk proxy` : analyse, tests ciblés ci-dessus puis suite complète ; builds debug app/galerie. Inspecter captures de la matrice et régressions des quatre lots Otc. Distinguer tests sémantiques de TalkBack/VoiceOver réels et disponibilité documentaire d’observation réelle ; consigner toute limite sans déclarer ces essais réussis.

Vérification locale du 22 octobre : analyze propre, 296 tests réussis, builds debug application/galerie réussis, 32 captures lisibles inspectées. Preuves et limites : [rapport de vérification](story-3-1-verification/rapport.md). TalkBack/VoiceOver réels et disponibilité des événements sur l’installation personnelle restent non vérifiés ; revue finale à la charge du coordinateur.

Après les correctifs de revue (B1/B2/E1, B3, B7, V1) : analyze propre, 299 tests réussis (rejoué le 22 octobre), builds debug application/galerie et captures régénérés.
