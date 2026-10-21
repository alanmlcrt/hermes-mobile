# Implémentation — connexion et profils

Date : 21 octobre 2026. Spec : [spec-1-suite-connexion-profils.md](spec-1-suite-connexion-profils.md). Référence documentaire : Hermes `v0.22.2`, SHA `d923a5eb487a17c0a68801bba9ef0f56c81040a8`. Aucun accès au serveur personnel, aucune capture réelle ni validation G1 simulée.

## Livré

- Contrat dans `contracts/` : provenance, méthodes REST/RPC sourcées, capacités documentaires séparées de leur état réel, mapping avec événement inconnu et fixtures synthétiques contrôlées contre les secrets. L’extrait OpenRPC conserve six méthodes et les 22 schémas référencés ; `tool/extract_openrpc.py` le reconstruit depuis le fichier officiel épinglé.
- Modèles Dart pur : UUID local stable, identités de profils sensibles à la casse, snapshots immuables, erreurs locales namespacées avec `retryable` et `operationKey?`, port `ConnectionGateway`.
- Un SQLite et deux migrations en ajout seul : connexion et sélection locale, sans secret. Coffre sous `<ConnectionKey>/<usage>` pour mot de passe et jetons ; effacement avant changement d’origine et suppression d’un RT obsolète lors d’un login sans RT.
- Adaptateur : login JSON `basic`/`hermes`, extraction explicite des cookies simples et préfixés, REST bearer, refresh natif puis relogin depuis le coffre, nouveau ticket à chaque socket. Le ticket utilise un sous-protocole ; aucune URL authentifiée. Les redirections REST et WS sont refusées.
- Repository unique : opérations sérialisées, une seule socket, états connecté/resynchronisation/hors ligne, retries bornés avec horloge et transport injectables. Les cycles ouverture/perte immédiate sont également bornés ; une période stable rétablit le budget de reconnexion.
- ViewModels `ChangeNotifier`, formulaires scrollables, confirmation obligatoire de l’origine, mot de passe effacé du champ après soumission, profils actualisables et sélection accessible locale. Défaut uniquement issu de `is_default`, sans POST de modification globale.
- Composition explicite, restauration, réception des liens Android par le routeur, exception HTTP Android limitée à `ts.net` et validation applicative limitée à ses sous-domaines. Galerie séparée de la release, avec le composant de sélection de profil dans ses quatre variantes.
- Générateur SVG du QR sans secret, procédure README et versions exactes de `crypto` et `sqflite_common_ffi` dans le lockfile.

## Vérification

SDK utilisé : Flutter **3.47.7**, Dart **3.13.5**, depuis `C:/Users/alanc/fvm/versions/3.47.7`.

Les sorties intégrales sont conservées dans **`C:/Users/alanc/AppData/Local/Temp/hermes-spec-connexion-yvagbam0/`** :

| Preuve | Commande / résultat |
|---|---|
| `sdk.log` | `flutter --version --machine` : versions épinglées confirmées |
| `final-pub.log` | `flutter pub get --enforce-lockfile` : succès |
| `final-analyze.log` | `flutter analyze` : aucune anomalie |
| `final-tests-machine.jsonl` | `flutter test --machine` : **77 tests passés**, aucun ignoré, noms et résultats complets |
| `final-python.log` | `python -m unittest discover -s tool -p 'test_*.py'` : **3 tests passés**, origines autorisées/refusées et erreur CLI sans secret ni fichier |
| `qr.log`, `pairing.svg` | génération effective d’un QR synthétique avec `qrcode==8.2` : succès |
| `final-build-release.log` | `flutter build apk --release` : succès, APK release |
| `final-signature.log` | `apksigner verify --print-certs` : succès, certificat Hermes Mobile |

APK : `build/app/outputs/flutter-apk/app-release.apk`, version existante `0.1.0+1`. Aucun APK n’a été distribué ou installé dans cette tâche. `git diff --check` est passé.

