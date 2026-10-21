---
title: 'Suite de l’epic 1 : connecter Hermes et retrouver ses profils (1.3 à 1.7)'
type: 'feature'
created: '2026-10-21'
status: 'done'
baseline_commit: '6f1663a8086402a9518f51de7ca922a7b425ced6'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Socle 1.1–1.2 terminé ; connexion et profils absents.

**Approach:** Figer un contrat documentaire officiel, puis livrer origine confirmée → authentification mémorisée → profils (1.4–1.7).

## Boundaries & Constraints

**Always:**
- Contrat officiel `v0.22.2`, SHA `d923a5eb487a17c0a68801bba9ef0f56c81040a8`. Fixtures synthétiques ; capacités réelles non vérifiées avant activation.
- Backend Desktop sur 9119, REST et `/api/ws`. Origine HTTPS ou HTTP strictement sur un sous-domaine `ts.net`, sans credentials, chemin, query ni fragment. Confirmation avant tout accès ; lien/QR `hermes-mobile://pair?url=<origine>` sans secret.
- `ConnectionRepository` possède connexions, capacités, profils, sélection et socket unique. Snapshots immuables, interfaces en Dart pur dans `models`, ViewModels `ChangeNotifier`, injection dans `app`. Aucun accès `data` depuis `features`.
- `ConnectionKey` UUID stable même après changement d’origine. Un SQLite, migrations en ajout seul, tables `connection_*`. Aucun secret en SQLite.
- Coffre `<ConnectionKey>/<usage>` pour mot de passe/jetons. Login JSON `hermes` sur `/auth/password-login`, cookies gérés explicitement, jetons extraits pour bearer ; refresh `/auth/native/refresh`, puis relogin si refusé. Aucun secret dans logs/diagnostics/URL ni redirection authentifiée ; pas de navigateur PKCE.
- Réutiliser thème/tokens/composants 1.2 et libellés centralisés ; clavier, texte 200 %, noms accessibles, mouvement réduit.
- Défaut : `is_default` du GET profils, puis choix explicite local prioritaire. Aucun POST modifiant le profil global.

**Décision d’Alanc (21 octobre) :** backend pas encore activé ; développer selon les docs officielles, activation ultérieure. Capture réelle 1.3/G1 différée. QR scanné par caméra Android puis deep link, saisie manuelle disponible. Changer d’origine ferme la socket et retire les anciens credentials avant réseau.

**Never:** Conversation/envoi/fichiers/push, administration serveur, capacité inventée ou validation réelle simulée.

## I/O & Edge-Case Matrix

| Cas | Résultat |
|---|---|
| Origine/lien invalide | refus avant réseau/persistance |
| Transport/auth/méthode échoue | erreurs distinctes, code namespacé, retryable, operationKey optionnelle |
| Refresh refusé | login via coffre, nouveau ticket, socket unique |
| Redirection externe | aucun secret transmis |
| Profils chargement/vide/erreur/actualisation | états distincts, aucun défaut inventé |
| Socket ouverte/reconnexion/perdue | connecté/resynchronisation/hors ligne, icône + texte |

</frozen-after-approval>

## Code Map

- `lib/main.dart::MainApp` : accueil provisoire et thème existant.
- `_bmad-output/implementation-artifacts/recherche-contrat-documentaire-epic-1.md` : routes/champs et provenance officiels.
- `lib/ui/{tokens,theme,content,gallery}.dart`, `components/{status_label,section_card}.dart` : réutiliser ; galerie séparée de la release.
- `pubspec.yaml` : réseau/coffre/routage/SQLite épinglés ; ajouter sqflite_common_ffi exact en dev pour migrations réelles. UUID via Random.secure.
- `test/{architecture_imports,visual_literals,main_app}_test.dart` : préserver frontières/thème ; règle Duration limitée aux valeurs visuelles, délais réseau hors tokens UI.

## Tasks & Acceptance

