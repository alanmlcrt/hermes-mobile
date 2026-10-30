---
title: 'Story 5.1 - Fixer le contrat de suivi et le déploiement de l''observateur'
type: 'feature'
created: '2026-10-26'
status: 'in-review'
baseline_commit: '7d223a1c55fd1e2e87c3b8ed61ada436c28977bd'
review_base_commit: '4ba2a0ab2e37bd6215147ff6745f4b67ab7b7284'
route: 'dispatch'
review_loop_iteration: 1
context:
  - '{project-root}/contracts/README.md'
  - '{project-root}/contracts/openrpc.json'
  - '{project-root}/contracts/event-mapping.json'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Registre de suivis, payload push minimal, point de santé, runtime de l'observateur, auth mobile → observateur, version FCM et prérequis Android ne sont pas fixés ; 5.2 à 5.5 construiraient sur des hypothèses.

**Approche :** Écrire le contrat de suivi dans `contracts/` en référençant le mapping et ses fixtures, consigner les décisions G3 validées par Alanc et constater les prérequis Android sur le Pixel. Aucun code runtime mobile ou observateur.

## Décisions G3 validées par Alanc (2026-10-26)

- **Runtime :** add-on Home Assistant dédié, supervisé par HA, volume persistant `/data`, accessible sur le tailnet.
- **Auth mobile → observateur :** jeton bearer opaque par environnement, haché côté observateur, stocké dans `flutter_secure_storage`.
- **Firebase :** un seul projet pour l'usage personnel ; l'intégration utilise un transport dry-run sans FCM. Un compte de service unique, hors dépôt. Alanc crée le projet et dépose le compte.

## Boundaries & Constraints

**Toujours :** Mapping partagé = seule source des terminaux (`message.complete` complete/error/interrupted, `error`). Payload = `subscriptionId` + issue + libellé générique. Santé authentifiée. Décisions datées, validées par Alanc, isolées par environnement. Provenance explicite.

**Jamais :** Observateur (5.2), FCM mobile (5.3/5.4), déclarer G3 franchie (5.5). Secrets ou chemins personnels dans le dépôt. Modifier `openrpc.json` ou `event-mapping.json` sans preuve. Captures réelles ou profil personnel. Promesse « exactement une fois ».

## I/O & Edge-Case Matrix

| Scénario | Entrée / état | Résultat | Erreur |
|----------|--------------|----------|--------|
| Contrat valide | JSON, fixtures, tests | Trois terminaux résolus, payload minimal | Test rouge bloque |
| Décision G3 manquante | Runtime, auth ou FCM non tranché | Story bloquée | Écart consigné |
| Firebase absent | Projet ou compte non créés | G3 non franchie | Aucune valeur fictive |

</frozen-after-approval>

## Code Map

- `contracts/notification-tracking.json` — contrat machine : registre, token FCM, corrélation session/exécution, endpoints, payload, déduplication, rattrapage, rétention, erreurs, journaux, santé, référence au mapping.
- `contracts/notification-deployment.json` — décisions G3 : runtime, volume, auth, accès Hermes, FCM, exposition tailnet, environnements, validation.
- `contracts/README.md` — section 5.1 : rationale, payload, santé, provenance, sans recopier les valeurs du JSON.
- `contracts/openrpc.json` — référence seule : schémas `session_id`, `user_row_id`, `persisted_turn`, `error` ; ne pas modifier.
- `contracts/event-mapping.json` — référence seule ; ne pas modifier.
- `_bmad-output/implementation-artifacts/epic-5-context.md` — exigences d'epic : rattrapage, rotation du token, journaux sans contenu.
- `contracts/fixtures/message-complete.json`, `error.json` — réutiliser ; ne pas modifier.
- `contracts/fixtures/message-complete-interrupted.json` — fixture synthétique `interrupted`.
- `test/event_mapping_test.dart` — compte attendu 10 → 11.
- `test/notification_contract_test.dart` — invariants des contrats et des trois terminaux.
- `_bmad-output/implementation-artifacts/story-5-1-verification/g3-decisions.md` — décisions, validation, Firebase, écarts.
- `_bmad-output/implementation-artifacts/story-5-1-verification/android-prerequisites.md` — constats ADB (Pixel 8 Pro, Android 17, GMS 26.41.31, app 0.1.0, `POST_NOTIFICATION: ignore`, aucune exemption batterie).
- `_bmad-output/implementation-artifacts/story-5-1-verification/implementation-report.md` — changements, décisions, résultats de vérification et apports d'epic 4.

