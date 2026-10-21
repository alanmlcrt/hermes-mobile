---
title: 'Story 1.1 : Initialiser l''application et la valider sur mon téléphone'
type: 'chore'
created: '2026-10-20'
status: 'done'
baseline_commit: 'a316e14379aaa37316299421bfe3a1232d9331d3'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Le dépôt ne contient aucun code applicatif. La stack Flutter n'a jamais été compilée, installée ni lancée sur le téléphone Android d'Alanc, et toutes les stories suivantes en dépendent.

**Approach:** Générer la graine Flutter épinglée, poser l'arborescence et les paquets centraux résolus ensemble, produire un APK release signé hors dépôt, mettre en place la CI (analyse, tests, contrôle des imports, build Android), puis faire valider l'installation et le lancement par Alanc sur son téléphone.

## Boundaries & Constraints

**Always:**
- Flutter 3.47.x, dernier correctif stable au moment du bootstrap, avec le Dart fourni. La version est épinglée et consignée dans le dépôt.
- Graine : `flutter create --empty --platforms=android,ios`, nom de projet `hermes_mobile`, générée **à la racine du dépôt**. `contracts/` est aussi à la racine, donc dans le package Flutter.
- `minSdk 24`, `android:allowBackup="false"`.
- Paquets épinglés en version exacte : dynamic_color 2.1.0, sqflite 2.4.4+2, flutter_secure_storage 11.2.0, plus les choix centraux (voir Design Notes). `pubspec.lock` est commité.
- Clé de signature et mots de passe hors du dépôt. `key.properties` et `*.jks` sont dans `.gitignore`.
- APK versionné (`version:` de `pubspec.yaml` → versionName/versionCode).

**Décisions d'Alanc :**
- Flutter installé et épinglé via **FVM** (`.fvmrc` commité ; commandes `fvm flutter …`).
- Identifiant d'application **`fr.hermes_mobile`** (`--org fr`, projet `hermes_mobile`).
- CI sur **GitHub Actions** (`.github/workflows/ci.yml`) ; création d'un dépôt GitHub **privé** comme remote.
- Dépôt GitHub privé nommé **`hermes-mobile`**, sous le compte de l'utilisateur (`gh`).
- **Nouvelle clé de signature** générée dans `%USERPROFILE%\.hermes-mobile\upload-keystore.jks` ; Alanc est responsable de sa sauvegarde.
- Spec gardée entière malgré sa taille (~2 300 tokens).

**Never:**
- `flutter_markdown` (abandonné), `firebase_messaging` / `firebase_core` (attente de G3).
- Aucun écran, thème, token, repository ni appel réseau : ils relèvent des stories 1.2 à 1.7. `main.dart` reste minimal.
- Pas de framework d'état, de service locator ni de `custom_lint` : le contrôle des imports est un simple test Dart.
- Aucune simulation (émulateur) ne vaut validation de la stack.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Import propre | `lib/models/x.dart` sans import Flutter | test d'imports vert | N/A |
| Modèle impur | `lib/models/x.dart` importe `package:flutter/...` | test d'imports rouge, fichier nommé | message cite fichier + import |
| Vue fautive | `lib/features/**` importe `lib/data/**` (relatif ou `package:hermes_mobile/data/`) | test d'imports rouge | idem |
| Installation téléphone | APK release installé par Alanc | l'app s'ouvre sans erreur | échec → HALT, choix de stack rendu à Alanc |

</frozen-after-approval>

## Code Map

- Dépôt vierge de code : seuls `_bmad/`, `_bmad-output/`, `.claude/`, `.agents/` et `.gitignore` (`_bmad/render/`, `_bmad/config.user.toml`) existent. À ne pas modifier, sauf `.gitignore` où l'on ajoute les entrées Flutter et de signature.
- `C:\Users\alanc\AppData\Local\Android\Sdk` (`ANDROID_HOME`) : SDK, NDK et build-tools présents. JDK 21 dans `C:\Program Files\Java\jdk-21`.
- Référence de version : le CHANGELOG stable de Flutter listait les correctifs 3.47.1 à 3.47.7. Il faut revérifier le dernier correctif au moment de l'installation.

## Tasks & Acceptance

