---
title: 'Story 6.4 — Récupérer les fichiers produits par Hermes'
type: 'feature'
created: '2026-10-30'
status: 'done'
baseline_commit: 'a6064a3'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-6-3-autoriser-refuser-action.md'
  - '{project-root}/contracts/README.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Depuis la 6.3, le fil montre les activités mais un fichier écrit par Hermes (`write_file`) n'y apparaît que comme un chemin dans une ligne d'activité. Alanc ne peut ni le télécharger ni l'ouvrir depuis son téléphone, alors que la porte G4 a retenu FR14.

**Approach:** Chaque `tool.complete` de `write_file` avec un `args.path` absolu produit une carte « fichier résultat » dans le fil (nom, type, taille si connue, état). La carte télécharge le fichier par `GET /api/fs/download` avec l'authentification du profil et de la session, le range dans un emplacement `results/` séparé des pièces jointes, puis l'ouvre avec l'application système adaptée sur demande. Un chemin seulement cité, ou relatif, ne produit aucune carte.

## Boundaries & Constraints

**Always:**
- Seul un `tool.complete` de `write_file` dont `args.path` est absolu (`/…` ou `Lettre:\…`) produit une carte. Le nom est le dernier segment du chemin ; le type vient de l'extension, puis du `Content-Type` reçu ; la taille n'est affichée que si `Content-Length` est connu.
- La carte est un élément du fil, placée après l'activité qui l'a produite. Son état est dit par un libellé, pas seulement par une couleur ; ses actions ont des noms accessibles distincts et des cibles d'au moins 48 dp.
- Le téléchargement est authentifié (Bearer), avec `profile` et `session_id` du fil ; redirections refusées ; aucune credential vers une autre origine.
- Les octets vont dans un emplacement privé `results/<connexion>/<profil>/<session>/<clé>` distinct de `attachments/<DraftKey>/` ; le nom local n'est jamais le nom serveur.
- Un échec affiche « Échec » et « Réessayer », sans jamais présenter le fichier comme récupéré. Un téléchargement interrompu par un redémarrage devient un échec réessayable. Un fichier local disparu redevient téléchargeable.
- Aucun fichier n'est exécuté automatiquement : l'ouverture n'a lieu que sur action d'Alanc, par l'application système adaptée au format.
- Un chemin absolu affiché par une activité qui n'est pas un `write_file` réussi porte la mention « Chemin sur Hermes — non récupérable depuis le téléphone ». Le texte des réponses reste inchangé.
- Le téléchargement et l'ouverture sont deux actions distinctes : « Télécharger », puis « Ouvrir » quand la copie locale existe.

**Décisions d'Alanc (2026-10-30) :**
- La mention « non récupérable » ne s'applique qu'aux chemins montrés par les activités, jamais au texte des réponses (aucune détection dans le Markdown).
- La 6.4 reste entière (affichage + téléchargement + ouverture), malgré sa taille (~3 100 tokens).

