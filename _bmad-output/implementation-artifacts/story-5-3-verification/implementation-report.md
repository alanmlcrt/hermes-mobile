# Implémentation 5.3 — 27 octobre 2026

La spécification approuvée et ses trois fichiers `context` ont été chargés avant
l’implémentation. Les contrats canoniques et leurs copies serveur restent identiques.

## Changements

- Migration SQLite additive : configuration par connexion, clé opaque de 192 bits
  par opération, association durable opération/profil/session stockée/session
  soumise/exécution, état de suivi et révocation différée. Aucun bearer ou token
  FCM dans ces tables ; credential observateur distinct dans le stockage sécurisé.
- `NotificationRepository` : HTTPS authentifié sans redirection, trois tentatives
  maximum avec backoff et jitter, budget global réseau de quatre secondes par
  préparation/attache (token inclus), requêtes annulables et réponses de santé
  bornées. Reprise depuis les opérations acceptées, rotation et révocation distante
  reprises à l’ouverture ; une reconfiguration ne remplace pas un credential tant
  qu’une révocation distante reste en attente.
- L’outbox prépare le suivi avant `prompt.submit`, attache uniquement après une
  confirmation ou un rapprochement certain et conserve le runtime réellement
  soumis, même si la reprise retourne un runtime différent. Aucun renvoi ajouté.
  Une panne observateur ne transforme pas un envoi accepté en échec. Le tour
  affiche « Notification non suivie » après restauration de sa projection.
- Firebase Messaging 17.0.1/Core 5.1.0 résolus sans repli. Initialisation facultative,
  permission explicite, token réel uniquement, réception au premier plan avec
  libellés génériques reconstruits, canal et icône Android. Arrière-plan : bloc
  notification FCM contractuel. Plugin Google Services conditionnel au fichier
  client privé. Aucun routage au toucher ajouté.
- Réglages existants : configuration HTTPS/credential, activation, désactivation,
  santé observateur distincte, explications permission/services Google/batterie/
  arrêt forcé et reprise des révocations. Champs nommés, credential masqué,
  erreurs génériques et mise en page défilante.
- Transport FCM HTTP v1 personnel : compte de service hors dépôt, OAuth renouvelable,
  délais de huit secondes, lecture des erreurs limitée à 16 Kio, exceptions masquées,
  classification transitoire/permanente et `UNREGISTERED`. Réutilisation du dispatcher,
  de sa rétention et de ses compteurs. Intégration toujours verrouillée en dry-run.
- Add-on HA : montage `share` en lecture seule et chemin privé documenté
  `/share/hermes-notifier/service-account.json`. Support de
  `GOOGLE_APPLICATION_CREDENTIALS` hors Supervisor. Documentation, exclusions Git
  et CI sans configuration Firebase réelle mises à jour.

## Vérifications exécutées

| Vérification | Résultat |
|---|---|
| `flutter pub get` avec Flutter 3.47.7/Dart 3.13.5 | Firebase 17.0.1/Core 5.1.0 résolus, lockfile mis à jour |
| `flutter analyze --no-pub` après dernières modifications | Aucune anomalie, 3,5 s |
| `flutter test --no-pub` — suite générale | 475 réussis, 17 ignorés, 64 s ; voir `flutter-test.log` |
| Tests ciblés notifications/réglages/send après durcissement deadline | 33 réussis |
| Dernière passe `notification_repository_test.dart` | 6 réussis ; serveur silencieux, runtime changé après reprise, révocation entre réouvertures inclus |
| `notification_settings_test.dart` | 4 réussis : 375×812 et 812×375, texte 200 %, clair/sombre, mouvement réduit et semantics |
| `flutter build apk --debug --no-pub` sans `google-services.json` | APK compilé ; dernière passe 25,2 s, voir `android-build.log` |
| `python -m unittest discover -s server/notifier/tests -t server/notifier` — suite générale | 125 réussis, 63,407 s ; voir `notifier-test.log` |
| Dernière passe `test_fcm.py` | 5 réussis ; réseau Google simulé, trois issues, erreurs OAuth/FCM, chargement d’une clé RSA synthétique créée uniquement dans un répertoire temporaire |
| `python server/notifier/sync_contracts.py --check` | Contrats byte-identiques |
| `git diff --check` | Aucune erreur |

Les suites générales précèdent les derniers durcissements ciblés ; ces changements
ont ensuite été vérifiés par analyse et les tests ciblés correspondants.
Les commandes Flutter utilisent le SDK FVM local, absent du PATH global.
Les dépendances Python épinglées ont été installées pour vérifier le chargement
réel de `google-auth` avec une clé strictement synthétique.

## Vérification finale après revue

Les seize constats des trois relectures ont été traités : rotation concurrente,
récupération du bearer, expiration depuis la première attache, état historique,
reprise par lots, confirmation immédiate, santé/permission, priorité API 24/25,
lecture FCM lente et couverture du client Firebase configuré.

La vérification complète a été rejouée après ces corrections :

- `final-analyze.log` : aucune anomalie, 14,7 s.
- `final-flutter-test.log` : 486 réussis, 17 ignorés, 70 s.
- `final-notifier-test.log` : 128 réussis, 25,080 s.
- `final-android-build.log` : APK debug compilé, 55,5 s.
- Contrats byte-identiques et `git diff --check` sans erreur.

Ces résultats remplacent les totaux généraux antérieurs. L’APK est disponible
dans `build/app/outputs/flutter-apk/app-debug.apk`.

## Limites conservées

- Aucun projet Firebase, compte réel, déploiement, installation téléphone ou push
  réel créé/exécuté. Préparation et essais réels reportés en 5.5. G3 reste ouverte.
- Le montage HA, les services Google, la réception Android app fermée, les réglages
  de batterie, le lecteur d’écran physique et l’arrêt forcé exigent l’essai réel 5.5.
  Les tests widgets vérifient la structure accessible et le texte agrandi.
- L’ouverture ciblée appartient à 5.4 ; les associations sont conservées pour elle.
- Le build signale un avertissement amont `firebase_core` sur la migration future
  vers Built-in Kotlin. Le build actuel réussit avec les versions épinglées.
- Aucun transport ni test ne promet exactement une livraison.

Références primaires consultées pour la compatibilité et le protocole :
[versions FlutterFire](https://github.com/firebase/flutterfire/blob/main/VERSIONS.md),
[FCM HTTP v1 et OAuth](https://firebase.google.com/docs/cloud-messaging/send/v1-api),
[firebase_messaging 17.0.1](https://pub.dev/packages/firebase_messaging/versions/17.0.1).
