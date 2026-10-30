# Story 5.1 — prérequis Android constatés

Constat du **2026-10-26 vers 21:38 CET**, via ADB 1.0.41 (36.0.0), sur le
téléphone d'Alanc. Aucun essai de notification réelle n'a été effectué : le
transport FCM appartient à 5.3 et la validation à 5.5.

## Identité de l'appareil et de l'app

| Élément | Constat |
|---|---|
| Numéro de série ADB | `39161FDJG0026X` |
| Modèle | Pixel 8 Pro (`husky`) |
| Android | 17, API 37 |
| Build | `CP3A.261005.005` |
| Patch de sécurité | 2026-10-05 |
| Empreinte | `google/husky/husky:17/CP3A.261005.005/16271449:user/release-keys` |
| Google Play services | 26.41.31 (`260400-1002748488`), paquet présent, non désactivé |
| App | `fr.hermes_mobile`, version 0.1.0 (versionCode 15), minSdk 24, targetSdk 36 |
| État ADB | `device` |

Le `versionCode` installé (15) ne correspond pas au `pubspec.yaml` du dépôt
(`0.1.0+1`) : le constat porte sur l'APK présent sur le téléphone, pas sur un
build du commit revu. Il faudra réinstaller l'APK de 5.3 avant l'essai de 5.5.

## Cas et comportements attendus

| Cas | Commande | Constat daté (2026-10-26) | Comportement attendu | Suite |
|---|---|---|---|---|
| Accès ADB | `adb devices -l` | `39161FDJG0026X device product:husky model:Pixel_8_Pro` | L'appareil reste interrogeable pour les constats et les essais | 5.5 |
| Services Google | `pm list packages com.google.android.gms` ; `dumpsys package com.google.android.gms` | Paquet présent, `versionName=26.41.31`, `enabled=0` (activé par défaut), `stopped=false` | FCM peut fonctionner ; si GMS est absent, désactivé ou trop ancien, l'app explique pourquoi aucune notification ne peut arriver | 5.3, 5.5 |
| Permission de notification | `dumpsys package fr.hermes_mobile` ; `cmd appops get fr.hermes_mobile POST_NOTIFICATION` | `POST_NOTIFICATIONS` **n'est pas déclaré** dans les permissions demandées ; l'app-op rend `POST_NOTIFICATION: ignore` | 5.3 doit déclarer `POST_NOTIFICATIONS` et la demander au runtime. Sans accord : aucune notification affichée, même si un token FCM a pu être obtenu. Un refus définitif renvoie vers les réglages avec une explication. | 5.3 |
| Canal de notification | `dumpsys notification --noredact` | Aucun `NotificationChannel` rattaché à `fr.hermes_mobile` | 5.3 crée un canal dédié aux fins de travail ; l'utilisateur peut le désactiver et l'app explique alors le silence | 5.3 |
| Optimisation batterie | `dumpsys deviceidle whitelist` ; `settings get global low_power` ; `cmd netpolicy get restrict-background` ; `am get-standby-bucket fr.hermes_mobile` | `fr.hermes_mobile` **absent** de la liste blanche ; `low_power=0` ; restriction d'arrière-plan désactivée ; appareil sur USB à 75 %, standby bucket 10 = `active` (20 = `working_set`) au moment du constat | Sans exemption, Doze peut retarder les messages FCM. Une fin doit utiliser une priorité FCM élevée et le bloc `notification` du contrat `notification + data` ; l'app explique l'optimisation batterie et propose les réglages, sans promettre une livraison immédiate. Le constat sur secteur ne prouve pas le comportement en veille. | 5.5, hors secteur |
| Arrêt forcé | `am force-stop fr.hermes_mobile` ; `pidof fr.hermes_mobile` | Processus absent après l'arrêt forcé ; aucune activité | Android ne délivre plus de FCM tant que l'app n'a pas été rouverte manuellement. C'est distinct d'un balayage hors des récents : l'app doit l'expliquer et reprendre à la réouverture. | 5.5 |
| Données en arrière-plan | `cmd netpolicy get restrict-background` | `Restrict background status: disabled` | Si la restriction est activée, FCM peut échouer ou être retardé ; l'app explique ce prérequis au lieu de laisser croire que le travail n'est pas fini | 5.5 |

## Ce qui n'a pas été testé

- Aucune notification n'a été envoyée : le code de 5.3 et l'observateur de 5.2
  n'existent pas encore.
- Aucun token FCM n'a été demandé ni enregistré.
- La permission n'a pas été accordée ; le constat porte sur l'état actuel de
  l'APK 0.1.0, pas sur le comportement après accord.
- Le mode Doze n'a pas été provoqué : l'appareil était sur secteur.
- L'ouverture à froid et à chaud depuis une notification appartient à 5.4/5.5.
- Aucune capture d'écran ni donnée de compte Google n'est versionnée.

## Commandes de reproduction

```powershell
adb devices -l
adb -s 39161FDJG0026X shell getprop ro.product.model
adb -s 39161FDJG0026X shell getprop ro.build.version.release
adb -s 39161FDJG0026X shell getprop ro.build.version.sdk
adb -s 39161FDJG0026X shell getprop ro.build.id
adb -s 39161FDJG0026X shell getprop ro.build.version.security_patch
adb -s 39161FDJG0026X shell pm list packages com.google.android.gms
adb -s 39161FDJG0026X shell "dumpsys package com.google.android.gms | grep -E 'versionName|enabled=|stopped='"
adb -s 39161FDJG0026X shell dumpsys package fr.hermes_mobile
adb -s 39161FDJG0026X shell cmd appops get fr.hermes_mobile POST_NOTIFICATION
adb -s 39161FDJG0026X shell dumpsys notification --noredact
adb -s 39161FDJG0026X shell dumpsys deviceidle whitelist
adb -s 39161FDJG0026X shell settings get global low_power
adb -s 39161FDJG0026X shell cmd netpolicy get restrict-background
adb -s 39161FDJG0026X shell am get-standby-bucket fr.hermes_mobile
adb -s 39161FDJG0026X shell am force-stop fr.hermes_mobile
adb -s 39161FDJG0026X shell pidof fr.hermes_mobile
```

## Conséquence pour 5.3 et 5.5

5.3 doit ajouter la permission `POST_NOTIFICATIONS`, demander l'accord au bon
moment, créer un canal, enregistrer le token auprès de l'observateur et
expliquer les refus. 5.5 doit rejouer les cas sur l'appareil réel, hors
secteur, avec permission accordée puis refusée, arrêt forcé, coupure réseau,
redémarrage de l'observateur et observateur absent. Le silence ne doit jamais
être présenté comme une réussite.
