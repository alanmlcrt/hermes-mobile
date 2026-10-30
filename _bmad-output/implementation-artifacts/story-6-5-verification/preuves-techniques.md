# Preuves techniques — préparation réelle du 2026-10-30

Relevés expurgés par l'agent. Les commandes indiquées ont été exécutées avec le préfixe `rtk proxy`. Aucun contenu personnel, secret, jeton ou identifiant complet de téléphone/session n'est conservé. Ces prérequis techniques ne valident aucun parcours mobile.

## Source et outillage

- Révision Git : `ecbedeeac543f8cf874e1e204ddc3b1a948022ac`. Arbre initial : seule la spec 6.5 était non suivie ; aucune modification de code applicatif pour la préparation.
- `C:/Users/alanc/.fvm-bin/fvm/fvm.exe flutter --version` : Flutter 3.47.7 stable, framework `abaf9c5237`, Dart 3.13.5, conforme à `.fvmrc`.
- `fvm flutter analyze` : exit 0, « No issues found! », 81.7 s.
- `fvm flutter test` : exit 0, « All tests passed! », 616 réussis et 17 ignorés, environ 67 s. Tests/fixtures non comptés comme essai réel.

## Build et installation

- `fvm flutter build apk --release --build-number=23` : exit 0, `assembleRelease` 141.3 s ; APK produit le 2026-10-30 à 16:20:38Z.
- APK : `build/app/outputs/flutter-apk/app-release.apk`, **57 576 535 octets**.
- SHA-256 : `a72d4aca9dcc189a454ae1f5add884feda7f7b31ffeba6c23b62e8097c69434d`.
- `apksigner.bat verify` (Android SDK build-tools 36.1.0) : exit 0.
- Avertissements du build, sans échec : `firebase_core` applique encore Kotlin Gradle Plugin ; référence CupertinoIcons sans police associée. Aucun correctif de dépendance effectué pendant cet essai.
- `adb devices -l` : Pixel 8 Pro connecté, état `device` autorisé ; identifiant omis.
- Avant : `fr.hermes_mobile`, versionName 0.1.0, versionCode 22, minSdk 24, targetSdk 36.
- Après annonce à Alanc par l'agent coordinateur : `adb install -r build/app/outputs/flutter-apk/app-release.apk` → exit 0, `Performing Streamed Install / Success`.
- Relu à **2026-10-30T16:21:21Z** via `dumpsys package` filtré : versionName **0.1.0**, versionCode **23**, minSdk 24, targetSdk 36. Aucun `clear`, uninstall ou downgrade exécuté. La conservation effective des brouillons sera vérifiée par Alanc, elle ne se déduit pas du succès d'installation.

## Hermes et plugin — lecture seule

Lecture externe annoncée à Alanc. À **2026-10-30T16:19:20Z**, `GET /api/health` :

```json
{"ok":true,"version":"0.22.2","displayVersion":"0.22.2+1690","commit":"9e01b44dd23978f9ff40b7837467f3a9f1582130","auth_required":true}
```

Build conforme à la référence documentaire ; ce relevé ne transforme pas les fixtures en captures réelles ni ne prouve les capacités.

Comparaison SHA-256 par Samba en lecture seule, uniquement `plugin.yaml` et `__init__.py` :

| Profil | plugin.yaml | __init__.py | Conclusion limitée |
|---|---|---|---|
| default | Identique dépôt | Identique dépôt | Fichiers de la version 1.0.2 présents ; chargement effectif après redémarrage à confirmer. |
| mesure-pieces-jointes | Absent | Absent | Plugin absent de ce profil au relevé ; aucun fichier installé par l'agent. |

Les clés et jetons n'ont pas été lus. Aucun fichier de configuration, plugin ni journal serveur modifié. Aucun accès aux bases privées de Hermes.

## Pièces préparées sur téléphone

Après annonce du transfert à Alanc : création du dossier `Download/Hermes-MVP-6-5`, puis `adb push` des quatre pièces existantes du corpus 4.1. Aucun envoi Hermes effectué. SHA-256 relus sur le téléphone par `adb shell sha256sum` et identiques aux sources locales à **2026-10-30T16:20:52Z**.

| Pièce synthétique | Octets | Format | SHA-256 |
|---|---:|---|---|
| texte-5Mo.txt | 5242906 | text/plain | `047cba4e5a7db41a77faa54302a542706ba064579a04da02cf1e7e50b343fff8` |
| image-marqueur.png | 9911 | image/png | `7a92f7d520464eebf8455cfd68534b203225c04b154ccd8c28a2bec0634fe8e7` |
| pdf-30pages.pdf | 7278 | application/pdf | `7b48d2aaebb548edca4bbf8b049c906e9de59eaf0165e03fac9d2013824776e7` |
| bureautique-1Mo.docx | 1048649 | application/vnd.openxmlformats-officedocument.wordprocessingml.document | `37e1b5f52684faf262e7ee4f564b6620c766a37ddc13132e0819d071ca10aec9` |

Ce choix couvre les quatre catégories demandées pour le parcours mobile ; il ne rejoue pas la campagne de plafonds 4.1. Une sélection et une réception dans le fil restent à constater. Les pièces sont neutres et synthétiques ; aucune analyse du modèle n'est démontrée par le transfert ADB.
