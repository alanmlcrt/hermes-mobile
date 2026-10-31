# Hermes Mobile

Application Android personnelle (iPhone anticipé) servant d'interface distante à l'installation Hermes d'Alanc. Identifiant d'application : `fr.hermes_mobile`.

## Notifications

Les notifications de fin de tour passent par le plugin Hermes `hermes-mobile-notify`. Aucun fichier Hermes n'est à copier ni à modifier à la main.

1. Depuis le terminal Hermes du profil à notifier :

   ```sh
   hermes plugins install alanmlcrt/hermes-mobile/server/hermes-plugin/hermes-mobile-notify --enable
   ```

   Autre profil : `hermes -p <profil> plugins install alanmlcrt/hermes-mobile/server/hermes-plugin/hermes-mobile-notify --enable`.

   Si une copie manuelle du plugin existe déjà dans `HERMES_HOME/plugins/`, ajouter `--force` à la commande (ou lancer d'abord `hermes plugins remove hermes-mobile-notify`).

2. Hermes Desktop → **Settings → Plugins** → engrenage de la ligne **hermes-mobile-notify** (Hermes Mobile) → champ **Compte de service Firebase** → coller le JSON du compte de service (ou le même JSON en base64) → **Save**.

   Si `HERMES_HOME/hermes-mobile/service-account.json` existe déjà (installation antérieure), cette étape est facultative : le plugin utilise ce fichier.

3. Redémarrer Hermes (add-on Home Assistant : **Redémarrer**).

4. Envoyer un message depuis l'app, quitter l'app, puis attendre la fin d'un tour : la notification arrive.

L'app demande la permission Android au premier lancement ; sans elle, le système masque les notifications même si le plugin les envoie.

Détails, vérification, mise à jour et désinstallation : [plugin Hermes](server/hermes-plugin/README.md).

L'app transmet son jeton FCM au plugin à chaque envoi, sans configuration par profil. Si le plugin est absent du profil, la demande part quand même et son tour est marqué « Notification non suivie ». Dans l'app, chaque profil garde son interrupteur de notifications ; il est grisé tant que le plugin n'est pas actif sur ce profil.

Firebase est facultatif au démarrage. Le fichier `android/app/google-services.json` n’est pas versionné : le plugin Gradle Google Services n’est appliqué que s’il existe. Sans lui, le même APK démarre avec l’état « Firebase non configuré » ; aucun faux jeton n’est utilisé.

## Salons (Bot Mode)

Un salon Hermes réunit 2 à 6 bots et vous. Avec Hermes Desktop, le marqueur Bot Mode est écrit automatiquement : aucun fichier Hermes à éditer.

1. Se connecter au backend dans Hermes Desktop (**Settings → Gateways**, ou **Connections** selon la version).
2. Onglet **Bots** → **+** → **New Agent** : créer les participants (nom, titre, description). Refaire pour chaque bot. Pour un profil existant, le sélectionner dans **Bots** → **Edit Profile** ; Hermes le marque comme bot.
3. Onglet **Bots** → **+** → **New Group Chat** : nommer le salon, cocher 2 à 6 bots, puis **Create**.
4. Ouvrir le salon et écrire. `@nom` cible un bot, `@all` / `@everyone` tout le monde, `@user` vous alerte.

Une fois les profils marqués, un salon peut aussi se créer depuis l'app : onglet **Salons** → **Nouveau salon**, mêmes règles (2 à 6 profils).

Hermes écrit le marqueur `ui_meta: {hermes-bots: {}}` dans le `profile.yaml` du bot. Il n'existe pas d'éditeur YAML de `profile.yaml` dans l'interface : **Bots** est le chemin officiel. Le YAML ne sert qu'aux installations sans Desktop :

```yaml
# HERMES_HOME/profiles/<bot>/profile.yaml (ou profile.yaml du profil par défaut)
ui_meta:
  hermes-bots: {}
```

Fusionner avec le bloc `ui_meta` existant (un seul bloc), redémarrer Hermes, puis créer le Bot Chat canonique si l'installation est purement headless :

```sh
hermes -p <bot> chat -c "Bot Chat" --create-if-missing
```

Les profils non marqués restent utilisables normalement ; seuls les profils marqués sont proposés à la création d'un salon. Documentation officielle : [Bot Mode](https://hermes-agent.nousresearch.com/docs/user-guide/bot-mode).

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