**Never:**
- Pas de détection de chemins dans le texte des réponses ; les activités autres que `write_file` ne produisent jamais de carte, seulement la mention « non récupérable » (décision G4).
- Pas de téléchargement automatique à l'apparition, ni d'ouverture automatique après téléchargement.
- Pas de nouvel événement de contrat, pas de reconstruction des résultats depuis `session.history`.
- Pas de modification du stockage ni du cycle de vie des pièces jointes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Fichier produit | `tool.complete`, `write_file`, `/home/u/rapport.pdf` | carte « rapport.pdf » (PDF), état « Disponible », action « Télécharger », après la ligne d'activité | — |
| Chemin relatif | `args.path = "notes.md"` | aucune carte ; l'activité reste inchangée | — |
| Chemin cité | réponse texte « voir /home/u/x.csv » | texte inchangé, aucune carte | — |
| Chemin d'activité non résultat | activité `read_file`, `/home/u/x.csv` | mention « Chemin sur Hermes — non récupérable depuis le téléphone » sous le chemin, aucune action | — |
| Téléchargement réussi | carte disponible, appui « Télécharger » | état « Téléchargement… », puis « Téléchargé » + taille ; action « Ouvrir » | — |
| Fichier absent du serveur | `404` | état « Échec », message « Ce fichier n'existe plus sur Hermes. », « Réessayer » | réessai autorisé |
| Auth expirée | `401` puis refresh réussi | téléchargement repris une fois, sans changer de profil | refresh impossible → « Échec » |
| Hors connexion | lien coupé | action désactivée, carte conservée | message « Téléchargement impossible hors connexion » |
| Reprise après redémarrage | état `downloading` en base | état « Échec — interrompu », « Réessayer » ; fichier partiel supprimé | — |
| Fichier local absent | état `downloaded`, fichier effacé | état « Disponible », « Télécharger » de nouveau | — |
| Ouverture impossible | aucune application pour le type | message « Aucune application ne peut ouvrir ce fichier. » | état local inchangé |
| Doublon d'événement | même `tool.complete` rejoué | une seule carte (clé stable) | — |
| Taille inconnue | pas de `Content-Length` | nom et type affichés, taille omise | — |

</frozen-after-approval>

## Code Map

- `lib/models/result.dart` (nouveau) -- `ResultState`, `ResultDownloads` (`download` écrit dans un chemin cible, rend octets et type), `ResultOpener` (`open` lève `result.open` si aucune application).
- `lib/models/timeline.dart` -- `ResultItem` (`k: 'result'`, `resultVersion: 1`, champs `resultKey`, `path`, `name`, `mediaType`, `bytes?`, `localKey?`, `state`, `errorCode?`), cas explicite dans `TimelineItem.fromJson` ; `ResultGateway` (`downloadResult`, `openResult`).
- `lib/data/hermes_adapter.dart` / `IoHermesTransport` -- `download` binaire : `GET /api/fs/download?path=&profile=&session_id=`, Bearer, pas de redirection, flux vers `.part` puis renommage ; `404` → `result.missing`, `403` → `result.refused`, `401` → `auth.refused`, `5xx`/`429` → `transport.server` réessayable. Réutiliser `networkTimeout` en délai d'inactivité.
- `lib/data/connection_repository.dart` -- implémenter `ResultDownloads` via `_authorized` (un seul renouvellement) ; ajouter `Capability('result_download', present)` à `_documentaryCapabilities`.
- `lib/data/storage/result_files.dart` (nouveau) -- miroir d'`AttachmentFiles` : racine injectable, segments `[a-zA-Z0-9-]+` (hacher les identifiants si besoin), `results/…`, création du dossier, `remove`.
- `lib/data/result_opener.dart` (nouveau) -- `DeviceResultOpener` avec `open_filex` 5.0.0 ; traduire tout refus en `result.open`.
- `lib/data/conversation_repository.dart` -- créer `ResultItem` dans la branche `EventEffect.activity` quand `m.activityCompleted && name == 'write_file'` et que le chemin `args.path` des détails fusionnés est absolu (insérer après l'activité, dédupliquer par `resultKey` = hash de `eventKey`) ; `downloadResult`/`openResult` ; `_withAttachments` étendu aux résultats (vérifier l'existence locale, `downloading` → échec interrompu) ; conserver le résultat lors du rejeu, pas lors du snapshot.
- `lib/ui/components/result_card.dart` (nouveau) -- modèle `ApprovalCard`/`AttachmentList` : en-tête, type, taille, libellé d'état en région live, actions `Wrap` ≥ 48 dp, libellés sémantiques « Télécharger le fichier … » / « Ouvrir le fichier … ».
- `lib/ui/components/activity_line.dart` -- mention « Chemin sur Hermes — non récupérable depuis le téléphone » sous le résumé quand `ActivityDetails.summary` est un chemin absolu et que l'activité n'a pas produit de `ResultItem` ; ne pas l'ajouter aux commandes ni aux URL.
- `lib/ui/content.dart` -- libellés et erreurs `result.*` (disponible, téléchargement, téléchargé, échec, interrompu, absent, hors connexion, aucune application, illisible) + taille lisible o/Ko/Mo.
- `lib/features/conversation/draft_view.dart` / `draft_view_model.dart` -- branche `ResultItem`, `vm.downloadResult`, `vm.openResult`, `canDownloadResult` (lien connecté, capacité `result_download` non absente) ; erreur d'ouverture dans `vm.error`.
- `lib/app/bootstrap.dart`, `lib/app/routes.dart` -- injecter `downloads: repository`, `ResultFiles()`, `DeviceResultOpener()` dans `ConversationRepository` ; passer `conversation` comme `ResultGateway` au view model.
- `pubspec.yaml` -- `open_filex: 5.0.0`, `mime: 2.0.0` (déjà transitif), versions exactes comme le reste.
- `contracts/README.md` -- paragraphe 6.4 : identification par `write_file` absolu, `GET /api/fs/download`, stockage séparé, échecs ; `test/contracts_test.dart` -- retirer `result_download` de `notTracked`.
- Contraintes : `test/architecture_imports_test.dart` (features/models sans `data/`), `test/visual_literals_test.dart` (styles dans tokens), migrations en ajout seul, pièces jointes intactes.

