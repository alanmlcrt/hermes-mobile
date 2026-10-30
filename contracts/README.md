# Contrat documentaire Hermes

Référence officielle : **v0.22.2+1690 (main 9e01b44)**, commit `9e01b44dd23978f9ff40b7837467f3a9f1582130` de NousResearch/hermes-agent, soit le build observé via `/api/health` (`displayVersion 0.22.2+1690`) ; ce build n’est pas validé (`installedBuild = observed-health`). Le tag `v0.22.2` (`d923a5eb487a17c0a68801bba9ef0f56c81040a8`) n’est plus que la base, conservée dans `release.json` (`baseTagCommit`). `openrpc.json` est un extrait du fichier généré officiel : treize méthodes (connexion, création et suite de conversation : `session.list/history/resume/status`, `prompt.submit`, `session.interrupt/title`), dix notifications (`gateway.ready`, `message.*`, `error`, `session.info`, `status.update`, `sessions.changed`, `session.title`) et les schémas atteints par leurs références. `tool/extract_openrpc.py` le reconstruit depuis le fichier officiel complet. `x-provenance` conserve release, SHA, source et nature documentaire de l’extrait ; `methods.json` décrit la surface appelée, avec les liens épinglés.

Les fixtures sont **synthétiques**, avec des marqueurs de secrets fictifs. Le backend personnel n’a pas été contacté. Aucune équivalence avec le build de l’add-on n’est établie ; la capture 1.3/G1 et les vérifications sur téléphone restent ouvertes.

### Activités compactes (3.1)

