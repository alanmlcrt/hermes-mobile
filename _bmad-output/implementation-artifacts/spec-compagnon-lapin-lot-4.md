---
title: 'Compagnon lapin — présence pendant les réponses'
type: 'feature'
created: '2026-10-22'
status: 'done'
baseline_commit: '603c801f3a58cd65c6305bfc0028b610c2d31da5'
route: 'dispatch'
review_loop_iteration: 1
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

Afficher Otc près de la réponse Hermes, avec `RabbitCompanion` et le dessin v5 des lots précédents. Faire approuver les choix ci-dessous avant tout code.

## Boundaries & Constraints

Toujours : enveloppe stable, oreilles asymétriques, lisibilité compacte, texte sans chevauchement ni déplacement causé par les poses. `WorkStateLabel` reste l'autorité. Envoi, démarrage, réception de texte et terminal sont distincts. Aucun mouvement ne mesure une progression. Chatouilles locales sans effet sur la génération ; statut immédiatement actualisé, pose courante après réaction, sans fin différée.

Mouvement réduit et pause suppriment les mouvements autonomes ; chatouilles en pose fixe. Suspension hors écran, route masquée et arrière-plan ; retour à l'état courant sans rattrapage. Erreur, arrêt et inconnu ne produisent aucune réussite.

Jamais : nouvelle commande d'arrêt, contrat serveur, migration, dépendance, modification de l'anatomie ou du statut métier.

## I/O & Edge-Case Matrix

| Entrée | Résultat exigé |
| --- | --- |
| Soumission / acceptation | Aucun démarrage supposé |
| Démarrage / texte | Expressions distinctes selon décisions approuvées ; aucun battement par fragment |
| Terminal réel | Statut exact immédiatement ; succès uniquement confirmé |
| Coupure / reconnexion | Inconnu puis état restauré ; aucune animation historique |
| Travail changé pendant chatouilles | Statut immédiat, puis pose courante |
| Suspension / reprise | Aucun cycle suspendu ; aucune animation manquée rejouée |

## Décisions approuvées

Approbation utilisateur : « fait tout ce que tu recommandes » ; les quatre options A sont retenues.

1. Chorégraphie : concentration au démarrage confirmé, regard vers le texte reçu, face puis repos à toute fin ; envoi neutre, aucune boucle pendant le travail, aucune réaction spécifique de réussite. Reprise : refléter la pose de l'état courant sans transition historique.
2. Trois points : lapin seul, remplaçant leur intention dans l'ancienne UX. `WorkStateLabel` et les lignes d'activité restent présents.
3. Fond : surface neutre du thème ; aucune lecture supplémentaire du fond mémorisé du profil.
4. Placement : slot 64 px latéral si largeur utile ≥360 px et texte <150 %, sinon avant le texte. Slot dès l'acceptation, conservé après fin ; historique neutre, anciennes réservations conservées sans interactions dupliquées ; clavier sans changement de placement. Pause locale à la page.

</frozen-after-approval>

## Code Map

- `lib/data/event_mapping.dart`, `conversation_repository.dart` — événements et restauration ; `_ensureTurn` et `_fromHistory` empêchent de déduire la provenance depuis `running`/`succeeded` seuls.
- `lib/models/timeline.dart`, `lib/features/conversation/draft_view_model.dart` — projection et indicateurs de reprise ; aucun signal de terminal direct exposé.
- `lib/features/conversation/draft_view.dart` — intégration du dernier tour, réponses multiples possibles ; conserver défilement et statuts.
- `lib/ui/components/rabbit_companion.dart` — réutiliser dessin, réactions et suspension ; étendre les poses sans couplage réseau.
- `lib/ui/components/work_state_label.dart` — autorité inchangée.
- `investigation-compagnon-lapin-lot-4.md` — sources et propositions détaillées ; UX du 22 octobre et v5 inspectées.

## Tasks & Acceptance

- [x] `lib/models/timeline.dart`, `lib/data/conversation_repository.dart`, `lib/features/conversation/draft_view_model.dart` — exposer seulement les distinctions de présentation nécessaires ; séparer direct et restauration si réaction terminale retenue.
- [x] `lib/ui/components/rabbit_companion.dart`, nouveau `conversation_companion.dart` — poses, enveloppe et pause selon décisions.
- [x] `lib/features/conversation/draft_view.dart`, `lib/ui/tokens.dart`, `lib/ui/content.dart` — intégrer layout, tokens et textes accessibles ; injection du fond uniquement si retenue.
- [x] `lib/ui/gallery.dart` — scénarios pilotables de toute la matrice, dont transitions pendant chatouilles.
- [x] `test/conversation_companion_test.dart`, `rabbit_companion_test.dart`, `conversation_test.dart`, `resync_test.dart`, `gallery_test.dart` sous `test/` — vérifier événements, reprise, stabilité et sémantique.
- [x] `DESIGN.md`, `EXPERIENCE.md` du dossier UX du 22 octobre — enregistrer les décisions approuvées.