Dernier APK signé : **51 983 467 octets**, SHA-256 **`bf84d8acd59a4645341fcd064b1901eda141bebef4ab2dcc152eb0f6bf7e6703`** (`final-apk.json` dans le répertoire de preuves). La signature a été revérifiée après ce dernier build ; aucun source Dart n'est postérieur à l'APK.

### Revue et corrections

Trois revues indépendantes Orca ont produit 19 constats, tous classés dans la spec. Les doublons ont donné 13 groupes corrigés : détection de perte silencieuse par ping IO, restauration du formulaire et reprise via coffre, invalidation de session après refus, état sûr après échec de stockage, fermeture immédiate de socket retirée, échéance des capacités, validation des réponses et fixture conforme. Les nouveaux tests passent par HTTP et WebSocket locaux réels ; les tests Python font désormais partie de la CI.

Le constat restant concerne un corps HTTP démesuré : risque faible sur une origine explicitement approuvée, rejeté selon la règle de triage du workflow car ajouter une limite et de nouveaux chemins de contrôle serait disproportionné pour cet usage rare. Aucun constat bloquant ne subsiste. La première analyse après corrections signalait une accolade manquante ; correction directe, puis analyse et suite complète à nouveau vertes.

### Couverture de la matrice

| Ligne de la spec | Tests exécutés |
|---|---|
| Origine/lien invalide avant réseau et persistance | `connection_repository_test` : origine/lien invalide ; `connection_flow_test` : confirmation avant réseau, deep link prérempli et lien Android reçu par le routeur ; tests Python du QR |
| Erreurs transport/auth/méthode distinctes | `connection_repository_test` : transport, auth, méthode absente et redirection ; méthode RPC absente ; formulaires avec refus d’auth |
| Refresh refusé, relogin via coffre, nouveau ticket, socket unique | `connection_repository_test` : refresh refusé, requêtes concurrentes et maximum d’une socket active |
| Aucun secret transmis à une redirection externe | `hermes_adapter_test` : serveurs HTTP locaux, redirections REST et WS avec zéro requête reçue par la cible ; vrai upgrade WS sans query de secret |
| Profils chargement/vide/erreur/actualisation, sans défaut inventé | `connection_repository_test` : tous ces états ; choix local prioritaire ; `profiles_test` : vide et erreur distincts, sélection accessible |
| Socket ouverte/reconnexion/perdue | `connection_repository_test` : connexion, perte, retries bornés et hors ligne ; cycles ouverture/perte immédiate ; retry périmé après changement d’origine ; `connection_flow_test` : libellé connecté ; galerie : les trois icônes et textes |

Les tests SQLite utilisent réellement `sqflite_common_ffi` : création, migration v1→v2, fermeture/réouverture, conservation du choix et stabilité de la clé. Les widgets couvrent le texte 200 %, le mouvement réduit et le clavier, avec un formulaire en portrait 375×700 et en paysage 700×375 ; la sélection des profils est vérifiée dans l’arbre sémantique.

## Reste ouvert / risques

- **Validation réelle différée par décision d’Alanc** : build installé de l’add-on, capture 1.3/G1, capacités du backend activé, login/profils/reconnexion PC et Pixel, puis TalkBack et texte 200 % sur téléphone. Les fixtures et tests locaux ne remplacent aucune de ces preuves.
- Le build produit un avertissement non bloquant sur une police `CupertinoIcons` non embarquée ; les nouveaux écrans utilisent les icônes Material. À surveiller lors de la validation visuelle réelle.
- Aucune conversation, aucun envoi, fichier, push ou écran d’administration ajouté. Aucun POST de sélection globale ni push effectué. Le bloc d’intention approuvé est préservé ; le coordinateur a terminé l'audit local ; la livraison est enregistrée dans un commit local. L'acceptation sur serveur et téléphone réels demeure différée.