Les [schémas officiels épinglés](https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/contracts/events.py#L354-L387) définissent `tool.start` (`tool_id`, `name`, puis `context`, `args`, `args_text`, `preview`, `labels` optionnels) et `tool.complete` (même identité ; `args`, `duration_s`, `result`, `summary`, `result_text`, `inline_diff`, `todos`, `revision`, `labels` optionnels). L’[émetteur](https://github.com/NousResearch/hermes-agent/blob/9e01b44dd23978f9ff40b7837467f3a9f1582130/tui_gateway/tool_progress.py#L276-L362) reprend `tool_call_id` dans `tool_id` ; ses chemins et réglages conditionnent l’émission. Ces notifications ne font pas partie de l’extrait OpenRPC sélectionné localement.

`fixtures/tool-start.json` et `tool-complete.json` sont des exemples synthétiques, jamais des captures de l’installation. Les champs documentés et leur disponibilité effective restent distincts (`capabilities.json.activityEvents.actual = unverified`). Seuls le mapping `tool`/`unknown`, l’ID opaque et les preuves de début/fin reçues servent à la projection ; ni le nom ni un emoji ne déterminent une famille précise. La fin d’action ne prouve aucune réussite ni fin du travail. Sans ID, chaque événement reste une entrée générique séparée.

La projection persistée conserve ces preuves sans migration destructive. Les anciennes projections deviennent génériques sans fin supposée. `session.history` ne décode actuellement que le texte : une reprise par snapshot sans outils ne reconstitue aucune activité ; le rejeu peut seulement conserver les événements effectivement disponibles.

`capabilities.json` sépare présence documentaire et état réel non vérifié. Seules les réponses effectives (GET profils, `gateway.ready`, `gateway.capabilities`) changent les états en mémoire. Les capacités futures mutantes restent non vérifiées ; aucun envoi ni création de conversation n’est utilisé comme sonde. `event-mapping.json` décrit les événements utilisés ici, avec un type inconnu explicite ; les états de travail hors périmètre restent nuls.

Login JSON, cookies de session explicitement extraits, REST bearer, refresh puis relogin via coffre. Le ticket WS est un sous-protocole, sans secret dans l’URL ; les redirections sont refusées. Aucun POST de sélection globale.

Après activation autorisée : comparer build et contrat, capturer les réponses expurgées, vérifier auth, profils, ticket, reprise, deux profils, texte 200 % et TalkBack. La présence documentaire ne vaut jamais validation réelle.

## Détails d’action (story 3.2)

`tool.start` et `tool.complete` peuvent fournir `name`, `context`, `args`,
`args_text`, `preview`, `result`, `result_text`, `inline_diff`. Seuls ces champs
sont conservés ; les textes sont des chaînes et args/result sont des valeurs JSON.
Une fin enrichit la même identité selon les règles 3.1 : omission conserve,
null explicite supprime. Les données structurées priment sur les textes de secours.
Seule une chaîne non vide dans `result.error` produit une section Erreur ; ni code
de sortie, ni nom MCP, ni texte libre ne modifie le statut global.
Les données restent du texte sélectionnable, jamais exécuté. Aucun RPC au dépliage.
Les textes peuvent être expurgés ou tronqués par le serveur : leurs marqueurs sont
conservés et l’interface ne promet pas une sortie complète. Un snapshot textuel ne
reconstitue aucun détail. Toutes les fixtures outil sont synthétiques ; la
disponibilité sur une installation réelle reste **unverified**.
# Arrêt du travail (story 3.5)

`session.interrupt` est documenté dans le contrat OpenRPC versionné : runtime
`session_id`, `profile`, et `expected_hosted_task_id` optionnel. Le mobile ne
reçoit pas d'identité de tâche hébergée fiable ; il omet ce dernier champ et
revérifie son repère local de tour avant transmission. Cela ne garantit pas
l'isolation entre clients distants.

La réponse `interrupted` / `not_interrupted` est un résultat RPC, jamais un
terminal. Seul `message.complete.status=interrupted` confirme l'arrêt dans la
projection. Refus, méthode absente, réponse invalide et résultat incertain sont
affichés ; aucun protocole alternatif ni renvoi automatique n'est utilisé.
Ces preuves documentaires et les tests synthétiques ne valident pas
l'installation personnelle de Hermes.

# Limites de fichiers (story 4.1)

`file-limits.json` est le seul endroit où les limites de fichiers sont
consignées. Il porte soit `evidence: install-measured` avec un build et une date
observés, soit `evidence: unmeasured` avec chaque limite `null` et
`maxBytesVerified` / `maxCountVerified` à `false`. Seule une sortie de
`tool/mesure_pieces_jointes.dart` le passe à `install-measured`. Les autres
contrats de ce dossier restent `documentary` ; les deux provenances ne se
mélangent pas.

## Protocole

La sonde réutilise `IoHermesTransport` et `HermesRpc` sans modifier `lib/`.
L'origine et les identifiants viennent uniquement de `HERMES_URL`,
`HERMES_PASSWORD` ou `HERMES_TOKEN`. Le profil cible est passé par
`--profil-de-test` et doit exister sans être le profil par défaut ; la sonde
refuse ce profil par défaut. Chaque pièce du corpus est passée par
`--piece categorie=chemin` (catégories `text`, `image`, `pdf`, `office`).
`--aide` affiche l'usage sans accès réseau. La sortie JSON reprend la forme de
`file-limits.json` et ne contient ni chemin local, ni identifiant, ni nom de
fichier, ni contenu. `install.profile` et `vision.profile` ne portent que le
marqueur de rôle `dedicated-test-profile`, jamais la clé réelle du profil.

La sonde passe par `IoHermesTransport` : chaque étape réseau (connexion,
en-têtes, corps) dispose de 15 s. Les pièces jusqu'à 20 Mo ont passé ce budget ;
il n'est pas une limite de fichier et n'est pas consigné dans le contrat. Pour
`file.attach`, seule la variante `data_url` est exercée (base64, corps environ
33 % plus gros que le fichier) ; elle est consignée dans
`transports.file.attach.parameters`. Le champ `uploaded` de la réponse n'est
pas retenu comme preuve : seule la ligne d'attachement relue dans la session
compte.

Les sessions et les copies créées restent sur le profil de test, dont le
propriétaire est Alanc ; la sonde ne supprime rien. Les campagnes successives
s'accumulent dans `attachments/` et `images/` et se nettoient depuis l'interface
Hermes du profil, jamais par la sonde.

### Rejouer la campagne

Depuis la racine du dépôt, avec `HERMES_URL` et `HERMES_PASSWORD` dans
l'environnement :

```powershell
$corpus = '_bmad-output/implementation-artifacts/corpus-pieces-jointes'
dart run tool/mesure_pieces_jointes.dart `
  --profil-de-test mesure-pieces-jointes `
  --piece "text=$corpus\texte-1Mo.txt" `
  --piece "text=$corpus\texte-5Mo.txt" `
  --piece "text=$corpus\texte-10Mo.txt" `
  --piece "image=$corpus\image-1Mo.png" `
  --piece "image=$corpus\image-5Mo.png" `
  --piece "image=$corpus\image-10Mo.png" `
  --piece "image=$corpus\image-20Mo.png" `
  --piece "image=$corpus\image-marqueur.png" `
  --piece "pdf=$corpus\pdf-1Mo.pdf" `
  --piece "pdf=$corpus\pdf-5Mo.pdf" `
  --piece "pdf=$corpus\pdf-10Mo.pdf" `
  --piece "pdf=$corpus\pdf-30pages.pdf" `
  --piece "office=$corpus\bureautique-1Mo.docx" `
  --piece "office=$corpus\bureautique-5Mo.docx" `
  --piece "office=$corpus\bureautique-10Mo.docx" `
  --surface file.attach `
  --surface rest.image-upload `
  --surface image.attach_bytes `
  --repetitions 3 `
  --vision-marqueur BANANE `
  --sortie _bmad-output/implementation-artifacts/mesure-finale.json
```

La sortie ne remplace `contracts/file-limits.json` qu'après relecture des
`proof` et des `unverified`.

## Transports et écarts documentaires

`file.attach` est la seule surface de l'extrait épinglé ; elle est déclarée
`pinned` et ne traite pas les images. Deux surfaces image du build sont
éprouvées séparément et marquées `outside-pinned` : la route
`POST /api/chat/image-upload` de la source du build, suivie de `image.attach`,
et `image.attach_bytes` du contrat amont complet, absente de l'extrait épinglé.
Leur présence installée n'est prouvée que par la sonde ; leur adoption par
l'app exige l'arbitrage d'Alanc avant 4.2. Aucun proxy n'est placé dans la
chaîne. Une source documentaire peut annoncer un plafond (la route image du
build porte un plafond de 25 Mo dans son code) : ce n'est pas une mesure et
cela ne remplit aucune limite.

## Preuves et limites

Une pièce n'est acceptée qu'après une référence serveur et une relecture de
`session.history` dans la session visée ; un aperçu client ne prouve rien. Un
upload ou un attachement réussi ne prouve jamais une analyse par le modèle :
`vision.analyzesImages` n'est `true` que si `--vision-marqueur` apparaît dans
la réponse du modèle, `false` sur un refus explicite de voir l'image, sinon
`null`.

`maxBytes` est la plus grande taille acceptée sous le plus petit refus observé
au premier essai ; `maxCount` n'est renseigné que si un refus après répétitions
prouve la dimension du nombre. Aucune interpolation : `threshold` vaut
`lower-bound`, `between` ou `not-measured`. Une méthode absente donne `absent`,
un délai ou une réponse invalide donne `unverified` ; aucune valeur ne se déduit
du silence. Le délai réseau de 15 s du transport peut produire `unverified`
sur une grosse pièce sans conclure à un refus.

Après une mesure, `transports.file.attach.status` est la seule source permise
pour `capabilities.file.attach.actual`. Si une mesure a pu être consignée sans
transport exploitable, la sonde écrit le contrat, signale le blocage et sort en
code 2 ; si l'ouverture de la session échoue, elle signale le blocage sans
écrire de contrat. Dans les deux cas, 4.2 à 4.4 restent bloquées.

## Résultat de la mesure (2026-10-24)

Campagne exécutée de 15:15 à 15:27 UTC sur le build `0.22.2+1690` avec un
profil de test non-défaut. Chaque pièce a été attachée trois fois dans une
session neuve ; une pièce n'est comptée acceptée qu'après référence serveur et
relecture de `session.history`.

| Catégorie | Pièces | Plus grande taille acceptée | Nombre |
|---|---|---|---|
| text | 3 (1, 5, 10 Mo) | 10 485 812 octets | au moins 3 |
| image | 5 (1, 5, 10, 20 Mo, marqueur) | 20 965 448 octets | au moins 3 |
| pdf | 4 (1, 5, 10 Mo, 30 pages) | 10 485 858 octets | au moins 3 |
| office | 3 (1, 5, 10 Mo ; .docx) | 10 485 797 octets | au moins 3 |

Les trois transports sont `present`. `file.attach` a traité 10 pièces et
30 essais : 9 pièces acceptées (27 copies relues), 1 `unverified`, aucun refus.
`rest.image-upload` et `image.attach_bytes` ont accepté leurs 5 pièces et
15 essais chacune. La pièce `unverified` est le texte de 1 Mo, première de la
campagne : ses trois copies ont été acceptées, mais la session est restée
orpheline (`end_reason: ws_orphan_reap`), sans réponse ni bloc serveur. Elle
n'entre dans aucune limite et n'invalide pas les 10 Mo acceptés.

Aucun refus n'a été observé. Les `maxBytes` sont donc des bornes inférieures
(`threshold.bytes: lower-bound`), pas des plafonds : promettre ces tailles est
sûr, refuser au-delà ne serait pas justifié par la mesure. Le plafond
documentaire de 25 Mo de la route image n'a pas été atteint ; il reste une
source de code, pas une mesure.

Les textes de 5 et 10 Mo sont acceptés mais pas inlinés : le bloc serveur les
déclare « too large to inline safely » et les référence sur disque. La réception
est prouvée ; 4.2 devra prévoir une lecture par outil pour ces pièces, pas un
contenu déjà présent dans le contexte.

Le nombre n'a pas de plafond observé : `maxCount` reste `null` avec
`maxCountVerified: false` et `threshold.count: lower-bound` (trois pièces
acceptées par session). `unverified` liste ces quatre bornes.

Le modèle du profil de test, `gpt-6-luna-900k`, analyse les images :
`analyzesImages: true`, preuve `marker` (le mot attendu est apparu dans sa
réponse à `image-marqueur.png`). Cette preuve porte sur ce modèle, pas sur un
autre profil.

Le corpus mesuré est synthétique et calibré ; aucune photo ni aucun PDF réel
n'a été déposé. Les types MIME réels d'un appareil (JPEG/HEIC, EXIF) restent
donc non couverts par cette campagne.

## Corpus

Le corpus vit dans `_bmad-output/implementation-artifacts/corpus-pieces-jointes/`
(15 fichiers de mesure, 84 Mio, plus un README), ignoré par Git. Il a été
généré pour calibrer les paliers de taille, avec une image portant le mot
`BANANE` pour la preuve de vision. Le contrat ne consigne que sa nature et son
volume (`pieces`, `totalBytes`, `mediaTypes`), jamais son contenu, ses noms ou
ses chemins.

## Vérification

`flutter test test/contracts_test.dart` vérifie qu'aucune limite non vérifiée
ne porte de valeur et qu'aucune donnée personnelle n'apparaît.
`dart run tool/mesure_pieces_jointes.dart --aide` doit afficher l'usage sans
accès réseau.

## Payload des notifications (plugin)

`notification-tracking.json` décrit le seul payload FCM envoyé par le plugin
Hermes `server/hermes-plugin/hermes-mobile-notify/` : titre, libellés génériques
par issue, canal Android, TTL, tag et collapse key. Le bloc `data` est
strictement `{outcome, sessionId}` en chaînes ; aucun texte, chemin ni secret.
Les issues (`succeeded`, `failed`, `stopped`) sont les terminaux notifiables
de `event-mapping.json`.

`flutter test test/notification_contract_test.dart` vérifie l'accord entre ce
contrat, les constantes du plugin et l'app Android (`MainActivity.kt`,
`AndroidManifest.xml`) : toute divergence de libellé, de canal ou de champ
`data` le fait échouer.