## Tasks & Acceptance

**Execution:**
- [x] `contracts/README.md`, `test/contracts_test.dart` -- documenter la 6.4, suivre `result_download` -- contrat.
- [x] `lib/models/result.dart`, `lib/models/timeline.dart` -- `ResultItem`, interfaces, sérialisation défensive -- modèle.
- [x] `lib/data/hermes_adapter.dart`, `test/support/connection_fakes.dart`, `test/hermes_adapter_test.dart` -- téléchargement binaire authentifié et mapping d'erreurs -- transport.
- [x] `lib/data/connection_repository.dart` -- `ResultDownloads` + capacité -- accès.
- [x] `lib/data/storage/result_files.dart`, `lib/data/result_opener.dart`, `test/result_files_test.dart` -- stockage séparé et ouverture système -- fichiers.
- [x] `lib/data/conversation_repository.dart` -- création, hydratation, téléchargement, ouverture -- logique.
- [x] `lib/ui/components/result_card.dart`, `lib/ui/components/activity_line.dart`, `lib/ui/content.dart`, `lib/features/conversation/draft_view.dart`, `draft_view_model.dart`, `lib/app/bootstrap.dart`, `routes.dart` -- carte, mention de chemin et branchement -- interface.
- [x] `test/result_flow_test.dart`, `test/result_card_test.dart`, `test/resync_test.dart`, `test/activity_line_test.dart` -- chaque ligne de la matrice, dont rejeu, redémarrage, mention de chemin et accessibilité -- preuves.
- [x] `pubspec.yaml`, `pubspec.lock` -- ajouter `open_filex` 5.0.0 et `mime` 2.0.0, régénérer le lock et vérifier le build Android -- dépendances.

**Acceptance Criteria:**
- Étant donné un `write_file` absolu terminé, quand le fil est affiché, alors une carte nomme le fichier et son type, avec une action « Télécharger » atteignable au lecteur d'écran et en texte agrandi.
- Étant donné un chemin cité dans une réponse ou un `args.path` relatif, quand le fil est affiché, alors aucune carte de résultat n'apparaît.
- Étant donné une activité qui affiche un chemin absolu sans l'avoir produit, quand elle est dépliée ou lue, alors la mention « non récupérable depuis le téléphone » est présente et aucune action de téléchargement n'est proposée.
- Étant donné un fichier téléchargé, quand l'app redémarre puis rouvre la conversation, alors la carte reste « Téléchargé » et « Ouvrir » fonctionne tant que la copie locale existe.
- Étant donné un téléchargement échoué, quand l'échec survient, alors la carte ne dit jamais « Téléchargé » et propose « Réessayer ».
- Étant donné une ouverture demandée, quand aucune application ne gère le type, alors un message clair apparaît et le fichier reste téléchargé.

