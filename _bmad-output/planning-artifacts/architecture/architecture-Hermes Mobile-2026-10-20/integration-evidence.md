# Preuves et limites — 20 octobre 2026

Appui technique à la proposition, pas certification de l'installation. Justification et décisions dans `.memlog.md` ; extraits amont dans `.working/`.

## Réalité locale

Dépôt de planning et outils BMAD, sans code application repéré. PRD final/addendum, DESIGN, EXPERIENCE et contrat d'évolution UI lus. Alanc confirme un add-on Home Assistant, « dernière version » et Tailscale. Dépôt/build et URL native inconnus. Aucun appel au serveur personnel, changement de configuration ou installation de SDK/package effectués.

## Hermes amont

`git ls-remote` a renvoyé HEAD `5eee5d02e85eaad32dfade3030d27fcfad204e72`. Ce commit ne désigne pas le serveur d'Alanc. Index des fichiers/URLs consultés : `.working/hermes-source-index.json`.

| Source primaire épinglée | Observation |
| --- | --- |
| [OpenRPC version 1](https://github.com/NousResearch/hermes-agent/blob/5eee5d02e85eaad32dfade3030d27fcfad204e72/apps/shared/src/gateway-contract.openrpc.json) | Profils, sessions, replay, soumission, interruption, pièces jointes et approbations présents. `file.attach` accepte chemin serveur ou `data_url` et retourne une référence. `session.create` propose `close_on_disconnect=false`. Replay avec epoch/séquence/troncature. Pas de clé d'idempotence exposée dans le schéma observé de `prompt.submit` ; ne pas importer la garantie d'une autre méthode. |
| [Routes WS](https://github.com/NousResearch/hermes-agent/blob/5eee5d02e85eaad32dfade3030d27fcfad204e72/hermes_cli/web_routers/chat_ws.py#L702) | `/api/ws` délègue au gateway structuré avec identité authentifiée. Le flux `/api/events` ne démontre pas à lui seul un journal durable. |
| [Routes fichiers](https://github.com/NousResearch/hermes-agent/blob/5eee5d02e85eaad32dfade3030d27fcfad204e72/hermes_cli/web_routers/files.py#L654) | Upload JSON/multipart et téléchargement. Multipart avec temporaire puis renommage. Cela ne prouve pas la référence du fichier dans un message ou les droits de l'add-on. |
| [Routes profils](https://github.com/NousResearch/hermes-agent/blob/5eee5d02e85eaad32dfade3030d27fcfad204e72/hermes_cli/web_routers/profiles.py#L807) | Découverte REST visible. Ne pas modifier le profil actif global du dashboard pour chaque sélection mobile : le scope du fil doit rester explicite. |

La [documentation API Server](https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server) expose plusieurs surfaces avec des garanties distinctes. Les uploads de documents génériques restent une limitation de l'API compatible OpenAI : elle ne suffit pas seule à FR-5/6. Ses garanties d'idempotence ne prouvent pas celles du WebSocket.

La [documentation Desktop](https://hermes-agent.nousresearch.com/docs/user-guide/desktop#connecting-to-a-remote-backend) décrit les connexions distantes. Le [Dashboard](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard#connecting-hermes-desktop-to-a-remote-backend) distingue disponibilité HTTP, auth et socket. L'essai du couple proxy/add-on reste nécessaire.

## Stack et starter proposés

| Source primaire | Constat | Limite |
| --- | --- | --- |
| [Flutter releases](https://docs.flutter.dev/release/release-notes) | 3.47.0 stable listée. | Version candidate disponible, dernier correctif non déterminé. L'index JSON de releases a renvoyé 404 ; aucune version n'en est déduite. |
| [Starter Flutter](https://docs.flutter.dev/learn/pathway/tutorial/create-an-app), [MVVM](https://docs.flutter.dev/app-architecture/guide) | Projet minimal `flutter create --empty`, vues/ViewModels/repositories/services. | Aucun projet généré ni build effectué. |
| [dynamic_color](https://pub.dev/packages/dynamic_color) | 2.1.0, palette Android S+ et variantes claire/sombre. | Secours et contraste réel à contrôler. |
| [sqflite](https://pub.dev/packages/sqflite) | 2.4.4+2, SQLite mobile, transactions/migrations. | Pas une base chiffrée ; aucun secret dedans. |
| [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) | 11.2.0, stockage sécurisé plateforme. | Sauvegarde/révocation à vérifier au bootstrap. |
| [firebase_messaging](https://pub.dev/packages/firebase_messaging) | 17.0.0, FCM Flutter Android/iOS. | Dépendances transitives et compilation non testées. |
| [Starter Expo](https://docs.expo.dev/get-started/create-a-project/) | Alternative officielle Android/iOS examinée. | Non retenue dans la proposition ; aucune version imposée. |

Ces packages correspondent aux responsabilités proposées ; ils n'ont pas été résolus ensemble. Bootstrap : SDK/Dart exacts, lockfile, contraintes plateformes et compilation. Le runtime observateur attend G3.

## Réseau et notifications

[Tailscale Serve](https://tailscale.com/docs/features/tailscale-serve) permet une exposition HTTPS interne au tailnet. Option pour G1, pas preuve d'exposition de l'add-on. Aucune configuration Serve/Funnel modifiée.

La [réception FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages) couvre permissions et ouverture depuis une notification. L'arrêt forcé Android dans les réglages requiert une réouverture avant reprise de réception. La [réception Android](https://firebase.google.com/docs/cloud-messaging/android/receive-messages) distingue affichage OS et callback. Socket en arrière-plan et notification locale programmée à l'envoi ne prouvent pas FR-9.

FCM ajoute un fournisseur externe ; l'observateur ajoute un élément à déployer. Source persistante, identité de tour, rattrapage après panne et lien vers le fil doivent être démontrés. L'outbox ne donne pas de garantie exactement une fois à travers le fournisseur.

## Contrat à relever sur l'add-on

1. Dépôt/build exact, origine native, préfixe proxy, accès PC puis téléphone.
2. Auth REST/WS, tickets, expiration et refus ; captures sans secrets.
3. Deux profils/sessions, historique, absence de mutation du profil actif global.
4. Acceptation, identité/corrélation, terminaux, arrêt ; coupure avant/après admission sans seconde soumission.
5. Outils et replay après troncature/redémarrage ; source persistante des fins manquées.
6. Image/PDF/document : limites, octets/références reçus côté Hermes et historique ; résultats si FR-14 retenu.
7. Suivi et outbox déployés, push Android réel et retour au bon fil. Les minutages de maquette ne sont jamais une preuve.

Les accès et le corpus manquants empêchent la validation d'intégration ; l'amont public ne les remplace pas.

## Add-on installé (fourni par Alanc, 2026-10-20)

- Dépôt : https://github.com/WolframRavenwolf/hermes-ha-addon, HEAD `64cdcb5` (14/10/2026), `config.yaml` version 1.3.9.
- `enable_desktop_backend` (désactivé par défaut) lance le backend officiel `hermes -p default serve --host 0.0.0.0 --port 9119 --skip-build` (`desktop-backend.sh`, `desktop-backend-launcher.py`). Port 9119 non mappé par défaut ; il faut le mapper dans Réseau. HTTP en clair, prévu pour LAN, VPN ou Tailscale uniquement.
- Auth : plugin `dashboard_auth/basic` (Hermes v2026.9.24), utilisateur `hermes` et hash de `access_password`. Jetons HMAC sans état : accès 12 h, refresh 30 j, tickets WS. Le lanceur retire `HERMES_DASHBOARD_BASIC_AUTH_SECRET`, donc le secret est aléatoire à chaque démarrage (`secrets.token_bytes(32)`) et un redémarrage invalide les jetons.
- Version de Hermes : `git_ref` vide signifie la dernière release stable vérifiée au premier clone ; `auto_update: false` la fige. Le tag installé reste à lire sur l'instance.
- Les URL `:8123/0a6523c6_hermes_agent` et `:8123/config/app/...` sont l'interface et l'ingress de Home Assistant, pas une URL native pour l'app.
