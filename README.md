# Hermes Mobile

Application Android personnelle (iPhone anticipé) servant d'interface distante à l'installation Hermes d'Alanc. Identifiant d'application : `fr.hermes_mobile`.

## Prérequis

- [FVM](https://fvm.app/) : la version de Flutter est épinglée dans `.fvmrc` (Flutter 3.47.7, Dart 3.13.5). Toutes les commandes passent par `fvm flutter …`.
- JDK 17 ou plus récent (testé avec JDK 21), `JAVA_HOME` défini.
- SDK Android (`ANDROID_HOME`), avec les licences acceptées : `fvm flutter doctor --android-licenses`.

```sh
fvm install          # installe la version lue dans .fvmrc
fvm flutter pub get --enforce-lockfile
```

## Arborescence

| Dossier | Rôle |
|---|---|
| `lib/app` | composition, injection explicite, routes |
| `lib/models` | modèles en Dart pur (aucun import Flutter) |
| `lib/data` | repositories, adaptateur Hermes, stockage |
| `lib/features` | vues et ViewModels (aucun import de `lib/data`) |
| `lib/ui` | tokens, thème, composants, catalogue |
| `contracts/` | contrat Hermes figé |

Les frontières d'imports sont vérifiées par `test/architecture_imports_test.dart`.

## Commandes

```sh
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug      # sans clé (identique à la CI)
fvm flutter build apk --release    # exige android/key.properties
```

La version de l'APK vient de `version:` dans `pubspec.yaml` (`0.1.0+1` → versionName `0.1.0`, versionCode `1`). L'incrémenter avant chaque APK distribué.

## Signature

La clé et ses mots de passe restent hors du dépôt (`android/key.properties`, `*.jks` et `*.keystore` sont ignorés par git). Sans `android/key.properties`, le build release échoue volontairement plutôt que de produire un APK non signé.

1. Clé (déjà générée ; à ne refaire que sur une nouvelle machine sans sauvegarde) :

   ```sh
   mkdir %USERPROFILE%\.hermes-mobile
   keytool -genkeypair -v -keystore %USERPROFILE%\.hermes-mobile\upload-keystore.jks ^
     -storetype PKCS12 -keyalg RSA -keysize 4096 -validity 10000 -alias upload
   ```

2. Créer `android/key.properties` :

   ```properties
   storePassword=<mot de passe>
   keyPassword=<mot de passe>
   keyAlias=upload
   storeFile=C:/Users/<utilisateur>/.hermes-mobile/upload-keystore.jks
   ```

   Une copie de ce fichier est conservée dans `%USERPROFILE%\.hermes-mobile\key.properties`.

3. **Sauvegarder le dossier `%USERPROFILE%\.hermes-mobile\`** (clé + mots de passe) dans un endroit sûr. Sans lui, les mises à jour de l'app ne pourront plus être installées par-dessus la version existante.

Vérifier la signature :

```sh
%ANDROID_HOME%\build-tools\<version>\apksigner verify --print-certs build\app\outputs\flutter-apk\app-release.apk
```

## Installation manuelle sur le téléphone

APK produit : `build/app/outputs/flutter-apk/app-release.apk`.

- Par câble : activer le débogage USB, puis `adb install -r build\app\outputs\flutter-apk\app-release.apk`.
- Sans câble : copier l'APK sur le téléphone, l'ouvrir et autoriser l'installation depuis cette source.

Lancer l'app et vérifier qu'elle s'ouvre sans erreur. Seule cette installation sur le téléphone réel valide la stack, pas un émulateur.

## CI

`.github/workflows/ci.yml` (GitHub Actions) lit la version Flutter dans `.fvmrc`, puis lance `flutter analyze`, `flutter test` et `flutter build apk --debug` à chaque push et pull request.