## Implementation Notes

- `ResultItem` garde l'identité de l'activité d'origine (`resultKey = sha256("result:" + eventKey)`), ce qui rend le rejeu idempotent sans table dédiée. La clé locale est le même hachage ; `ResultFiles` re-hache tout segment qui n'est pas `[a-zA-Z0-9-]+`, donc aucun chemin ni nom serveur n'atteint le disque.
- Le téléchargement passe par `_authorized` : un seul renouvellement sur `401`, profil et session du fil inchangés. `IoHermesTransport` écrit dans `.part`, refuse les redirections et compte les octets reçus ; un flux inactif suit `networkTimeout`.
- L'hydratation de la projection distingue un téléchargement vivant (`_downloading`) d'un état `downloading` relu après redémarrage : ce dernier devient `interrupted` et la copie partielle est supprimée. Une copie `downloaded` disparue redevient `available`.
- La mention « non récupérable » n'est calculée que dans `ActivityLine`, à partir du résumé de l'activité ; les commandes, URL et le texte des réponses n'y passent jamais. Une activité ayant produit une carte n'affiche pas la mention.
- Aucun fichier n'est téléchargé à l'apparition ni ouvert après un téléchargement : les deux actions restent des appuis distincts de la carte.
- Vérification : `flutter analyze` sans problème, `flutter test` 616 réussis / 17 ignorés, `flutter build apk --debug` réussi avec `open_filex` 5.0.0.

## Spec Change Log

## Review Triage Log