Étant donné 320/375 px, paysage, clavier ouvert et texte 200 %, quand les états et poses changent, alors texte, oreilles et commandes restent lisibles sans chevauchement ni saut dû au compagnon.

Étant donné un lecteur d'écran, quand le travail change ou le lapin est activé, alors le statut est annoncé sans doublon et « Chatouiller Otc » reste indépendant de la génération.

## Implementation Notes

- Clôture parent : tous les correctifs retenus des deux revues sont appliqués. Statut live déplacé hors liste paresseuse ; activités antérieures au premier accusé rapprochées sans tour fantôme ; snapshot de repli lorsque le rejeu garde sending malgré running confirmé. Le plafond de saisie dépend des contraintes réelles après clavier. Dix captures, nouveau golden 48/64 px, analyse, 270 tests et deux APK debug vérifiés. Voir `lot4-verification/final.md` pour les preuves et limites.

- `CompanionPhase` distingue présentation neutre, concentration et texte reçu, sans modifier `WorkState`. Ce champ n'est pas enregistré : la reprise reconstruit seulement la pose courante. Aucun signal de réussite directe n'est nécessaire, puisqu'aucune réaction de succès n'est retenue.
- Une réservation `ConversationCompanion` par tour regroupe les réponses et les activités. Seul le dernier tour possède une action ; les anciens carrés sont peints statiquement. La pause vit dans la page et sa commande se trouve dans le fil pour rester lisible à 200 %.
- La galerie propose des boutons manuels pour chaque état, le démarrage, le texte, la restauration et la suspension. Aucun scénario automatique ne simule une progression.

## Spec Change Log

- Revue 1 — préciser le rendu avant reconstitution : mesurer l'agrandissement à la taille réelle du texte de réponse (TextScaler non linéaire), orienter le regard vers le contenu en placement latéral/vertical et garder la pause accessible près du dernier tour. Grouper les éléments une seule fois et conserver la construction paresseuse entre blocs d'un tour. Corriger la restauration avec texte historique sans `partial`, et affecter les activités antérieures au démarrage au tour accepté. Galerie : conserver le texte aux terminaux, réception progressive manuelle, restauration annulant les réactions transitoires. Ajouter les preuves page complète dès acceptation, reprise en échec et clavier/200 %. KEEP : anatomie v5, champ de présentation non persistant, terminaux neutres, chatouilles indépendantes, suspension, enveloppe 64 px, contrats UX approuvés, tests existants verts, captures et builds déjà réussis. Version précédente conservée dans le dossier temporaire `hermes-lot4-preserved` pour réutiliser ces éléments positifs.

## Review Triage Log

| Constat | Verdict et traitement |
| --- | --- |
| B1 snapshot sans partial | medium, bad_spec : `_fromHistory` ignore le texte du tour contrairement à `_replay` ; reconstruire la même pose courante. |
| B2 échelle non linéaire | medium, bad_spec : `scale(1)` ne représente pas le corps de réponse ; tester une échelle non linéaire à la taille réellement utilisée. |
| B3 regard en placement vertical | medium, bad_spec : regard horizontal malgré texte dessous ; orienter vers le texte sans miroir des oreilles. |
| B4 construction du tour entier | medium, bad_spec : Column de tous les blocs remplace leur rendu paresseux ; conserver la paresse entre blocs longs. |
| B5 scans par tour | low, bad_spec : chaque tour rescane le fil ; grouper une fois pendant le rendu corrigé de B4. |
| B6 pause éloignée | medium, bad_spec : commande avant tout l'historique ; rapprocher du dernier compagnon, défilable et sans débordement. |
| B7 galerie efface réponse au terminal | medium, bad_spec : `_change` remet `_text` à false ; conserver le contenu reçu, y compris erreur/arrêt/inconnu. |
| B8 galerie restauration identique au direct | medium, bad_spec : ne suspend pas la réaction existante ; fixture de reprise distincte, sans rattrapage. |
| B9 tests de layout isolés | medium, bad_spec : 375 px composant ne représente pas 343 px après marges page ; tester DraftView complet, clavier et 200 %. |
| B10 harness Windows | low, rejeté : utilitaire manuel sur la machine disponible, chemins documentés comme au lot 3 ; portabilité CI hors usage quotidien, correction ajoute configuration sans bénéfice pour cette livraison. |
| V1 neutralisation de pose périmée | medium, bad_spec : lacune de régression pré-vérifiée ; page avec lecture périmée puis resynchronisation/échec/récupération. |
| V2 réservation dès acceptation | medium, bad_spec : lacune pré-vérifiée ; page avec seule demande puis démarrage/texte/fin, taille et position stables. |
| E1 snapshot sans partial | medium, bad_spec : même défaut que B1, historique courant contient du texte. |
| E2 activité avant démarrage | medium, bad_spec : ActivityItem rang 0 est trié avant demande rang 1 ; l'attacher au tour accepté en attente, sans créer un autre lapin. |

