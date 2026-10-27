# Hermes Mobile

Les notifications de fin se configurent dans les réglages du profil, pour la
connexion entière : origine HTTPS de l’observateur et credential distinct de
Hermes, puis activation explicite de la permission Android. La santé de
l’observateur est distincte de la disponibilité du téléphone. Un échec du suivi
laisse partir la demande et marque son tour « Notification non suivie ».

Firebase est facultatif au démarrage. `firebase_messaging 17.0.1` et
`firebase_core 5.1.0` sont résolus et le build debug sans configuration est
vérifié. Aucun projet, compte ni push réel n’est créé par ce dépôt. Leur
préparation et les essais téléphone appartiennent à 5.5 ; le toucher ciblé
appartient à 5.4. Voir [la préparation FCM](server/notifier/DOCS.md#15-préparation-fcm-pour-55).

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

## Connexion et profils (contrat documentaire)

Le backend Desktop doit être activé et exposé sur le port 9119 via Tailscale. La référence publique est Hermes `v0.22.2`, SHA `d923a5eb487a17c0a68801bba9ef0f56c81040a8`. Le contrat est épinglé sur le build observé via `/api/health`, `v0.22.2+1690` (main, SHA `9e01b44dd23978f9ff40b7837467f3a9f1582130`) ; il n’est pas encore validé sur l’installation. Les données de `contracts/fixtures/` sont synthétiques et **ne valident pas 1.3/G1**.

1. Saisir `http://<hôte>.ts.net:9119` ou une origine HTTPS. L’app refuse identifiants, chemin, query et fragment. HTTP n’est accepté que sous `ts.net`.
2. Vérifier et confirmer l’origine affichée, puis saisir le mot de passe Hermes (utilisateur `hermes`). La connexion est mémorisée ; mots de passe et jetons restent dans le coffre sécurisé, jamais dans SQLite.
3. Choisir un profil et actualiser la liste. Le choix est local au téléphone et ne modifie pas le profil global du dashboard. Sans choix explicite, seul le `is_default` fourni par le GET profils sert de défaut ; aucune valeur n’est inventée en cas d’échec.

Pour générer un QR sans secret (à scanner avec la caméra Android) :

```sh
python -m pip install -r tool/requirements.txt
python tool/generate_pairing_qr.py http://desktop.exemple.ts.net:9119 --output pairing.svg
```

Le QR contient uniquement `hermes-mobile://pair?url=<origine encodée>`. L’ouverture du lien affiche la confirmation avant tout accès au nouveau serveur. La saisie manuelle reste disponible. Un changement d’origine conserve la clé UUID locale, ferme l’ancienne socket et efface ses credentials avant tout nouvel accès réseau.

La reconnexion renouvelle les jetons via `/auth/native/refresh`, puis retente le login depuis le coffre si le refresh est refusé. Chaque socket reçoit un nouveau ticket transmis par sous-protocole, jamais en URL. Les redirections authentifiées sont refusées. Après trois tentatives automatiques échouées, le bouton de reconnexion reste disponible.

Les fonctions absentes et non vérifiées restent visibles. Les capacités futures ne sont pas sondées par création de session, envoi ou ajout de fichier. Après activation, comparer le build effectif, capturer des réponses expurgées, puis valider auth/profils/reconnexion sur PC et Pixel, texte 200 %, clavier et TalkBack. Cette validation réelle reste ouverte.

## CI

`.github/workflows/ci.yml` (GitHub Actions) lit la version Flutter dans `.fvmrc`, puis lance `flutter analyze`, `flutter test` et `flutter build apk --debug` à chaque push et pull request.