## Tasks & Acceptance

**Execution:**
- [x] `contracts/notification-tracking.json` — schéma v1, provenance documentary/synthetic, terminaux par référence, `subscriptionId` et token FCM créés avant soumission, `attach` portant session/profil/exécution, déduplication `(subscriptionId, executionId, terminal)` avec premier terminal gagnant, message FCM `notification + data` avec data strict `{subscriptionId, outcome}`, endpoints register/attach/revoke/health avec statuts cohérents, auth bearer, erreurs bornées, journaux rédigés, rattrapage `last_seen`, rétention, santé à seuils, retries bornés.
- [x] `contracts/notification-deployment.json` — add-on HA dédié supervisé avec volume `/data`, origine HTTPS tailnet sans port hôte publié, ports et terminaison TLS marqués proposés, bearer opaque par environnement haché côté observateur, lecture seule via le contrat, FCM 17.x proposé (repli 16.x documenté), token et rotation référencés, un projet Firebase personnel et un compte de service hors dépôt, intégration en dry-run sans FCM, validation par décision (`validatedBy: Alanc` sur les points acceptés), `pending`/`blockers` datés et reportés à 5.5.
- [ ] Création Firebase par Alanc — **reportée à 5.5 par décision d'Alanc du 2026-10-26**. Créer le projet unique et le compte de service hors dépôt, consigner les identifiants non secrets et passer `status` à `created`. G3 reste ouverte jusqu'à l'essai réel de 5.5.
- [x] `contracts/README.md` — décrire la section 5.1 sans dupliquer le JSON.
- [x] `contracts/fixtures/message-complete-interrupted.json` + `test/event_mapping_test.dart` — fixture synthétique et compte 11.
- [x] `test/notification_contract_test.dart` — terminaux, payload strict, token et rotation, corrélation session/exécution, conflits, rattrapage, rétention, erreurs/journaux, endpoints exacts, santé authentifiée, environnements distincts, absence de secret ou de chemin personnel, comparaison des copies machine.
- [x] `_bmad-output/implementation-artifacts/story-5-1-verification/g3-decisions.md` — décisions, validateur, date, preuves Firebase, écarts.
- [x] `_bmad-output/implementation-artifacts/story-5-1-verification/android-prerequisites.md` — ADB sur `39161FDJG0026X`, chaque cas avec comportement attendu.
- [x] `flutter analyze` et tests ciblés.

**Acceptance Criteria:**
- Given le contrat et les fixtures, when `flutter test test/notification_contract_test.dart test/event_mapping_test.dart` s'exécute, then les trois terminaux sont résolus et aucun champ interdit n'apparaît.
- Given `notification-deployment.json`, when Alanc le relit, then chaque point G3 porte une valeur, un propriétaire et une date, sans TBD.
- Given le rapport Android, when il est lu, then chaque cas porte un constat daté et un comportement attendu.
- Given le contrat de suivi, when 5.2 l'implémente, then chaque abonnement porte un token FCM, chaque attache porte session, profil et exécution ; un terminal de tour est rapproché par `session_id` + `persisted_turn.user_row_id`, et un `error` de session ne notifie que l'unique exécution attachée non notifiée.
- Given un redémarrage de l'observateur, when il reprend, then il repart de `last_seen` et refait l'historique si `truncated` ou si l'`epoch` change.
- Given une entrée notifiée, expirée, révoquée ou abandonnée, when la purge s'exécute, then aucune entrée ne reste indéfiniment dans `/data` et les compteurs `dropped`/`expired`/`revoked` sont exposés.
- Given un port hôte, when l'add-on démarre, then aucun port n'est publié hors tailnet et l'accès passe par Tailscale Serve.
- Given Firebase, when la création sera consignée en 5.5, then un projet unique et un compte de service hors dépôt seront consignés, l'intégration restera en dry-run et aucun secret ne sera versionné.
- Given le dépôt, when `flutter analyze` et `flutter test` s'exécutent, then tout passe.

## Contrat de suivi — exigences amendées (revue du 2026-10-26)

La revue a montré que le contrat ne permettait pas à 5.2 de localiser la session
et l'exécution, ni de survivre à un redémarrage. Les exigences suivantes
complètent les sections non gelées ; elles ne changent ni l'intent, ni les
décisions G3, ni la porte ouverte.

**Token FCM.** `register` porte `subscriptionId` et `fcmToken`. Le token est
stocké chiffré côté observateur, jamais dans le push ni les journaux. La
rotation se fait par ré-enregistrement du même `subscriptionId` ; un token
invalide (`UNREGISTERED`) supprime l'abonnement sans réessai. Seul
l'environnement personnel exige un token réel ; en dry-run, la valeur est un
marqueur synthétique.

