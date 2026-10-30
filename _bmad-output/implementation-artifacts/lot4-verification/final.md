# Vérification du lot 4

22 octobre 2026 — Flutter 3.47.7, Windows. Décisions A1–A4 approuvées avant codage ; aucun champ serveur, migration ni dépendance ajoutés.

## Résultats finaux

- Suite complète : **270 tests réussis**, dont goldens existants et nouveau `rabbit_work_poses.png` inspecté. Voir `flutter-test.log`.
- Analyse finale et APK debug application/galerie : journaux séparés dans ce dossier.
- Dix captures inspectées dans `../lot4-visuals/` : clair/sombre, 320/412 px, 100/200 %, plus commandes et focus en portrait/paysage à 200 %. Anatomie v5 conservée ; regard latéral ou vertical selon le placement.
- Revue : deux passes indépendantes, corrections retenues appliquées. Le second réviseur des lacunes de vérification a atteint sa limite d'usage après une remarque partielle ; le parent a terminé l'audit de matrice et l'inspection des preuves. Aucun constat retenu restant ni travail différé.

## Matrice exécutée

| Exigence | Preuve |
| --- | --- |
| Envoi distinct du démarrage | Tests de projection et page ; activités avant accusé et avant start, aucune concentration supposée |
| Texte progressif | Fragments cumulés, texte sans start ; fixture galerie pilotable manuellement |
| Réussite, erreur, arrêt, inconnu | Table des terminaux réels ; toutes les poses terminales neutres |
| Coupure et reconnexion | Tests resync : rejeu, snapshot, texte historique sans partial, sending confirmé running, échec/récupération |
| Changement pendant chatouilles | Tests composant et galerie ; statut immédiat, pose courante ensuite, aucune fin différée |
| Réservation stable | Rectangle complet depuis acceptation sans réponse jusqu'au terminal, sans rescroller |
| Petit écran, paysage, clavier, texte agrandi | DraftView complet 320/375 px et 812×375, clair/sombre, 100/200 %, clavier simulé 300/160 px ; ouverture/fermeture sur même page avec pause conservée |
| Suspension et mouvement réduit | Tests RabbitCompanion existants et nouveaux, état courant au retour sans rattrapage |
| Accessibilité | Action sémantique/clavier, historique sans action dupliquée, statut live unique monté hors liste paresseuse, focus inspecté |
| Long fil | 60 blocs avec construction paresseuse ; statut conservé pendant lecture loin de la fin |

## Limites

Aucun appareil Android/iOS connecté (`flutter devices` : Windows, Chrome, Edge). TalkBack/VoiceOver réels et clavier système réel non essayés ; les tests Flutter vérifient la sémantique et les insets simulés. Les captures sont produites par un harness local Windows, pas par un appareil de production. Les wrappers Python de journalisation ont échoué à imprimer des caractères Unicode dans la console Windows après la réussite des outils ; le journal Flutter contient bien `All tests passed!`, et les codes retournés par analyse/build app/build galerie sont tous zéro.