- **B1 — `result_download` déclarée `unverified` au lieu de `present`** (blind) — **faux**. Toutes les capacités documentaires de `ConnectionRepository` restent `unverified` (`connection_repository.dart:53-69`), y compris `approval` et `clarify` livrées avant ; `canDownloadResult` ne bloque que `absent`, et l'écran profils applique le même libellé à toutes. Aucun consommateur n'attend `present`.
- **B2 — aucun passage à `absent` ; un 404 affiche « fichier disparu »** (blind) — **faux**. La matrice impose `result.missing` pour un 404 (spec, ligne 54), et la branche `absent` reste atteignable depuis n'importe quel snapshot de capacité ; l'absence de transition est le même choix documentaire que B1, pas une erreur de la carte.
- **B3 — la carte affiche le texte brut d'un code d'erreur d'un autre domaine** (blind) — **corrigé**. `Content.resultError` ne traduit que les codes `result.*` et rend « Le fichier n'a pas pu être récupéré. » sinon (`content.dart:306-309`, `result_card.dart:52-54`), avec test dédié dans `result_card_test.dart`.
- **B4 — taille obsolète après suppression de la copie locale** (blind) — **faux**. `bytes` conserve la taille annoncée par le serveur (`Content-Length`), pas la taille de la copie locale ; elle est effacée à chaque échec (`clearBytes`) et reste une métadonnée distante valable quand la carte redevient « Disponible ». Aucun écran n'affirme qu'un fichier local de cette taille existe.
- **B5 — un `ResultItem` du tour 0 reste détaché de son activité** (blind) — **corrigé**. `ResultItem.atTurn` et `_startTurn` retaguent désormais tous les éléments du tour 0, résultat compris (`timeline.dart:505-516`, `conversation_repository.dart:1375-1385`) ; `result_flow_test.dart` couvre l'ordre carte/activité.
- **B6 — `fromJson` accepterait une ligne sans `resultVersion` et créerait une carte vide** (blind) — **faux**. `ResultItem.fromJson` n'est appelé que pour `k == 'result'` (`timeline.dart:164`), clé qui n'existait pas avant cette story ; toute ligne ainsi écrite porte `resultVersion: 1`. Le repli ne peut concerner qu'une base corrompue, pas un fil produit par l'app.
- **B7 — taille déclarée non vérifiée contre les octets écrits, pas de plafond** (blind) — **faux**. La spec fait de `Content-Length` la seule source de taille affichée (ligne 26), et le flux Dart applique la longueur annoncée ; aucun plafond n'est demandé par l'intention. Le transport écrit bien chaque chunk et supprime le `.part` sur erreur (`hermes_adapter.dart:155-194`).
- **B8 — `ResultFiles.file` ne crée pas le dossier** (blind) — **faux**. Le seul écrivain est `IoHermesTransport.download`, qui crée le parent récursivement avant d'ouvrir le `.part` (`hermes_adapter.dart:130`) ; `ResultFiles` rend le chemin prévu par le code map et le téléchargement de bout en bout est testé.
- **B9 — `DeviceResultOpener` réduit tous les refus à « aucune application »** (blind) — **corrigé**. `fileNotFound` et `permissionDenied` donnent `result.unreadable`, `noAppToOpen` et `error` donnent `result.open` (`result_opener.dart:25-32`) ; `result_opener_test.dart` couvre les quatre issues.
- **B10 — `result.unavailable` fourre-tout, `result.offline` jamais levé** (blind) — **faux**. Le hors-connexion est traité avant le transport par `resultBlockedReason`, et les exceptions inconnues retombent sur le message générique de B3 ; `downloads == null` n'est atteignable que par un câblage de test incomplet, pas par les routes de production.
- **B11 — copies `results/` orphelines quand la carte disparaît** (blind) — **faible, rejeté**. Une carte ne disparaît que lors d'un remplacement par snapshot, limitation acceptée et documentée ; aucun geste utilisateur ne la supprime. Ajouter un nettoyage au `_setResultState`/`_fromHistory` introduirait un cycle de vie que la story exclut explicitement.
- **B12 — plusieurs chemins et branches sans test** (blind) — **moyen, corrigé pour les chemins décisifs**. Ajout de `result_widget_test.dart` (carte → view model → gateway), du test d'hydratation en vol et de concurrence avec `downloadGate`, des messages d'erreur de carte et des bornes de `Content.resultSize`. Les variantes `downloads == null` et capacité `absent` restent des gardes défensives sans chemin utilisateur.
- **B13 — un chemin venu de `args_text` ne produit pas de carte** (blind) — **faux**. La spec exige `args.path` (ligne 26) et `args_text` n'est qu'un repli d'affichage ; s'en servir créerait des cartes pour des chemins seulement cités, ce que la story interdit.
- **B14 — bouton désactivé sans raison quand `results` ou `_timelineKey` manque** (blind) — **faux**. En production, `AppRoutes` injecte toujours `results` et une carte n'est rendue qu'avec une projection chargée, donc `_timelineKey` est renseigné ; le cas nul n'existe que dans les tests.
- **B15 — `Content.resultSize` affiche « 1024.0 Ko » sous 1 Mio** (blind) — **corrigé**. Le seuil bascule en Mo quand l'arrondi vaut `1024.0` (`content.dart:296-304`), avec un test de borne dans `result_card_test.dart`.

