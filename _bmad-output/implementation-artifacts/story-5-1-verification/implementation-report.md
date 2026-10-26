# Story 5.1 — Preuves d'implémentation

Date : 26 octobre 2026.
Base de vérification : `4ba2a0ab2e37bd6215147ff6745f4b67ab7b7284`, qui inclut
le correctif JPEG `4571d09` et la stabilisation du test de flux `4ba2a0a`.
Base d'origine de la story : `7d223a1c55fd1e2e87c3b8ed61ada436c28977bd`.
Portée : contrat de suivi, décisions de déploiement G3, fixture synthétique,
tests de contrat et constats Android. Aucun code runtime mobile ou observateur.

## Changements

| Fichier | Contenu |
| --- | --- |
| `contracts/notification-tracking.json` | Schéma v1 : provenance, référence au mapping, trois terminaux, token FCM, cycle du `subscriptionId`, corrélation session/profil/exécution, conflits, déduplication, message FCM `notification + data` avec data strict, endpoints et statuts, auth, erreurs, journaux, rattrapage, rétention, santé à seuils, retries |
| `contracts/notification-deployment.json` | Décisions G3 datées et statuées : add-on HA, volume `/data`, origine tailnet sans port hôte publié, auth par environnement, accès Hermes en lecture seule avec REST épinglé, FCM 17.x proposé et repli 16.x, token référencé, gratuité FCM, Firebase non créé et création reportée, dry-run verrouillé, ports/TLS proposés |
| `contracts/README.md` | Section 5.1 : rationale, payload, santé, provenance, statut de validation, sans recopier les valeurs des JSON |
| `contracts/fixtures/message-complete-interrupted.json` | Fixture synthétique `message.complete` / `interrupted` |
| `test/event_mapping_test.dart` | Compte des fixtures 10 → 11 |
| `test/notification_contract_test.dart` | 17 tests : terminaux et couverture inverse du mapping, payload strict, token et rotation, corrélation, conflits, endpoints exacts, auth, erreurs et journaux, rattrapage, rétention, seuils de santé, décisions G3, exposition tailnet, copies machine, environnements, secrets et chemins personnels |
| `_bmad-output/implementation-artifacts/story-5-1-verification/g3-decisions.md` | Décisions, statuts, preuves Firebase, contrat de suivi, écarts, actions d'Alanc, relecture |
| `_bmad-output/implementation-artifacts/story-5-1-verification/android-prerequisites.md` | Constats ADB datés, comportement attendu par cas, version installée et commandes de reproduction |
| `_bmad-output/implementation-artifacts/epic-5-context.md` | Exigences d'epic : token, rattrapage, journaux sans contenu |
| `_bmad-output/implementation-artifacts/spec-5-1-contrat-suivi-deploiement-observateur.md` | Spec, triage de revue, exigences amendées et critères d'acceptation |

## Décisions structurantes

- Le mapping `contracts/event-mapping.json` reste la seule source des
  terminaux. Trois issues seulement : `succeeded`
  (`message.complete/complete`), `failed` (`message.complete/error` ou
  `error`), `stopped` (`message.complete/interrupted`).
- Le mobile génère `subscriptionId` et enregistre le token FCM avant
  `prompt.submit`, sans bloquer l'envoi. Après acceptation confirmée, il attache
  la session, le profil et l'exécution. La rotation du token se fait par
  ré-enregistrement du même `subscriptionId` ; le token est chiffré côté
  observateur et n'entre ni dans le push ni dans les journaux. Seul
  l'environnement personnel exige un token réel ; le dry-run utilise un
  marqueur synthétique.
- `executionId` est composé à l'attache depuis
  `prompt.submit.params.session_id` et `prompt.submit.result.user_row_id`
  (entier, scopé par session). L'observateur le recalcule depuis
  `event.params.session_id` et `message.complete.payload.persisted_turn.user_row_id`.
  `persisted_turn.submission_id` renforce la corrélation quand il est présent,
  mais ne remplace jamais `user_row_id`. Si la session ou l'identité manque,
  aucun rattachement et aucune notification.
- Un `error` de session ne notifie que l'unique exécution attachée et non
  notifiée de cette session ; sans cette unicité, il est ignoré. Pour une même
  exécution, le premier terminal notifié gagne et les terminaux tardifs sont
  ignorés. La déduplication porte sur
  `(subscriptionId, executionId, terminal)` ; les doublons fournisseur visibles
  sont dédupliqués par tag.
- Le push est un message FCM `notification + data`. Le bloc `notification`
  porte un titre fixe et un libellé générique dérivé de l'issue, donc Android
  peut l'afficher app fermée ; le bloc `data` ne porte que
  `{subscriptionId, outcome}` en chaînes. Aucun texte, identité de session ou de
  profil, chemin, jeton ou secret n'y figure.
- Après un redémarrage, l'observateur reprend depuis le curseur `last_seen`
  avec `session.events.since` ; `truncated` ou un changement d'`epoch` impose
  un refetch de `session.history` avant de notifier. Au-delà de la borne de
  rejeu, il reprend depuis le dernier événement traité.
