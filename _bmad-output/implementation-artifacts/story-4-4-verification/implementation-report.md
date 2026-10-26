# Story 4.4 — Preuves d’implémentation

Date : 26 octobre 2026. Revue terminée, constats retenus corrigés.

## Changements

Les pièces structurées sont rattachées aux bulles par scope connexion/profil/session et identité d’opération ou de ligne exacte. Les anciennes projections JSON restent lisibles ; aucun chemin privé n’est restauré depuis JSON. L’hydratation intervient au chargement, à l’acceptation et au rapprochement, sans accès aux pièces à chaque fragment de réponse.

La migration additive 13 ajoute `cleaned` aux pièces et `receipt_row_id` aux instantanés. Les métadonnées restent conservées après nettoyage. La preuve individuelle et sa ligne sont persistées ensemble avant suppression ; les erreurs de suppression et interruptions permettent une reprise idempotente. Les anciens états `received` de 4.3 nécessitent une nouvelle preuve.

Les cartes existantes apparaissent dans leur bulle. Les nouvelles demandes conservent leur texte original. Les aperçus privés possèdent un libellé accessible et un repli nom/type. Aucun téléchargement, ouverture ou exécution automatique.

## Vérification initiale

Commandes via RTK et SDK `C:\Users\alanc\fvm\versions\3.47.7\bin\flutter.bat`, toutes sorties zéro.

| Arguments Flutter | Résultat | Preuve |
| --- | --- | --- |
| `test --no-pub test/attachment_history_test.dart test/attachment_send_test.dart test/resync_test.dart test/attachment_store_test.dart test/attachment_flow_test.dart` | 79 réussis | `flutter-targeted.log` |
| `test --no-pub` | 431 réussis, 17 ignorés | `flutter-test.log` |
| `analyze --no-pub` | Aucune anomalie | `flutter-analyze.log` |
| `build apk --debug --no-pub` | APK compilé | `flutter-build-apk.log` |
| `test --no-pub test/support/attachment_history_capture.dart` | 1 réussi, 6 PNG | `flutter-captures.log` |

`rtk git diff --check` réussit. Aucun commit créé. Les captures préexistantes de la story 3.5 régénérées par la suite globale ont été restaurées.

## Correspondance matrice et tests réussis

| Scénario | Couverture |
| --- | --- |
| Réouverture, nom/type/état | `partial receipt cleans only its own copy; durable names and states survive restart` ; `conversation reopened from stored projection renders attachments inside their message` |
| Image et repli absent/corrompu | `unconfirmed image restores its validated private path across restart` ; `aperçu privé et repli nom/type si décodage impossible` |
| Preuve individuelle avant suppression | `success: scoped references in prompt, receipt only from server history` ; `receipt transaction failure never deletes bytes` ; collisions de préfixes PDF/PNG |
| Partiel ou ambigu | Test de réception partielle ; `multiple fresh rows cannot be disambiguated by matching prompt text` |
| Redémarrage et reprise | `failed deletion retains metadata and retries after restart without submitting again` ; `interruption after deletion before cleanup flag is idempotent` |
| Isolation et brouillon courant | `same row and name in other connection, profile or session never hydrate` ; `deferred receipt never cleans a same-name attachment in the current draft` |
| Compatibilité 4.3 | `version 12 migration retains historical metadata and requires fresh cleanup proof` ; `4.3 received records require a new exact proof before cleanup` ; JSON/withRow |
| Demande suivante sans renvoi | Test partiel après redémarrage ; tests existants de réponse perdue, commit échoué et preuve différée |
| Noms longs, 200 %, mouvement réduit | Tests `attachment list and sheet ... text 200% reduced motion`, portrait/paysage et clair/sombre |

## Inspection visuelle

Six captures avec Inter, texte à 200 %, mouvement réduit et page `DraftView` complète. Portrait clair/sombre et paysage haut/bas : noms, types et états lisibles, retours à la ligne, aucun débordement horizontal. Le paysage défile verticalement.

Captures : `captures/history-{light,dark}-375-200.png`, `captures/history-{light,dark}-812-200.png`, `captures/history-{light,dark}-812-200-top.png`.

## Vérification après revue

Les corrections et régressions couvrent le rafraîchissement sans ligne initiale, la réception différée dans le cache ouvert, les erreurs de chemin et de lecture privée, les copies nettoyées sans fournisseur de chemin, les échos PNG répétés, les références partagées, les changements de génération et de connexion pendant hydratation, et la réouverture de deux messages avec repositories réels et SQLite durable.

- 53 tests ciblés des premières corrections réussis : `review-fixes-targeted.log`.
- 45 tests de reprise et historique réussis après correction de la garde de connexion : `resync-scope-fix-targeted.log`.
- Suite complète finale : **442 réussis, 17 ignorés**, code de sortie 0 : `final-test.log`.
- Analyse finale : aucune anomalie, code de sortie 0 : [résultat](final-analysis-result.md).
- Compilation finale `flutter build apk --debug --no-pub` : code de sortie 0, APK produit dans `build/app/outputs/flutter-apk/app-debug.apk` (36,7 secondes).

## Limites finales

Vérifications avec passerelle synthétique et SQLite local, sans essai sur Hermes réel. Une preuve absente ou ambiguë conserve les copies. Aucun contrat de téléchargement ou d’ouverture ajouté.