## Interventions et résultats (story 6.1, porte G4)

Mesuré le 2026-10-30 sur l'installation réelle, profil de test
`mesure-pieces-jointes`, avec `tool/sonde_interventions.dart` (journal brut
hors dépôt). Source lue : commit épinglé, `tui_gateway/server_requests.py` et
`tui_gateway/contracts/server_requests.py`.

**Prérequis.** Questions et autorisations sont des requêtes JSON-RPC
serveur → client (`id` = `srq-<12 hex>`, champ `method`, sans `result`). Hermes
ne les envoie qu'au client qui a dit une fois par connexion
`client.capabilities {server_requests: true}` (`fixtures/client-capabilities.json`).
Sans cela, la requête n'est jamais écrite et l'agent attend jusqu'à son délai
(300 s pour clarify). L'app actuelle ne l'envoie pas.

**Question (`clarify`).** Params : `session_id`, `questions[]` (`qid`,
`question`, `choices?`, `multi_select`). Réponse : trame `{id, result:
{answers: {qid: texte}, outcome: "submitted"}}` ; sans `answers` = annulation.
Prise en compte immédiate : `tool.complete` du clarify suit dans la seconde.
Le serveur peut suffixer un choix par « (Recommended) » : l'afficher tel quel.
Fixtures `clarify-request.json`, `clarify-answer.json`.

