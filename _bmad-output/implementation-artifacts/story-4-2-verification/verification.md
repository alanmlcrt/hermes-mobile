# Vérification de la story 4.2

Version finale du 24 octobre 2026, après corrections de revue.

- `flutter test --reporter expanded` : 393 tests réussis, 17 ignorés ; sortie complète dans [final-tests.txt](final-tests.txt).
- `flutter analyze` : aucun problème ; [final-analyze.txt](final-analyze.txt).
- `flutter build apk --debug` : compilation réussie ; [final-build-apk.txt](final-build-apk.txt). APK local : `build/app/outputs/flutter-apk/app-debug.apk`.
- Captures inspectées : [clair](captures/composer-light-375.png), [sombre](captures/composer-dark-375.png), composer 375 px avec aperçu PNG, PDF, retrait et blocage explicite.

## Audit de la matrice

| Ligne | Preuve exécutée |
|---|---|
| Acceptée | `attachment_store_test` : PNG, JPG, JPEG, PDF, quatre pièces ordonnées ; copie depuis chemin réel et source supprimée ; `attachment_flow_test` : aperçu privé et repli de décodage. |
| Refus taille | `file_limits_test` : borne exacte puis +1 octet pour chaque catégorie ; `attachment_store_test` : aucun fichier privé créé ; `attachment_flow_test` : raison avec taille limite. |
| Refus type | `file_limits_test` : HEIC/GIF/ZIP refusés ; `attachment_flow_test` : type refusé nommé. |
| Retrait | `attachment_store_test` : ligne et copie supprimées, erreur filesystem et refus SQLite conservent la pièce ; `attachment_flow_test` : action nommée et disparition de la ligne. |
| Redémarrage | `attachment_store_test` : réouverture de SQLite et du repository, même ordre, copie absente signalée, contenu indépendant de la source. |
| Permission | `attachment_picker_test` : vraie traduction de l'adaptateur à la frontière plateforme ; `attachment_flow_test` : erreur annoncée et brouillon conservé. |
| Envoi avec pièces | `attachment_store_test` : aucun RPC ni opération, texte et pièces conservés ; ajout en vol attendu avant blocage ; `attachment_flow_test` : blocage depuis le viewmodel. |

Les tests de composants passent aussi en 375×812 et 812×375, texte 200 %, deux thèmes et mouvement réduit. Réassignation d'un brouillon contenant seulement des pièces couverte. La galerie et les garde-fous d'architecture/tokens passent dans la suite complète.

## Revue

Trois couches indépendantes : recherche aveugle, cas limites et lacunes de vérification. Chaque constat est trié dans la spec. Corrections retenues appliquées et revérifiées ; aucune entrée différée.

Limites de vérification : pas de manipulation du sélecteur sur téléphone réel ni test TalkBack/VoiceOver. Les tests de permission et d'annulation utilisent la frontière plateforme simulée. La sélection est locale : ni téléversement ni réception JPEG serveur ne sont validés ici (story 4.3).
