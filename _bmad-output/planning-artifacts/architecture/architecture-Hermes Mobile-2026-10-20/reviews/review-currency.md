# Revue « actualité et vérification » — ARCHITECTURE-SPINE.md

- **Date :** 2026-10-20
- **Objet :** vérifier que chaque décision engagée (versions, outils, transports, contrat Hermes) a été confrontée au web, au projet ou au starter actuel, et non affirmée de mémoire.
- **Méthode :** relecture du spine, de `integration-evidence.md` et de `.memlog.md`. Re-vérification en ligne le 2026-10-20 : pub.dev, docs.flutter.dev, CHANGELOG stable Flutter, docs Tailscale, docs Firebase, doc de l'add-on Tailscale Home Assistant. Comparaison de `.working/gateway-contract.openrpc.json` avec le HEAD amont actuel et avec le dernier tag de release. Spine non modifié.

## Verdict

L'effort de vérification est réel. Les cinq versions annoncées existent toutes sur leurs sources primaires, `flutter create --empty` est documenté et les dix méthodes OpenRPC citées sont présentes. Il reste quatre problèmes : le SDK est épinglé sur une version `.0` déjà corrigée sept fois ; un saut majeur de Firebase vieux de cinq jours n'a pas été évalué ; le contrat Hermes de référence est un HEAD mouvant qui diffère déjà du dernier tag publié ; le chemin Tailscale Serve n'est pas confronté à la façon dont l'add-on Home Assistant expose réellement un service tiers.

## Tableau de contrôle

| Élément engagé | Valeur du spine | Constat web du 2026-10-20 | Statut |
| --- | --- | --- | --- |
| Flutter stable | 3.47.0 | Ligne 3.47 confirmée ; correctif le plus récent **3.47.7** | Périmé (correctif) |
| dynamic_color | 2.1.0 | 2.1.0 = dernière (publiée il y a environ 2 mois, Dart ≥ 2.16) | Confirmé |
| sqflite | 2.4.4+2 | 2.4.4+2 = dernière (publiée il y a 7 jours) | Confirmé |
| flutter_secure_storage | 11.2.0 | 11.2.0 = dernière ; minSdk 23 ; avertissement sur la sauvegarde Android | Confirmé, réserves non reportées |
| firebase_messaging | 17.0.0 | 17.0.0 = dernière, **publiée il y a 5 jours**, version cassante ; minSdk 24 ; firebase_core ^5.0.0 | Confirmé, risque non évalué |
| `flutter create --empty` | `--empty --platforms=android,ios` | `--empty` documenté ; `--platforms` non montré dans le tutoriel (flag CLI standard) | Confirmé |
| MVVM Flutter | guide officiel | Lien présent dans les preuves | Confirmé |
| Tailscale Serve HTTPS | « convient si l'hôte la permet » | HTTPS automatique confirmé ; WebSocket non mentionné par la doc officielle ; dans l'add-on HA, un add-on tiers passe par `services` (Tailscale Services) | Partiel |
| FCM Android arrière-plan | FCM + affichage OS | Confirmé ; force-stop, POST_NOTIFICATIONS Android 13+, `getInitialMessage`/`onMessageOpenedApp` | Confirmé |
| OpenRPC `/api/ws` | commit `5eee5d0…` | HEAD actuel `71633f7…` ; contrat identique pour les méthodes clés ; **le tag v2026.9.24 diffère** | Partiel |

## Constats

### Majeur