**Réponse aux questions (story 6.2).** L'app déclare
`client.capabilities {server_requests: true}` une fois par socket, juste après
`gateway.capabilities`. Une requête `clarify` devient l'événement synthétique
`server.clarify` (payload `{id, questions}`), routé comme les autres événements
de session ; `open_requests` de `session.resume` / `session.events.since`
(entrées `{id, method, params}`) produit les mêmes événements. Toute autre
requête serveur reçoit aussitôt une erreur JSON-RPC `-32601` (méthode non prise
en charge) jusqu'à la 6.3. `request.cancel {id, method, reason}` ferme la carte
(fixture synthétique `request-cancel.json`, format lu dans
`tui_gateway/server_requests.py` épinglé) : `reason` `timeout` ou `expired`
= question expirée, sinon annulée. `event-mapping.json` porte ces deux types
avec l'effet `intervention`. La réponse est enregistrée
(`intervention_answers`, clé = id `srq-…`) avant la trame ; une issue incertaine
reste « inconnue » et n'est jamais renvoyée automatiquement.

**Autorisation (`approval`).** Params : `request_id`, `command` (expurgée par le
serveur), `description`, `pattern_key(s)`, `choices` (`once`, `session`,
`always`, `deny`), `allow_session`, `allow_permanent`. Réponse `{choice}`.
Un refus produit `tool.complete` avec `result.status = "blocked"` et
`user_summary` ; la commande ne s'exécute pas. Fixtures `approval-*.json`.
Les profils de l'installation sont en `approvals.mode = smart` : les commandes
signalées sont le plus souvent approuvées sans demande (constaté :
« auto-approved by smart approval »). Une demande n'arrive au téléphone qu'en
mode `manual` ou quand le juge smart hésite. Les commandes de la liste
absolue (`BLOCKED (hardline)`) ne sont jamais proposées.