- La rétention purge les abonnements non attachés, attachés, notifiés, expirés
  ou révoqués, la déduplication et l'outbox ; `expiryByState` nomme le TTL
  applicable et les révoqués sont supprimés à la révocation. Un abandon après
  la fenêtre de relance incrémente `dropped` et reste visible dans la santé.
- FCM est gratuit, sans quota de messages, plan Spark, sans facturation. Le
  contrat le consigne avec sa source et une date.
- Endpoints exacts `POST /v1/subscriptions`,
  `POST /v1/subscriptions/{subscriptionId}/attach`,
  `DELETE /v1/subscriptions/{subscriptionId}`, `GET /v1/health`. `register` et
  `attach` sont idempotents sans 409 ; `revoke` traite 404 comme un succès ;
  `attach` peut répondre 202 avant que la session soit vive. Les erreurs HTTP
  sont bornées et les journaux rédigent l'autorisation, le token et les
  identifiants.
- La santé exige le bearer et ne renvoie qu'un état borné, des raisons avec
  sonde et seuil, et des compteurs incluant `dropped`, `expired`, `revoked` et
  `invalidToken` ; jamais de contenu ni d'identifiant de suivi.
- Auth mobile → observateur : bearer opaque par environnement, haché côté
  observateur (SHA-256 salé, comparaison en temps constant), conservé côté
  mobile dans `flutter_secure_storage`.
- L'observateur lit Hermes uniquement par le contrat épinglé et le mapping,
  avec une liste de méthodes et de routes REST en lecture seule.
  `session.resume` attache le flux sans soumettre ni interrompre de travail.
  Aucun port hôte n'est publié : l'accès passe par Tailscale Serve et l'ACL du
  tailnet.
- Les points G3 acceptés portent `validatedBy: Alanc` et leur date. Les ports
  443/8787, la terminaison TLS Tailscale et la version FCM restent `proposed`,
  avec une échéance de confirmation en 5.2/5.3 ; la validation globale est
  `partial`. Les blocages et reports Firebase sont structurés, datés et portés
  par Alanc jusqu'à 5.5.

## Vérification

| Commande | Résultat | Preuve |
| --- | --- | --- |
| `flutter analyze --no-pub` | Aucune anomalie | `flutter-analyze.log` |
| `flutter test --no-pub test/notification_contract_test.dart test/event_mapping_test.dart test/contracts_test.dart` | 29 réussis | `flutter-targeted.log` |
| `flutter test --no-pub` | 466 réussis, 17 ignorés, aucun échec | `flutter-test.log` |

`git diff --check` ne signale aucune erreur ; les avertissements CRLF portent
sur les fichiers ajoutés et `test/event_mapping_test.dart`.

Les journaux sont normalisés : le chemin du dépôt devient `<repo>/` et le
chemin utilisateur `<home>/` ; le scan de contrat lit aussi les trois journaux.
Le reporter compact répète le nom du dernier test à la clôture d'un fichier ;
le total `+29` et les fichiers listés font foi.

### Apports d'epic 4 arrivés pendant l'implémentation

Le correctif JPEG `4571d09` a permis l'envoi des photos et mis à jour
`contracts/file-limits.json` et ses tests. La suite complète restait instable
sur `attachment_flow_test.dart` : le test attendait le brouillon mais pas le
chargement de la pièce JPEG restaurée. Le commit `4ba2a0a` ajoute cette attente
et rend la suite déterministe. Ces deux commits ne font pas partie de 5.1 ; la
revue de 5.1 utilise `review_base_commit: 4ba2a0a` pour ne pas les mélanger aux
changements de contrat.

## État de G3

**G3 reste ouverte.** Le projet Firebase et le compte de service ne sont pas
créés ; aucun identifiant n'est inventé. Le contrat porte
`status: "not-created"` et `identifier: null`. Par décision d'Alanc du
2026-10-26, la création est reportée à 5.5, avant l'essai réel sur téléphone.
La résolution de FCM 17.x par 5.3 et l'essai réel de 5.5 restent les prochaines
étapes.

## Risques et écarts

| Écart | Effet | Suite |
| --- | --- | --- |
| Projet et compte Firebase absents | G3 ouverte ; aucune notification réelle possible | 5.5 |
| Ports/TLS proposés, non validés | configuration d'accès à confirmer | 5.2 |
| FCM 17.x non résolu/compilé | choix définitif non prouvé | 5.3 |
| `POST_NOTIFICATIONS` non déclaré | aucune notification affichée | 5.3 |
| Canal `hermes_turn_complete` absent | l'OS ne peut pas afficher la fin | 5.3 |
| Aucun essai réel | comportement app fermée/coupure/redémarrage inconnu | 5.5 |
| Livraison non « exactement une fois » | doublon possible côté fournisseur | assumé : au moins une livraison, déduplication locale |