**Execution:**
- [x] Poste + `.fvmrc` -- installer FVM puis Flutter 3.47.x (`fvm use 3.47.<dernier>`), puis `fvm flutter doctor --android-licenses` -- prérequis épinglé.
- [x] racine -- `fvm flutter create --empty --platforms=android,ios --project-name hermes_mobile --org fr .` -- graine imposée.
- [x] `lib/{app,models,data,features,ui}/`, `contracts/` -- créer chaque dossier avec un `README.md` d'une ligne qui donne son rôle -- arborescence suivie par git.
- [x] `android/app/build.gradle.kts` -- `minSdk = 24` ; signature release lue depuis `android/key.properties` (absent → build release non signé refusé) -- signature hors dépôt.
- [x] `android/app/src/main/AndroidManifest.xml` -- `android:allowBackup="false"`.
- [x] `pubspec.yaml` -- ajouter les paquets en version exacte (Always + Design Notes), `version: 0.1.0+1`, puis `flutter pub get` -- résolution commune, lockfile commité.
- [x] `test/architecture_imports_test.dart` -- parcourir `lib/models` (aucun `package:flutter`) et `lib/features` (aucun import vers `data/`), en couvrant les cas de la matrice avec des sources en mémoire -- contrôle des frontières.
- [x] `.github/workflows/ci.yml` -- sur push/PR : Flutter lu depuis `.fvmrc`, `flutter analyze`, `flutter test`, `flutter build apk --debug` (pas de clé en CI) -- CI.
- [ ] GitHub -- créer le dépôt privé, l'ajouter en remote, pousser `master` et la branche -- la CI s'exécute.
- [x] `.gitignore` -- ajouter `android/key.properties`, `*.jks`, `*.keystore`.
- [x] `README.md` -- prérequis, commandes de build, procédure de signature et d'installation manuelle -- reproductibilité.

**Acceptance Criteria:**
- Given le dépôt généré, when on liste l'arborescence, then `lib/app`, `lib/models`, `lib/data`, `lib/features`, `lib/ui` et `contracts/` existent, `minSdk` vaut 24 et `allowBackup` vaut `false`.
- Given `pubspec.yaml`, when on l'inspecte, then aucun paquet `flutter_markdown`, `firebase_*` n'est présent et chaque dépendance directe a une version exacte.
- Given la clé hors dépôt, when on lance `flutter build apk --release`, then un APK signé et versionné est produit et `git status` ne montre ni clé ni `key.properties`.
- Given l'APK, when Alanc l'installe et le lance sur son téléphone, then l'app s'ouvre sans erreur. En cas d'échec, le travail s'arrête et le choix de stack lui revient.
- Given la CI, when elle s'exécute, then analyse, tests (dont le contrôle des imports) et build Android passent.

## Implementation Notes

- Flutter 3.47.7 (Dart 3.13.5), dernier tag 3.47.x vérifié par `git ls-remote` au bootstrap. `fvm use` a écrit `.fvmrc` mais n'a pas pu créer le lien `.fvm/versions` (privilège symlink Windows absent, mode développeur désactivé) ; sans incidence, `.fvm/` est ignoré. Licences Android déjà acceptées (le build release a réussi).
- Versions pub.dev au bootstrap : http 1.6.0, web_socket_channel 3.0.3, go_router 18.1.1, flutter_markdown_plus 1.0.12, file_picker 13.1.0 ; flutter_lints épinglé à 6.0.0 (dev).
- Refus du release non signé : `build.gradle.kts` lève une `GradleException` si une tâche `*Release*` est demandée sans `android/key.properties` (vérifié).
- Clé : `%USERPROFILE%\.hermes-mobile\upload-keystore.jks` (PKCS12, RSA 4096, alias `upload`) ; mots de passe aléatoires dans `%USERPROFILE%\.hermes-mobile\key.properties`, copié dans `android/key.properties` (ignoré).
- Tâche GitHub (dépôt, remote, push) laissée non cochée : opérations distantes exclues de cette étape. Installation téléphone à faire par Alanc.

- 2026-10-21 : APK release installé par adb sur le Pixel 8 Pro d'Alanc ; `Displayed fr.hermes_mobile/.MainActivity +554ms`, aucun plantage ; Alanc confirme l'affichage « Hello World! ». Stack validée sur téléphone réel.
- Dépôt GitHub privé `alanmlcrt/hermes-mobile` créé, `master` et `story/1-1-init-app` poussés.

## Spec Change Log

## Review Triage Log