**Execution:**
- [x] `contracts/{README.md,release.json,methods.json,capabilities.json,event-mapping.json,openrpc.json,fixtures/}`, `test/contracts_test.dart` — provenance officielle, méthodes sourcées, capacités documentaires/réelles séparées, inconnu explicite, tests anti-secret/mapping.
- [x] `lib/models/{connection,profile,app_error,connection_gateway}.dart` — identités, snapshots, erreurs, port des ViewModels.
- [x] `lib/data/storage/{database,migrations,connection_store,secret_store}.dart` — connexion/sélection persistées, registre et stockage sécurisé ; tester création, migration, réouverture et stabilité de la clé.
- [x] `lib/data/{hermes_adapter,connection_repository}.dart` — contrat documentaire, login/refresh/ticket, socket unique/reconnexion bornée, capacités et profils ; transport/horloge injectés.
- [x] `lib/features/connection/{connection_view_model,connection_view}.dart`, `lib/features/profiles/{profiles_view_model,profiles_view}.dart` — origine, confirmation, mot de passe puis profils actualisables, avec états et sémantique accessibles.
- [x] `lib/app/{bootstrap,routes}.dart`, `lib/main.dart`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/network_security_config.xml` — composition, restauration, deep link et exception HTTP limitée.
- [x] `tool/generate_pairing_qr.py`, `README.md`, `lib/ui/{content,gallery}.dart` — QR sans secret, procédure et composants sur fixtures.
- [x] `test/{connection_repository,connection_store,connection_flow,profiles}_test.dart` — matrice, concurrence socket, changement d’origine, sélection persistée, refresh et sémantique.

**Acceptance Criteria:**
- Given un transport conforme au contrat documentaire, when origine confirmée et authentifiée, then connexion persistée et profils affichés sans mutation globale.
- Given une reconnexion avec jetons invalidés, when le refresh échoue, then le mot de passe sécurisé permet le nouveau login sans nouvelle saisie.
- Given une capacité obligatoire absente ou non vérifiée, when la connexion est évaluée, then la fonction concernée apparaît et l’acceptation reste ouverte.
- Given le téléphone réel, when le parcours est testé avec texte 200 % et TalkBack, then origine, erreurs, profils et sélection restent utilisables et identifiables.

## Implementation Notes

Lots ordonnés : contrat/modèles ; données ; interface/composition. Capture réelle différée par Alanc.

Audit initial du coordinateur avant revue : diff complet lu (54 fichiers), tâches vérifiées et six lignes de matrice reliées aux tests effectivement exécutés. Première sortie `flutter test --machine` : 57 réussites, aucun test ignoré ; preuves dans `C:/Users/alanc/AppData/Local/Temp/hermes-spec-connexion-yvagbam0/tests-machine.jsonl`. Analyse sans anomalie, 3 tests Python verts, build release et signature vérifiés. APK SHA-256 `73db66a8174bfe3d134e40ff1ed3df01215ef077d3e0158d0a4ad36bb702c718` ; aucun source Dart postérieur au build.

L’AC téléphone/TalkBack demeure explicitement différé selon la décision approuvée ; les assertions sémantiques et 200 % locales ne sont pas une validation sur appareil réel. Détails : [rapport d’implémentation](rapport-implementation-connexion-profils.md).

## Spec Change Log

## Review Triage Log

| ID | Verdict | Route / groupe | Preuve |
|---|---|---|---|
| B1 | medium | patch G1 | Aucun pingInterval ni délai de vie sur la WebSocket IO ; un réseau muet ne déclenche aucun callback. |
| B2 | medium | patch G2 | initState précède restore ; didUpdateWidget ne traite que incomingLink : origine restaurée absente. |
| B3 | medium | patch G3 | La route racine non authentifiée ouvre ConnectionView sans bouton reconnect ; le port reconnect existe déjà. |
| B4 | medium | patch G4 | authenticate garde authenticated=true pendant un nouveau login refusé ; _submit lit ce booléen et navigue. |
| B5 | medium | patch G5 | _loadProfiles absorbe auth.refused sans invalider authenticated ni fermer la socket. |
| B6 | medium | patch G6 | confirmOrigin ferme la socket avant clear/save ; _run ne modifie que error/busy sur exception. |
| B7 | medium | patch G7 | Le code RPC 5035 appelle _lostSocket sans fermeture ; après trois essais aucune reconnexion ne la ferme. |
| B8 | medium | patch G8 | Après gateway.ready seul le completer ready est borné ; aucune échéance pour la réponse capabilities. |
| B9 | medium | patch G9 | jsonDecode lance FormatException ; _response la transforme en transport.unreachable retryable. |
| B10 | low | patch G10 | GatewayReadyPayload exige skin ; fixture gateway-ready absent, test références ne valide pas les payloads. |
| E1 | medium | patch G1 | Même chemin réseau muet que B1 : aucun détecteur de vie IO. |
| E2 | medium | patch G5 | Même refus de renouvellement absorbé par _loadProfiles que B5. |
| E3 | medium | patch G6 | Même fermeture avant échec persistance que B6 ; snapshot précédent reste connecté. |
| E4 | medium | patch G2 | Même restauration asynchrone après initState que B2. |
| E5 | medium | patch G9 | Même FormatException classée transport que B9. |
| E6 | medium | patch G11 | result est seulement contrôlé Map ; clé absente ou chaîne devient absence confirmée au lieu de réponse invalide. |
| E7 | low | rejet | join bufferise sans limite : dommage réel avec serveur surdimensionné, peu probable sur origine Hermes explicitement approuvée ; limite et branches supplémentaires disproportionnées pour ce cas rare. |
| V1 | medium | patch G12 | Gap pré-vérifié : FakeTransport contourne sérialisation IO ; test réel ne contrôle que redirection, pas login/cookies/bearer. |
| V2 | medium | patch G13 | Gap pré-vérifié : CI exécute Flutter seulement ; suite Python de validation origine jamais appelée. |

Groupes G1–G13 : même défaut uniquement pour les doublons explicitement cités. Tous les correctifs retenus restent locaux, sans extension du contrat public ; aucun écart nécessitant une nouvelle décision produit.

## Verification

- SDK épinglé : analyse, tests complets et APK release signé verts ; preuves de commandes conservées.
- Après activation : capture PC/Pixel, auth/profils/reconnexion/TalkBack avant acceptation réelle de 1.3/G1.

Vérification finale après revue : 77 tests Flutter réussis, aucun ignoré ; 3 tests Python réussis ; analyse sans anomalie et lockfile respecté. Les 13 groupes G1–G13 sont corrigés et couverts, E7 rejeté selon le triage. Les preuves finales portent le préfixe `final-` dans le répertoire indiqué plus haut. APK signé SHA-256 `bf84d8acd59a4645341fcd064b1901eda141bebef4ab2dcc152eb0f6bf7e6703`, 51 983 467 octets ; aucun source Dart postérieur au build. Le statut done porte sur le périmètre documentaire et implémenté approuvé ; il ne ferme pas la validation réelle différée.
