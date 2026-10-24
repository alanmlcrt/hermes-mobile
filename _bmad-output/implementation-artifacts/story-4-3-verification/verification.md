# Story 4.3 — Vérification

La story téléverse les copies privées dans le scope connexion/profil/session figé, attend les accusés valides avant le prompt et distingue « téléversé » de « reçu dans la conversation ». Seule une preuve ajoutée par Hermes dans le bon message autorise ce dernier état. PNG est activé par `image.attach_bytes` ; JPEG reste bloqué jusqu’à mesure. Les copies sont conservées pour 4.4.

## Résultats

| Vérification | Résultat | Preuve |
|---|---|---|
| `flutter test --no-pub --reporter expanded` | 419 réussis, 17 ignorés préexistants | [Résumé de la suite](tests.log) |
| `flutter test --no-pub test/attachment_send_test.dart --reporter expanded` | 25 réussis, aucun ignoré | [Journal des scénarios](target.log) |
| `flutter test --no-pub test/attachment_send_test.dart test/attachment_flow_test.dart test/resync_test.dart` | 59 réussis | Exécuté après les corrections, puis repris dans la suite complète |
| `flutter analyze --no-pub` | Aucune anomalie | [Analyse](analyze.log) |
| `flutter build apk --debug --no-pub` | APK compilé | [Compilation](build.log) |
| `flutter test --no-pub test/support/attachment_status_capture.dart` | Réussi, quatre captures | [Générateur](../../../test/support/attachment_status_capture.dart) |
| `git diff --check` | Réussi | Contrôle avant commit |

SDK utilisé : Flutter 3.47.7. APK : `build/app/outputs/flutter-apk/app-debug.apk`.

## Matrice et régressions

Les scénarios ci-dessous figurent dans [attachment_send_test.dart](../../../test/attachment_send_test.dart) et ont tous été exécutés sans exclusion.

| Ligne de matrice | Tests couvrants |
|---|---|
| Succès | `success: scoped references in prompt, receipt only from server history` : le récepteur vérifie les octets décodés, le MIME, le nom, la session, le profil et l’absence de chemin local pour les deux transports ; prompt avec références ; prochaine demande sans anciennes pièces |
| Refus | `partial refusal keeps success and draft; explicit retry reuses success` ; copie et texte conservés, aucun prompt ; succès réutilisé lors du nouvel essai explicite |
| Incertain | `invalid response is uncertain and never prompts or retries itself` ; `socket loss during upload is uncertain and never prompts` ; référence image invalide et erreur serveur interne |
| Partiel | Succès puis refus, deux tentatives persistées séparément, seul l’échec est renvoyé |
| Redémarrage | `restart changes in-flight upload to uncertain` : aucune répétition automatique ni réception inventée |
| Isolation | Profil choisi ailleurs sans changement de cible ; changement de connexion ou de génération entre pièces arrête le pipeline |
| Vision | JPEG bloqué avant session/upload ; libellé de vision conditionnel, aucune analyse promise |

Régressions supplémentaires : collisions de références PNG/PDF ; ancien message identique sans ligne courante ; session déjà active sans upload ; échec de lecture avant prompt ; commit local d’acceptation refusé ; réponse de soumission perdue puis rapprochée ; nom d’une pièce seule visible ; preuve différée à la fin du tour sans renvoi. Le parcours page réelle → bouton Réessayer → view model → repository → envoi est exécuté.

## Interface

Le contrôle à 200 % a révélé un débordement de 125 px sur 375 px. Les actions utilisent maintenant un retour à la ligne avec les espacements existants. Les tests couvrent clair/sombre, portrait 375 × 812 et paysage 812 × 375, mouvement réduit et cibles d’au moins 44 px. Les états sont du texte annoncé et ne dépendent pas de la couleur.

Captures inspectées :

- [Clair, états à 100 %](captures/etats-light-1x.png)
- [Sombre, états à 100 %](captures/etats-dark-1x.png)
- [Clair, nouvel essai à 200 %](captures/etats-light-2x.png)
- [Sombre, nouvel essai à 200 %](captures/etats-dark-2x.png)

## Orchestration et revue

Coordination via le skill `orchestration`, Run `run_a0f8331f476e`.

| Tâche | Modèle | Résultat et preuve |
|---|---|---|
| Implémentation `task_87f486b0d762` | GPT-6 Sol, high | Réussie, Dispatch `ctx_6bb2c2900192`, livraison initiale avec 405 tests ; corrections ensuite appliquées par le coordinateur |
| Défauts `task_d70348399388` | GPT-6.1 Sol, high | Réussie, 9 constats ; sondes de régression ; lignes B1–B9 du triage |
| Cas limites `task_a64c368b8eac` | GPT-6.1 Sol, high | Réussie, 5 constats ; lignes E1–E5 |
| Lacunes de vérification `task_fe18a291c7ed` | GPT-6.1 Sol, high | Réussie, 3 lacunes et 1 défaut ; lignes V1–V4 |

Chaque constat a été vérifié et consigné dans la [spec](../spec-4-3-envoi-reception-fichiers.md). Corrections locales appliquées et vérifiées ; aucun élément différé. Les quatre workers ont été libérés et aucun terminal ne reste à récupérer.

## Limites de la validation

Les échanges sont exécutés contre un récepteur de test, pas contre une installation Hermes réelle pendant cette story. L’essai sur appareil avec le sélecteur natif et la réception réelle reste à réaliser. Une preuve distante absente garde le libellé « téléversé, réception à vérifier » ; sa relecture à la fin du tour ou après rapprochement n’entraîne aucun renvoi. La mesure du profil de test n’est pas extrapolée aux capacités d’analyse des autres profils.