**M1 — Le contrat Hermes de référence est un HEAD de branche, pas une release ; le schéma diffère déjà de la dernière release publiée alors que `info.version` reste « 1 ».**
- *Preuve :* `git ls-remote` donne aujourd'hui HEAD = `71633f762d2d74faebe604d0b8a2a2e6cf48346a`, et non `5eee5d0…`. Entre les deux, le fichier OpenRPC n'a pas changé : 257 méthodes, schémas clés identiques. En revanche, le dernier tag `v2026.9.24` ([contrat au tag](https://raw.githubusercontent.com/NousResearch/hermes-agent/v2026.9.24/apps/shared/src/gateway-contract.openrpc.json)) a 237 méthodes. Il lui manque `replay_epoch` dans `SessionEventsSinceParams` et `idempotency_key` dans `SessionCreateParams`. `info.version` vaut « 1 » dans les deux cas. Un add-on HA qui suit les releases serait donc probablement sur un schéma **sans** `replay_epoch`, alors qu'AD-4 s'appuie sur le curseur `(epoch, seq)`.
- *Pourquoi c'est important :* le numéro de version du contrat ne signale pas la compatibilité. Le HEAD ne correspond pas à ce qu'une installation « dernière version » fait tourner.
- *Correctif proposé :* dans `integration-evidence.md`, épingler le contrat sur le **tag de release** le plus proche du build de l'add-on (v2026.9.24 aujourd'hui) et garder le HEAD comme simple information. Dans AD-4/AD-7, préciser que `info.version` ne vaut pas preuve de compatibilité. La détection des capacités (présence de `replay_epoch`, etc.) doit se faire sur le contrat **du build installé**, pendant G1. Noter aussi que `session.create` a gagné une `idempotency_key` sur HEAD. AD-5 reste correct (aucune clé sur `prompt.submit`), mais la phrase sur l'absence d'idempotence doit être datée et rattachée à une version précise.

**M2 — firebase_messaging 17.0.0 est une version majeure cassante publiée il y a 5 jours ; son impact n'a pas été évalué.**
- *Preuve :* [changelog firebase_messaging](https://pub.dev/packages/firebase_messaging/changelog). La 17.0.0 est marquée « breaking ». Elle passe sur le Firebase iOS SDK 13.0.0 et la BoM Android 35, exige **minSdk 24** et dépend de `firebase_core ^5.0.0` ([pub.dev](https://pub.dev/packages/firebase_messaging)).
- *Pourquoi c'est important :* une version majeure de quelques jours expose à des régressions et à des incompatibilités avec les autres plugins FlutterFire. Le minSdk 24 devient aussi le plancher Android de toute l'app, puisque flutter_secure_storage demande 23. Rien de cela n'est écrit dans le spine.
- *Correctif proposé :* dans « Stack de départ », ajouter `firebase_core` 5.x comme dépendance liée et fixer **minSdk Android = 24** comme contrainte explicite. Préciser qu'au moment de G3 on choisit entre la dernière 17.x corrigée et la dernière 16.x stable, après résolution et compilation conjointes. Ne pas laisser « 17.0.0 » figé.

**M3 — Tailscale Serve n'est pas confronté au mécanisme réel de l'add-on Tailscale Home Assistant, ni au WebSocket.**
- *Preuve :* la [doc de l'add-on Tailscale HA](https://github.com/hassio-addons/addon-tailscale/blob/main/tailscale/DOCS.md) indique que `share_homeassistant` n'expose que Home Assistant. Un autre add-on passe par l'option `services`, avec un nom `svc:`, une cible `http://127.0.0.1:<port>`, `advertise_tags` obligatoire, une définition du service dans la console admin et une approbation de l'hôte. La [référence CLI Serve](https://tailscale.com/docs/reference/tailscale-cli/serve) n'accepte comme cible de proxy que `http://127.0.0.1`. Ni elle ni la [page Serve](https://tailscale.com/docs/features/tailscale-serve) ne documentent le passage WebSocket ni la conservation ou le retrait du préfixe `--set-path`. Seules des sources tierces (par exemple [OpenClaw](https://docs.openclaw.ai/gateway/stable-https-url)) affirment que WSS fonctionne.
- *Pourquoi c'est important :* AD-8 exige « HTTPS/WSS… préfixe conservé ». L'hypothèse peut tomber pour trois raisons : un port Hermes non joignable en 127.0.0.1 depuis l'add-on Tailscale (si Hermes n'est pas en `host_network`), un préfixe retiré, ou des tags et une approbation admin oubliés.
- *Correctif proposé :* reformuler l'[ASSUMPTION] Serve ainsi : « via l'option `services` de l'add-on Tailscale HA (Tailscale Services, tags, approbation), cible 127.0.0.1 joignable ». Ajouter à la checklist G1 trois tests : upgrade WebSocket `/api/ws` à travers Serve, comportement du préfixe de chemin, joignabilité du port Hermes depuis l'add-on Tailscale.

### Mineur

**m1 — Flutter épinglé sur 3.47.0 alors que 3.47.7 existe.**
- *Preuve :* le [CHANGELOG stable](https://github.com/flutter/flutter/blob/stable/CHANGELOG.md) liste les correctifs 3.47.1 à 3.47.7, dont un correctif Android (rendu PowerVR, 3.47.3), un correctif de sécurité libpng (3.47.2) et des correctifs d'accessibilité iOS (3.47.7). `integration-evidence.md` dit « dernier correctif non déterminé » : la source permettait pourtant de le déterminer. Les [release notes](https://docs.flutter.dev/release/release-notes) n'en parlent pas (page mise à jour le 2026-08-12).
- *Correctif proposé :* remplacer par « Flutter 3.47.x, dernier correctif stable au bootstrap (3.47.7 au 2026-10-20) » et citer le CHANGELOG stable comme source.

**m2 — Réserves de flutter_secure_storage 11.x non reportées dans le spine.**
- *Preuve :* [pub.dev](https://pub.dev/packages/flutter_secure_storage) : minSdk 23, et la sauvegarde Android par défaut provoque `InvalidKeyException`. Il faut `android:allowBackup="false"` ou une exclusion. La page est par ailleurs ambiguë sur la migration (`migrateWithBackup`).
- *Correctif proposé :* AD-8 exclut déjà les secrets des sauvegardes. Le traduire en règle concrète de bootstrap : `allowBackup=false` ou règles d'exclusion de sauvegarde, et pas de migration v9 (projet neuf).

**m3 — Le protocole d'envoi FCM côté observateur n'est pas nommé.**
- *Preuve :* l'API FCM legacy est retirée au profit de [HTTP v1](https://firebase.google.com/docs/cloud-messaging/migrate-v1). Le spine ne précise pas l'API d'envoi de l'observateur. Ce point n'a pas été re-vérifié en ligne dans cette revue : c'est un rappel, pas une preuve.
- *Correctif proposé :* dans « Différé — après G3 », ajouter : « envoi FCM via HTTP v1 avec compte de service, identifiants hors dépôt ».

**m4 — Les dates de vérification des packages sont relatives.**
- *Preuve :* pub.dev n'affiche que « il y a N jours ». Le spine écrit « vérifiées le 20 octobre 2026 », ce qui est exact mais sans capture.
- *Correctif proposé :* au bootstrap, `pubspec.lock` devient la référence, comme le spine le prévoit déjà. Aucun changement requis au-delà de M2 et m1.

### Confirmé (aucune action)

- dynamic_color 2.1.0, sqflite 2.4.4+2 et flutter_secure_storage 11.2.0 sont les dernières versions publiées.
- `flutter create --empty` figure dans le [tutoriel officiel](https://docs.flutter.dev/learn/pathway/tutorial/create-an-app). `--platforms` est un flag CLI standard non montré dans ce tutoriel.
- [FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages) confirme : réception arrêtée après force-stop jusqu'à réouverture, permission Android 13+, `getInitialMessage` et `onMessageOpenedApp` pour l'ouverture à froid ou à chaud. Le spine (AD-9, portes) le reflète correctement.
- Les méthodes `profiles.list`, `session.create`, `prompt.submit`, `session.history`, `session.events.since`, `session.control.read`, `session.interrupt`, `file.attach`, `image.attach_bytes` et `approval.respond` sont présentes au snapshot, au HEAD actuel et au tag v2026.9.24. `PromptSubmitParams` n'a pas de clé d'idempotence (HEAD vérifié), ce qui confirme AD-5.