**Décision d'autorisation (story 6.3).** Une requête `approval` devient
l'événement synthétique `server.approval` (payload `{id, description, command,
choices, allow_session, allow_permanent}`), effet `intervention`, état de
travail `waitingApproval` ; `open_requests` produit le même événement
(`pending_approval` de `session.resume` n'est pas lu : il n'a pas l'id
`srq-…`). L'app ne propose et n'envoie que `{choice: "once"}` (« Autoriser »)
ou `{choice: "deny"}` (« Refuser »), jamais `session` ni `always`. La décision
est enregistrée dans `intervention_answers.answers` sous la forme
`{"choice": …}` avant la trame (fixture `approval-answer.json`) ; issue
incertaine = « inconnue », sans renvoi. Aucun événement « autorisation
résolue » n'existe : le `tool.complete` suivant (outil autre que `clarify`)
confirme la dernière décision envoyée, refusée si `result.status = "blocked"`
(fixture `approval-denied.json`), autorisée sinon. `request.cancel` ferme la
carte comme pour une question. Les autres requêtes serveur (`sudo`,
`secret`…) reçoivent toujours `-32601`. Le mode du profil se lit par
`config.get {key: "approvals.mode", profile}` (`{value}`) et s'écrit par
`config.set {key, value, profile}` suivi d'une relecture : la valeur affichée
est toujours celle relue ; passer en `off` demande une confirmation.

**Reconnexion.** Documentaire, non mesuré : les requêtes sans réponse reviennent
dans `open_requests` de `session.resume` / `session.events.since` ; une
requête expirée ou annulée émet `request.cancel {id, method, reason}` ; une
réponse à un id fermé est ignorée. `approval.pending` relit les autorisations
en attente.

**Message pendant le travail.** Un `prompt.submit` pendant un tour répond
`redirected` : le message est injecté dans le tour en cours, pris en compte
immédiatement (fixture `prompt-submit-redirected.json`).

**Fichiers résultats.** Sur ce canal, Hermes n'attache pas de fichier : il
l'écrit côté serveur (`write_file`, `args.path` absolu) et cite le chemin dans
sa réponse (fixture `result-file-written.json`). `GET /api/fs/download?path=`
(bearer, `profile` et `session_id` facultatifs) renvoie le fichier en
`attachment` avec nom et type ; chemin absent = 404. Aucun événement dédié
« résultat disponible » n'existe : l'identification d'un résultat est une
décision de l'app. La copie locale va dans
`results/<connexion>/<profil>/<session>/<clé hachée>`, séparé des pièces
jointes, et jamais sous le nom servi. Un 404, un 403, une authentification
expirée ou un 5xx reste un échec réessayable, jamais un fichier récupéré.

**Décisions d'Alanc (G4, 2026-10-30).** FR13 et FR14 sont retenus.
Le mode d'autorisation reste celui de chaque profil, réglé côté Hermes ;
l'app l'affiche et permet de le changer profil par profil (`config.get` /
`config.set approvals.mode` avec `profile`, mesuré sans effet sur le profil
par défaut), critère ajouté à la story 6.3.
Un fichier résultat est un fichier écrit par Hermes pendant le tour
(`tool.complete` de `write_file`, `args.path` absolu), téléchargé par
`/api/fs/download`. Les chemins seulement cités dans le texte de la réponse
ne sont pas repérés comme résultats.
Palette de secours (UX-DR3) validée par Alanc le 2026-10-30 en clair et en
sombre : texte et erreur ≥ 5,3:1 ; contours 1,5 à 1,8:1, acceptés car
décoratifs (les éléments se distinguent par leur fond). Porte G4 fermée.