| # | Source | Constat | Verdict | Preuve | Route |
|---|--------|---------|---------|--------|-------|
| 1 | blind | `INTERNET` absent du manifest `main` | medium | seuls `debug`/`profile` la déclarent ; l'APK release n'aura pas de réseau dès 1.4 | patch |
| 2 | blind | libellé app `hermes_mobile` | low | `android:label` du gabarit, visible sur le téléphone ; correction directe | patch |
| 3 | blind | bundle iOS `fr.hermesMobile` ≠ `fr.hermes_mobile` | low | pbxproj l.386 ; `_` interdit en iOS, à trancher avant le travail iPhone | defer |
| 4 | blind, edge, gap | `key.properties` incomplet → erreur obscure | low | fichier généré par l'outil ; rare, la correction ajoute des gardes | rejet |
| 5 | blind, edge, gap | garde release par nom de tâche : `assemble`/`build` contournent, `lintRelease` bloqué | low | `startParameter.taskNames` ne voit pas le graphe ; passer à `taskGraph.whenReady` est une correction directe | patch |
| 6 | edge | `storeFile` relatif résolu depuis `android/app` | false | `key.properties` utilise un chemin absolu ; convention de la doc Flutter | rejet |
| 7 | blind, edge, gap | modèles : `dart:ui` non détecté | low | le README promet « aucun import Flutter » ; une ligne suffit | patch |
| 8 | blind, edge, gap | modèles : paquets plugins Flutter non détectés | low | il faudrait une liste blanche, et les modèles peuvent importer des paquets Dart purs | rejet |
| 9 | edge, gap | imports conditionnels, `part`, commentaires `/* */`, barrels, URI non normalisées | low | cas peu probables ; il faudrait un parseur | rejet |
| 10 | blind | autres frontières (models→data, ui→data) | low | la matrice n'exige que deux règles | rejet |
| 11 | gap, blind, edge | test sur l'arborescence réelle vacant si un dossier manque | medium | `if (!d.existsSync()) continue;` | patch |
| 12 | gap | règle `export` non testée | medium | aucun cas en mémoire n'utilise `export` | patch |
| 13 | gap | refus du build release sans clé jamais vérifié en CI | medium | CI = `--debug` seulement | patch |
| 14 | gap | CI jamais exécutée | medium | pas de remote ; tâche GitHub en attente de finalisation | traité par la tâche GitHub restante |
| 15 | blind | pas de smoke test widget | low | seed vide ; l'essai sur téléphone couvre le lancement | rejet |
| 16 | blind | CI sans `permissions:` | low | `contents: read` en une ligne, correction directe | patch |
| 17 | blind | CI sans concurrency/timeout/cache Gradle/format | low | confort, non demandé | rejet |
| 18 | blind | `-Xmx8G` dans `gradle.properties` | maybe-false | valeur du gabarit ; runner de 16 Go ; seul un run CI trancherait, et le constat serait au plus low | rejet |
| 19 | blind | statut de la spec / `master` vs `main` | false | correctif = édition de la spec ; `main` n'existe pas dans le dépôt | rejet |
| 20 | blind | README Windows seul | low | poste unique Windows ; non demandé | rejet |
| 21 | edge | README : `keytool` échoue si `.hermes-mobile` n'existe pas | low | `keytool` ne crée pas le dossier ; une ligne `mkdir` suffit | patch |
| 22 | blind | `resolveLaunchTarget` cité dans `lib/app/README.md` | false | rôle prévu par l'architecture, pas un symbole appelé | rejet |
| 23 | blind | `.gitignore` racine incomplet | false | `android/.gitignore` et `ios/.gitignore` du gabarit couvrent ces entrées | rejet |
| 24 | blind | pas de contrainte `flutter:` dans `pubspec` | low | `.fvmrc` épingle la version ; cas peu probable | rejet |
| 25 | edge | `jq` renvoie `null` si `.fvmrc` est cassé | low | cas peu probable ; erreur visible malgré tout | rejet |

## Design Notes

Choix centraux (décidés ici, versions exactes vérifiées sur pub.dev au bootstrap, non *discontinued*) :
- Réseau : `http` (REST) + `web_socket_channel` (`/api/ws`), deux paquets officiels Dart.
- Routage : `go_router` (officiel Flutter, deep links `hermes-mobile://pair` à venir en 1.4).
- Markdown : `flutter_markdown_plus` (successeur communautaire maintenu). Le rendu du code et des emojis sera vérifié en 2.3.
- Fichiers : `file_picker`.

Les paquets ajoutés ne sont pas encore importés : `flutter build apk --release` compile quand même leurs parties natives Android, ce qui valide la résolution commune.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: tous verts, dont `architecture_imports_test.dart`
- `flutter build apk --release` -- expected: `build/app/outputs/flutter-apk/app-release.apk` produit
- `apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk` -- expected: signature valide avec la clé hors dépôt

**Manual checks (if no CLI):**
- Alanc installe l'APK sur son téléphone (`adb install` ou copie du fichier) et confirme que l'app s'ouvre.