- **E1 — carte résultat du tour 0 détachée** (edge) — **corrigé**. Même défaut que B5 ; `ResultItem.atTurn` et `_startTurn` le corrigent, test à l'appui.
- **E2 — échec de `ResultFiles.file` ou changement de connexion pendant le téléchargement** (edge) — **faux**. L'échec reste un échec réessayable avec le message générique de B3, jamais une réussite ; revenir à « Disponible » masquerait l'échec d'écriture. Le contexte de fil est déjà protégé par `_setResultState`/`_enqueue`.
- **E3 — taille conservée après suppression locale** (edge) — **faux**. Même raisonnement que B4 : la taille est une métadonnée distante, effacée sur échec.
- **E4 — chemin absolu finissant par un séparateur ou `/..`** (edge) — **faux**. Un `tool.complete` de `write_file` ne peut pas réussir sur un dossier ; `ResultPaths.name` ignore déjà les segments vides, `.` et `..`, et un lecteur seul ne rend aucun nom (`result.dart:43-55`).
- **E5 — écriture locale impossible (disque plein, permission)** (edge) — **corrigé**. `IoHermesTransport.download` traduit `FileSystemException` en `result.write` et supprime le `.part` (`hermes_adapter.dart:187-189`) ; la carte affiche « Impossible d'enregistrer le fichier sur le téléphone. ».
- **E6 — un `write_file` en erreur avec chemin absolu crée une carte fantôme** (edge) — **faux**. La spec dit explicitement tout `tool.complete` de `write_file` (ligne 26) ; si le fichier n'existe pas, le téléchargement échoue proprement en `result.missing`. Filtrer sur le résultat aurait été une décision de spec non prise.
- **E7 — carte retirée par un resync pendant le téléchargement, copie orpheline** (edge) — **faible, rejeté**. Même limite que B11 : le remplacement par snapshot est assumé et le nettoyage demanderait un cycle de vie hors intention.
- **E8 — `_fromHistory` perd les cartes après resync** (edge) — **faux**. C'est la conséquence explicitement acceptée par « pas de reconstruction des résultats depuis `session.history` » (spec, ligne 42) ; aucun résultat n'est inventé depuis le texte.

- **G1 — aucun test du chemin carte → view model → gateway** (vérification) — **moyen, corrigé**. `test/result_widget_test.dart` monte `DraftView` avec une conversation implémentant aussi `ResultGateway`, vérifie la carte, la mention d'activité et le `resultKey` transmis à « Télécharger ».
- **G2 — aucun test d'hydratation pendant un téléchargement en vol** (vérification) — **moyen, corrigé**. `result_flow_test.dart` ouvre `downloadGate`, lance `downloadResult`, recharge le fil et vérifie que la carte reste « Téléchargement… », que le `.part` survit et qu'un second appui ne lance qu'un seul téléchargement.
- **G3 — le test d'ouverture couvre `SystemResultOpener`, pas l'implémentation de production** (vérification) — **moyen, corrigé**. `DeviceResultOpener` reçoit une fonction d'ouverture injectable, `SystemResultOpener` a été supprimé et `test/result_opener_test.dart` couvre succès, fichier introuvable, permission refusée, absence d'application et exception.
- **G4 — la bannière d'erreur `result.*` sans « brouillon conservé » n'est pas vérifiée** (vérification) — **moyen, corrigé**. Un test de `result_widget_test.dart` provoque `result.open` via le gateway et vérifie que la bannière affiche l'erreur de résultat sans `Content.draftKept`.
- **G5 — `result_download` reste `unverified`** (vérification, autre) — **faux**. Même constat que B1 : choix documentaire cohérent avec les autres capacités, sans consommateur qui exige `present`.
- **G6 — `test/result_view_model_test.dart` non suivi risque d'être oublié au commit** (vérification, autre) — **faible, sans objet pour l'instant**. Le fichier est présent dans l'arbre et inclus dans le diff de revue ; aucun commit n'a été créé à la demande d'Alanc. S'il est demandé, le commit devra inclure les trois nouveaux tests non suivis.

## Design Notes

L'état du résultat vit dans la projection, comme celui des pièces jointes, plutôt que dans une nouvelle table : la carte est ainsi relue avec le fil et le rejeu la conserve. `session.history` ne décode aucun outil : un snapshot qui remplace la projection perd les cartes, comme les activités aujourd'hui ; aucun résultat n'est inventé depuis le texte. La clé locale est un hachage, jamais le chemin serveur, pour éviter toute traversée et tout nom choisi par le serveur. Le type et la taille peuvent rester inconnus avant le premier téléchargement : la carte ne les invente pas.

## Verification

**Commands:**
- `fvm flutter analyze` -- expected: aucun problème.
- `fvm flutter test` -- expected: tous les tests passent.

**Manual checks (if no CLI):**
- Galerie ou app réelle : carte disponible, en téléchargement, téléchargée, en échec, interrompue, en clair/sombre et texte agrandi ; ouverture d'un PDF et d'une image ; tentative d'ouverture d'un type sans application.