| Revue 2 | Verdict et traitement |
| --- | --- |
| B1 activité avant accusé / E1 | medium, patch : cas supplémentaire aux deux compteurs nuls ; rapprocher les activités de rang zéro de la première demande acceptée et éviter une réservation avant acceptation. |
| B2 demandes locales en file | false : `OutboxRepository.send` garde synchroniquement busy/turnActive ; les événements et l'acceptation maintiennent ce verrou, donc plusieurs demandes locales acceptées en avance ne sont pas atteignables par ce flux. |
| B3 sending restauré running sans start | medium, patch : le rejeu laisse sending lorsque la reprise confirme running sans événement frais ; utiliser le repli snapshot existant pour ce cas non résolu. |
| B4 statut démonté dans long fil | medium, patch : défaut déjà présent dans le fil paresseux mais révélé par la vérification lecteur d'écran ; maintenir l'unique WorkStateLabel hors de la liste défilante, près de la saisie. |
| B5 réservation vérifiée seulement en x | medium, patch de test : compléter par comparaison du rectangle complet dès acceptation, sans repositionnement du défilement. |
| B6 clavier testé sur pages neuves | medium, patch de test : tester ouverture/fermeture sur la même page et maintien de pause/pose/placement. |
| B7 captures sans commandes/focus | low, patch de preuve : compléter la capture avec pause/focus à 200 % et en paysage. |
| B8 restauration galerie uniquement running | low, rejeté : restauration de travail en cours est une fixture explicite ; les six boutons d'états montrent déjà les fins et l'inconnu, sans réaction de fin ; ajouter un sélecteur de toutes les restaurations complexifierait le démonstrateur sans défaut constaté. |
| B9 parcours clavier après nouveau tour | low, rejeté : les historiques sont peints sous ExcludeSemantics sans FocusNode ; seul RabbitCompanion courant porte l'action, déjà éprouvée par activation clavier et sémantique. Aucun défaut de focus démontré dans ce constat. |
| B10 suivi spec | low, rejeté selon règle du workflow sur les constats éditant la spec ; checklist et bilan seront actualisés à la clôture normale. |
| V1 poses nouvelles sans golden | low, patch : remarque partielle confirmée par lecture ; ajouter une référence raster des poses de travail aux tailles compactes. Le second réviseur de vérification a été interrompu par une limite d'usage avant son rapport complet ; audit de matrice et inspection des captures effectués par le parent. |

## Verification

Bilan final parent : 270 tests réussis ; captures de poses et commandes/focus inspectées, golden compact contrôlé ; analyse et builds finaux consignés dans lot4-verification/. Le statut live reste monté près de la saisie, sans doublon. Le plafond de la saisie utilise la hauteur réelle disponible (LayoutBuilder) ; matrice clavier réaliste 300 px en portrait et 160 px en paysage verte. Aucun constat retenu non résolu ; aucun travail différé. Limite : aucun appareil Android/iOS connecté, TalkBack/VoiceOver et clavier système réels non essayés. Les paragraphes suivants conservent les résultats intermédiaires datés par leur phase ; les mentions « à exécuter par le parent » y sont historiques.

Reprise après revue 1 : `flutter analyze --no-pub` sans problème ; les cinq fichiers ciblés passent avec **80 tests**, dont la matrice DraftView complète (320/375 px, paysage, clavier, clair/sombre, 100/200 %), le TextScaler non linéaire, le snapshot courant sans partial, les activités avant démarrage, la neutralisation en reprise/échec et la construction paresseuse de 60 blocs. La galerie conserve les fragments au terminal et une restauration annule immédiatement les chatouilles. Suite complète, builds et nouvelles captures confiés au parent ; aucun nouvel essai TalkBack/VoiceOver ou clavier sur appareil réalisé ici.

Implémentation : `flutter analyze --no-pub` sans problème ; 73 tests ciblés puis suite complète de 257 tests réussis sous Flutter 3.47.7. La suite inclut les cinq fichiers demandés, la comparaison golden v5 existante et le scénario galerie manuel. SDK : `C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat`, commandes préfixées par `rtk`.

Couverture de la matrice : soumission/acceptation et démarrage/texte dans `conversation_test.dart` (dont texte sans `message.start`) ; terminaux complet/erreur/arrêt/inconnu dans la table des terminaux ; coupure et restauration rejeu/snapshot dans `conversation_test.dart` et `resync_test.dart` ; changements pendant chatouilles dans `conversation_companion_test.dart` et `gallery_test.dart` ; suspension et pose courante dans `rabbit_companion_test.dart`. Layout clair/sombre 320/375 px, paysage, clavier et 100/150/200 % vérifié par widgets ; action unique et anciens tours neutres vérifiés avec plusieurs blocs.

Limites séparées : builds app/galerie et nouvelles captures visuelles restent à exécuter par le parent ; aucun essai réel TalkBack/VoiceOver ou clavier sur appareil n'a été réalisé par l'agent d'implémentation.

`flutter analyze`, tests ciblés puis suite complète, builds debug app/galerie. Captures clair/sombre/200 %, comparaison v5 ; essais de suspension, clavier et lecteur d'écran réel si appareil disponible. Consigner les limites séparément des tests sémantiques.