**Corrélation.** `attach` porte `sessionId`, `profile` (nullable) et
`executionId`. `executionId` est composé au moment de l'attache à partir de
`prompt.submit.params.session_id` et de
`prompt.submit.result.user_row_id` ; il est scopé par session. Le terminal est
rapproché par `event.params.session_id` et
`message.complete.payload.persisted_turn.user_row_id` ;
`persisted_turn.submission_id` est une corrélation plus forte optionnelle, jamais
un substitut au `user_row_id`. Sans session ou sans `user_row_id`, aucun
rattachement et aucune notification.

**Erreur de session.** `error` reste terminal `failed`, mais ne notifie que
l'unique exécution attachée et non notifiée de la session ; sans cette
unicité, il est ignoré. Un `message.complete/error` sans `user_row_id` est
ignoré.

**Conflits.** Pour une même exécution, le premier terminal notifié gagne ; tout
terminal tardif est ignoré. La déduplication reste
`(subscriptionId, executionId, terminal)` ; les doublons fournisseur sont
dédupliqués à l'affichage par un tag stable.

**Rattrapage.** L'observateur stocke un curseur `{connection, profile,
sessionId, last_seen}` dans `/data`, reprend par `session.events.since` après
redémarrage, et refait `session.history` si `truncated` ou si l'`epoch` change.
Au-delà de `maxReplayEvents`, il reprend depuis le dernier événement traité.

**Rétention.** Les abonnements non attachés expirent selon `ttlSeconds` ; les
attachés selon `attachedTtlSeconds` ; les notifiés sont purgés après
`notifiedTtlSeconds` ; la déduplication après `deduplicationTtlSeconds` ;
l'outbox après `dropAfterSeconds`, avec compteur `dropped`. Le contrat nomme ce
mapping `expiryByState` et supprime les révoqués à la révocation. Aucune entrée
ne reste indéfiniment dans `/data`.

**Erreurs et journaux.** Les erreurs HTTP ont une forme bornée `{code,
message}`, sans identifiant de suivi ni contenu. Les journaux rédigent
`Authorization`, `fcmToken`, `subscriptionId`, `executionId`, `sessionId` et
`profile`, et ne journalisent jamais le payload ni le contenu Hermes.

**Santé.** `degradedWhen` porte une sonde et un seuil pour chaque raison ;
`counters` inclut `dropped`, `expired`, `revoked` et `invalidToken` ;
`fcm-unavailable` est ignoré en dry-run.

**Endpoints.** Chemins exacts : `POST /v1/subscriptions`,
`POST /v1/subscriptions/{subscriptionId}/attach`,
`DELETE /v1/subscriptions/{subscriptionId}`, `GET /v1/health`. Les corps sont
figés. `register` et `attach` sont idempotents et ne renvoient pas 409 : un
doublon met à jour le token ou renvoie 200. `revoke` traite 404 comme un
succès. `attach` peut renvoyer 202 quand la session n'est pas encore vive ;
l'observateur la surveille ensuite, sans action mobile. Les statuts 500/502/504
sont déclarés partout où `retryOn` les autorise ; 410 signale un abonnement
expiré ou révoqué.

**Exposition.** Le conteneur écoute sur `0.0.0.0` dans son espace de noms, mais
aucun port hôte n'est publié (`hostPortPublished: false`) ; l'accès passe par
Tailscale Serve et l'ACL du tailnet. Le contrat porte cette règle, pas seulement
`tailnet-only`.

## Implementation Notes

- Contrats, fixture et tests livrés ; aucun code runtime mobile ou observateur.
- Trois issues seulement, résolues par la table partagée : `succeeded`
  (`message.complete/complete`), `failed` (`message.complete/error` ou `error`),
  `stopped` (`message.complete/interrupted`).
- Le push est un message FCM `notification + data` : le bloc `notification`
  porte un libellé générique dérivé de l'issue pour l'affichage app fermée, et
  le bloc `data` reste strictement `{subscriptionId, outcome}`.
- Les points G3 acceptés portent `validatedBy: Alanc` et leur date ; les ports
  443/8787, la terminaison TLS et la version FCM sont explicitement `proposed`.
  La validation globale est `partial`, sans prétendre que ces valeurs sont
  validées.
- Le token FCM est enregistré avec le `subscriptionId` avant la soumission et
  renouvelé par ré-enregistrement ; il n'entre ni dans le push ni dans les
  journaux.
- `attach` porte `sessionId`, `profile` et `executionId` ; l'exécution est
  composée depuis la session et `prompt.submit.result.user_row_id`, puis
  rapprochée du terminal par `session_id` + `persisted_turn.user_row_id`.
- Un `error` de session ne notifie que l'unique exécution attachée non encore
  notifiée ; le premier terminal gagne et les terminaux tardifs sont ignorés.
- Le curseur `{connection, profile, sessionId, last_seen}` permet le rattrapage ;
  `truncated` ou un changement d'`epoch` impose un refetch de l'historique.
- La rétention purge les abonnements notifiés/expirés, la déduplication et
  l'outbox ; `dropped` est compté et exposé dans la santé.
- Les erreurs HTTP sont bornées et les journaux rédigent les identifiants, le
  token et l'autorisation.
- La santé porte une sonde et un seuil par raison de dégradation ; les compteurs
  incluent `dropped`, `expired`, `revoked` et `invalidToken`.
- `pending` et `blockers` sont datés, structurés et reportés à 5.5 ; aucun port
  hôte n'est publié et l'accès tailnet est explicite.
- Firebase n'est pas créé : `status: "not-created"`, `identifier: null`, aucune
  valeur fictive. La création est **reportée à 5.5** par décision d'Alanc du
  2026-10-26 ; G3 reste ouverte.
- Constats Android datés du 2026-10-26 sur le Pixel 8 Pro
  `39161FDJG0026X` ; chaque cas porte son comportement attendu.
- Le correctif JPEG `4571d09` et la stabilisation du test de flux `4ba2a0a` sont
  arrivés pendant l'implémentation. La vérification et la revue de 5.1 portent
  sur les changements au-dessus de `4ba2a0a`, sans compter ces apports d'epic 4.
- Vérification : `flutter analyze` sans anomalie, 29 tests ciblés réussis, suite
  complète **466 réussis, 17 ignorés, aucun échec**. Preuves dans
  `story-5-1-verification/`.

## Spec Change Log

- 2026-10-26 : tâche de déploiement scindée entre le contrat écrit (fait) et la
  création Firebase par Alanc (reportée à 5.5), pour ne pas déclarer G3 franchie.
- 2026-10-26 : payload corrigé de data-only à `notification + data` avec
  libellés génériques côté serveur, pour qu'Android affiche la fin de travail
  même app fermée ; le data reste strict `{subscriptionId, outcome}`.
- 2026-10-26 : validation requalifiée par décision ; les ports, la terminaison
  TLS et la version FCM ne sont plus présentés comme validés par Alanc.
- 2026-10-26 : passe ciblée après revue — copie `auth` comparée, REST lié à
  `methods.json`, version FCM liée à sa proposition, dépassement de rejeu
  défini et bind du conteneur asserté.
- 2026-10-26 : revue indépendante ciblée — journaux normalisés, contradiction
  `clientConfig` corrigée, règle `error` testée, assertions vides remplacées,
  TTL par état et token dry-run explicités.
- 2026-10-26 : `executionId` composé à l'attache depuis
  `prompt.submit.params.session_id` et `prompt.submit.result.user_row_id` ;
  `persisted_turn.submission_id` renforce la corrélation quand il est présent,
  sans remplacer `user_row_id` (entrée corrigée après la revue).
- 2026-10-26 : le correctif JPEG et la stabilisation du test de flux ont rendu
  la base verte ; la revue utilise `review_base_commit` pour ne pas mélanger
  les changements d'epic 4 à ceux de 5.1.
- 2026-10-26 — **revue, loopback `bad_spec` (G1)** : déclenché par BH1-BH5,
  BH10-BH14, EC1-EC7 et VG3-VG4. Le contrat ne permettait pas de localiser la
  session, d'enregistrer le token, de rattraper un redémarrage, de purger ou de
  corréler une erreur de session. État connu mauvais : `attach` sans
  session/profil, `executionId` préféré indisponible à l'attache, `error`
  déclaré terminal mais non notifiable, aucun token/curseur/rétention/erreur/
  seuil de santé, statuts d'endpoint incohérents. Amendements : section
  « Contrat de suivi — exigences amendées », Code Map, tâches, critères
  d'acceptation, notes. **KEEP** : trois terminaux issus du mapping, payload
  `notification + data` avec data strict, `validatedBy: Alanc` par décision,
  FCM gratuit/Spark, Firebase non créé et G3 ouverte, constats Android datés,
  aucun code runtime mobile/observateur, aucun secret versionné.

## Review Triage Log

Revue du 2026-10-26 sur le diff depuis `4ba2a0a`, trois couches : Blind Hunter
(BH), Edge Case Hunter (EC), Verification Gap (VG). Chaque constat reçoit un
verdict et sa preuve ; les regroupements et routes suivent.

| ID | Constat | Verdict | Preuve |
|---|---|---|---|
| BH1 | Aucun modèle ni endpoint de token FCM : le registre ne connaît que `subscriptionId`. | medium | `notification-tracking.json` : `register.body` vaut `["subscriptionId"]` (l. 242-244) ; aucun champ token dans `registry` ni `endpoints`. |
| BH2 | `attach` ne porte ni session ni profil ; l'observateur ne peut pas localiser le tour. | high | `attach.body` vaut `["executionId"]` (l. 264-266) ; `session.resume`, `session.history`, `session.events.since` et `session.status` exigent `session_id` (`contracts/openrpc.json`). |
| BH3 | `executionId` préféré (`persisted_turn.submission_id`) n'existe qu'au terminal ; le repli `user_row_id` est scopé par `session_id`, jamais envoyé. | high | `preferredSource` l. 136-140 ; `fallback` l. 141-145 ; `MessageCompletePayload.persisted_turn` et `PromptSubmitResult.user_row_id` dans `openrpc.json`. |
| BH4 | Aucune politique quand une même exécution produit plusieurs terminaux. | medium | `deduplication.key` inclut `terminal` (l. 155-160) : `succeeded` et `failed` sont deux clés ; aucune règle de conflit. |
| BH5 | La promesse « au moins une livraison » contredit l'abandon silencieux à 48 h et l'absence de relance après 5 essais. | medium | `afterMaxAttempts: keep-in-outbox` (l. 378), `dropAfterSeconds: 172800` (l. 379), aucun `dropped` dans `health.counters` (l. 403-409). |
| BH6 | Les doublons fournisseur n'ont aucune politique d'affichage. | low | `providerMayDuplicate: true` (l. 380), `exactlyOnce: false` (l. 170) ; aucun tag ni collapse key. |
| BH7 | La liste des champs interdits ne couvre pas les noms snake_case réellement portés par Hermes. | low | `forbiddenDataFields` l. 209-232 contient `sessionId` mais pas `session_id`, `submission_id`, `user_row_id`, `profile_id`, `connection_id`. |
| BH8 | `mapping.terminalRule` dit que `workState` fournit l'issue, ce qui est faux pour `message.complete`. | medium | Ligne 22 ; `event-mapping.json` donne `message.complete.workState: null` et un `statusMap`. |
| BH9 | Aucune fixture pour `message.complete/error`. | false | Le test l. 54-71 résout chaque source par `mapping.map`, y compris `message.complete/error` ; `fixture` est défini par terminal, pas par source. La couverture existe. |
| BH10 | Aucun contrat de curseur ni de rattrapage après redémarrage. | medium | Aucune section `catchUp` dans `notification-tracking.json` ; `persistentVolume.contents` contient pourtant `cursor` (`notification-deployment.json` l. 215-220) ; `session.events.since` expose `last_seen`, `latest_seq`, `truncated`, `epoch`. |
| BH11 | Aucune rétention : les entrées attachées ou notifiées ne sont jamais purgées. | medium | `expired` seulement `ttl-elapsed-without-attach` (l. 128-132) ; `revokeOnTerminal: false` (l. 153) ; aucune purge de la déduplication. |
| BH12 | Aucun contrat d'enveloppe d'erreur ni de rédaction des journaux. | medium | `auth.logging: redacted` est la seule règle (l. 341) ; aucun schéma d'erreur ; `subscriptionId` voyage dans le chemin. |
| BH13 | Statuts et idempotence se contredisent. | medium | `register` idempotent mais 409 (l. 245-256) ; `retryOn` inclut 500/502/504 (l. 352-359) absents des `errorStatus` ; `revoke` renvoie 404 (l. 293-298) ; `attach` 202 sans suite. |
| BH14 | La santé n'a ni seuils ni sondes, et ses compteurs masquent les abandons. | medium | `degradedWhen` l. 390-395 sans seuil ; `counters` l. 403-409 sans `dropped`, `expired`, `revoked`. |
| BH15 | `hermes-access` est déclaré accepté alors que la checklist de relecture le laisse à relire. | medium | `notification-deployment.json` l. 27 et 96-103 ; `g3-decisions.md` laisse « Accès Hermes… à relire ». |
| BH16 | `pending` et `blockers` n'ont ni propriétaire ni date ; `pending` omet la création du compte de service. | medium | `gate.blockers` l. 9-13 et `validation.pending` l. 43-46 sont des chaînes ; `statusReason` l. 8 ne mentionne pas le report à 5.5. |
| BH17 | Les tests figent `gate: open` et `validation: partial`, donc la clôture de G3 en 5.5 cassera la suite. | low | `notification_contract_test.dart` l. 319-331 et 624. |
| BH18 | Un chemin personnel Windows est versionné et le scan ne couvre pas les documents de vérification. | medium | `g3-decisions.md` contient un chemin SDK Windows absolu ; le scan l. 628-698 ne lit que les deux JSON. |
| BH19 | Le test des champs interdits est court-circuité par le contrôle de longueur ; la couverture inverse manque. | low | `accepts` l. 174-179 retourne faux sur la longueur avant la liste ; `forbidden.take(8)` l. 186 ; aucune vérification que tout terminal du mapping est représenté. |
| BH20 | Le README et le contrat de déploiement dupliquent des valeurs du contrat de suivi ; aucune comparaison ne prévient la dérive. | low | README : canal, TTL, ports, versions ; `deployment.auth`, `runtime.health`, `fcm.payload` répètent le tracking ; `clientFallback` l. 197 n'a pas de source lisible par le client. |
| BH21 | La preuve Android parle encore de messages data-only et malnomme le standby bucket. | medium | `android-prerequisites.md` l. 29 : « messages data-only » et « standby bucket 10 (actif) » alors que 10 = working set et que le contrat est `notification + data`. |
| BH22 | Les constats Android ne sont pas rattachés au build revu et certaines commandes manquent. | low | `android-prerequisites.md` l. 18 (versionCode 15 installé, dépôt en 0.1.0+1) ; `dumpsys notification` (l. 28) absent des commandes l. 46-62 ; `enabled/stopped` de GMS non couvert par `grep versionName`. |
| BH23 | Le bind `0.0.0.0` et l'exposition tailnet-only n'ont aucune règle d'application. | medium | `notification-deployment.json` `runtime.listen.bind` l. 224, `origin.exposure` l. 232 ; aucune publication de port ni ACL. |
| BH24 | La matrice de cas limites de la spec est trop mince. | low, rejeté | Le correctif consisterait à modifier la section gelée de la spec ; le workflow l'interdit. Les cas sont couverts par le nouveau contrat et ses tests. |
| BH25 | `epic-5-context.md` n'est ni dans le Code Map ni dans le rapport. | low | Le diff ajoute le fichier ; le Code Map et la table du rapport ne le listent pas. Le Code Map est gelé ; la ligne du rapport est ajoutée. |
| EC1 | `attach` envoie un entier `user_row_id`, le terminal expose un `submission_id` nullable : aucun rapprochement possible. | high | Même preuve que BH3 : `PromptSubmitResult.user_row_id` (integer) contre `PersistedTurn.submission_id` (string nullable). |
| EC2 | `attach` ne porte pas le `session_id` dont le repli a besoin. | high | Même preuve que BH2 : `attach.body` l. 264-266. |
| EC3 | Aucun token FCM dans `register`/`attach` ni endpoint de rotation. | medium | Même preuve que BH1. |
| EC4 | `error` est déclaré terminal `failed` mais ne porte aucun `executionId` ; la règle `whenMissing` le rend non notifiable. | high | `terminals.failed.sources` l. 44-47 ; `ErrorPayload` n'a que `message` ; `whenMissing: no-attach-no-notification` l. 147. |
| EC5 | Les entrées attachées n'expirent jamais. | medium | Même preuve que BH11. |
| EC6 | Après 5 essais, aucune relance n'est définie avant l'abandon à 48 h. | medium | Même preuve que BH5. |
| EC7 | `register`/`attach` idempotents renvoient 409, que le mobile ne réessaie jamais. | medium | L. 245 et 267 ; 409 dans `errorStatus` l. 253 et 276 ; 409 dans `neverRetryOn` l. 365. |
| EC8 | Le bind `0.0.0.0` peut exposer le bearer hors tailnet si le port hôte est publié. | medium | Même preuve que BH23. |
| VG1 | Le test « accès Hermes en lecture seule » ne lit jamais `allowedRest`. | medium | `notification_contract_test.dart` l. 454-491 ; `allowedRest` n'apparaît que dans le contrat. |
| VG2 | Le test des endpoints ne fige ni les chemins exacts ni les corps. | medium | Test l. 255-279 : seul le préfixe `/v1/` est vérifié ; `attach.path` et `attach.body` ne sont pas assertés. |
| VG3 | La source préférée de `executionId` n'existe pas au moment de l'attache. | high | Même preuve que BH3. |
| VG4 | Le chemin `error` → `failed` n'est pas notifiable sans identité d'exécution. | high | Même preuve que EC4. |
| VG5 | Le chemin personnel Windows est versionné et hors du scan. | medium | Même preuve que BH18. |
| R1 | `deployment.auth` est une copie machine non comparée au contrat de suivi. | low | `notification-deployment.json` `auth` ; le test ne lit que `tracking.auth`. |
| R2 | `allowedRest` est figé dans le test et n'est pas lié à `contracts/methods.json`. | low | Set l. 1113-1119 ; `methods.json` n'est pas lu. |
| R3 | La proposition `fcm-version` n'est pas comparée au paquet `fcm.selected`. | low | `proposed` l. 232-240 ; test l. 1133-1137. |
| R4 | `maxReplayEvents` n'a pas de politique de dépassement. | low | `catchUp` l. 543 ; la note promet qu'aucun terminal n'est perdu. |
| R5 | Le bind du conteneur n'est pas asserté, seulement sa portée et l'absence de port hôte. | low | `listen` l. 264 ; test l. 1040-1045. |
| R6 | Les journaux de test versionnés contiennent le chemin utilisateur absolu et le scan ne les lit pas. | high | `flutter-targeted.log` et `flutter-test.log` (30 et 484 occurrences) ; scan l. 1344-1353. |
| R7 | Le critère d'acceptation exige `user_row_id` pour tout terminal, alors que `error` n'en porte pas et suit la règle d'unicité. | medium | Spec l. 80 ; contrat l. 50-53. |
| R8 | La règle de corrélation de `error` n'est pas assertée. | medium | Contrat l. 50-53 ; test l. 194-235. |
| R9 | Le numéro de série ADB est versionné. | false | `android-prerequisites.md` l. 11 ; la spec l'exige comme preuve ; ce n'est ni un secret, ni un token, ni un chemin. |
| R10 | `clientConfig.generatedBy` vaut `5.3` alors que la création du projet est reportée à `5.5`. | medium | `notification-deployment.json` l. 457-462 ; test l. 1278. |
| R11 | Le change log présente `submission_id` comme source principale et `user_row_id` comme repli, à l'inverse du contrat final. | medium | Spec l. 209-211 ; contrat l. 164-175. |
| R12 | L'assertion de copie Android compare le contrat à lui-même. | low | Test l. 1220-1223. |
| R13 | Le contrôle de version FCM par `contains` accepte une version préfixée ou suffixée. | low | Test l. 1170-1172. |
| R14 | Le journal ciblé répète le dernier test et omet le premier `event_mapping`. | false | `flutter-targeted.log` l. 16-18 ; artefact du reporter compact, total `+29`. |
| R15 | Le TTL applicable à un abonnement attaché ou notifié n'est pas nommé dans le contrat. | low | Contrat l. 140-143 et 191-192 ; test l. 542-546. |
| R16 | Les boundaries omettent `message.complete/error`. | low | Spec l. 33 ; contrat l. 40-49. |
| R17 | `fcmTokenRequiredFor: ["personal"]` contredit le cycle `registered.requires: [subscriptionId, fcmToken]` en dry-run. | low | Contrat l. 104-112 et 307-309 ; déploiement l. 476-508. |
| R18 | Le README qualifie les deux contrats de « documentaires » alors que le déploiement porte `evidence: decision`. | low | `contracts/README.md` l. 228 ; déploiement l. 3. |

R1-R5 sont issus de la passe ciblée du même jour, après application des routes
G2-G12. R6-R18 proviennent de la revue indépendante ciblée qui a suivi ; R9 et
R14 sont classés `false`, les autres sont corrigés.

### Regroupements et routes

- **G1 — bad_spec : contrat de suivi incomplet.** BH1, BH2, BH3, BH4, BH5,
  BH10, BH11, BH12, BH13, BH14, EC1, EC2, EC3, EC4, EC5, EC6, EC7, VG3,
  VG4. La spec non gelée n'exigeait ni token, ni corrélation session/exécution,
  ni rattrapage, ni rétention, ni erreurs/journaux, ni seuils de santé, alors
  que `epic-5-context.md` les exige. La spec est amendée et le contrat
  re-dérivé. Les preuves de payload `notification + data`, les trois terminaux,
  les décisions G3 et l'absence de Firebase restent acquises.
- **G2 — patch : preuves G3.** BH15, BH16, BH18, VG5. Cocher la relecture
  `hermes-access`, structurer `pending`/`blockers` avec propriétaire et date,
  retirer le chemin personnel et étendre le scan aux documents.
- **G3 — patch : tests de contrat.** BH17, BH19, VG1, VG2. Assertions de
  cohérence de la porte, chemins/corps/statuts exacts, `allowedRest`, champs
  interdits et couverture inverse du mapping.
- **G4 — patch : documentation Android.** BH21, BH22. Remplacer data-only,
  corriger le bucket, ajouter les commandes et dater la version installée.
- **G5 — patch : exposition tailnet.** BH23, EC8. Interdire la publication du
  port hôte et documenter l'application Tailscale.
- **G6 — patch : doublons visibles.** BH6. Ajouter tag/collapse et politique
  d'affichage.
- **G7 — patch : champs interdits snake_case.** BH7.
- **G8 — patch : règle terminale.** BH8.
- **G9 — false : BH9.** Le test couvre déjà `message.complete/error` par le
  mapping ; aucune fixture supplémentaire n'est nécessaire.
- **G10 — rejeté : BH24.** Le correctif modifierait la section gelée.
- **G11 — patch : inventaire.** BH25. Ajouter `epic-5-context.md` au rapport.
- **G12 — patch : README sans duplication.** BH20. Alléger le README et ajouter
  une comparaison des copies machine.
- **G13 — patch : résidus de la passe ciblée.** R1-R5. Comparer `deployment.auth`
  au contrat, lier `allowedRest` à `methods.json`, lier la version FCM à sa
  proposition, définir le dépassement de rejeu et asserter le bind du conteneur.
- **G14 — patch : revue indépendante ciblée.** R6-R8, R10-R13, R15-R18.
  Normaliser les journaux, corriger le critère `error` et `clientConfig`,
  remplacer les assertions vides, expliciter le TTL par état, le token dry-run
  et le change log. R9 et R14 sont classés `false`.

La route G1 déclenche le loopback `bad_spec` (`review_loop_iteration` 0 → 1).
Les routes G2 à G12 sont appliquées après la re-dérivation ; elles portent sur
des preuves, des tests et de la documentation, pas sur le cœur du contrat.

## Design Notes

- `subscriptionId` est généré par le mobile et sert de clé de routage locale, donc le data ne porte ni `sessionKey` ni identité Hermes.
- Le message FCM est `notification + data` : le libellé générique est dérivé de l'issue seule et le data reste la source de routage ; l'app peut afficher le même libellé en repli au premier plan.
- `executionId` est composé par le mobile au moment de l'attache : `base64url(session_id + ':' + user_row_id)`. L'observateur le recalcule depuis le terminal avec `persisted_turn.user_row_id` ; `submission_id` ne sert qu'à renforcer la corrélation quand il est présent.
- Un `error` de session est rattaché à l'unique exécution attachée et non notifiée ; cette règle évite une fausse notification après une réussite.
- Le tag Android `hermes:{subscriptionId}:{outcome}` déduplique les livraisons fournisseur visibles ; le collapse key `hermes:{subscriptionId}` regroupe le suivi.
- La santé renvoie un état borné (`ok` / `degraded`), des raisons avec seuils et des compteurs, jamais de contenu ni d'identifiant de suivi.

## Verification

**Commands:**
- `flutter analyze --no-pub` — aucune anomalie.
- `flutter test --no-pub test/notification_contract_test.dart test/event_mapping_test.dart test/contracts_test.dart` — 29 réussis.
- `flutter test --no-pub` — 466 réussis, 17 ignorés, aucun échec, sur la base
  `4ba2a0a` (correctif JPEG `4571d09` inclus).
- Journaux : `story-5-1-verification/flutter-analyze.log`,
  `flutter-targeted.log`, `flutter-test.log` ; détail dans
  `story-5-1-verification/implementation-report.md`.

**Manual checks:**
- Les décisions acceptées ont été approuvées avec la spec le 2026-10-26 ; les
  ports, la terminaison TLS et la version FCM restent à confirmer en 5.2/5.3.
- Vérifier qu'aucun secret ni chemin personnel n'est versionné : couvert par le
  test de contrat et la revue.
- La création du projet Firebase et du compte de service est reportée à 5.5 ;
  G3 ne peut être franchie que par 5.5 sur téléphone réel.
