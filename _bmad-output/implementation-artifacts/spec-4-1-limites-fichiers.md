---
title: 'Story 4.1 - Fixer les limites de fichiers sur mon installation'
type: 'feature'
created: '2026-10-24'
status: 'done'
baseline_commit: '3972ff35b9f46e37d21ca335a9df1312201d9e27'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/contracts/README.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** L'app ignore ce que l'installation Hermes d'Alanc accepte réellement. Le contrat épinglé documente `file.attach` (non-images) avec `actual: unverified`, ne fixe aucune limite (type, taille, nombre) et n'expose aucun transport d'image. Sans mesure, 4.2–4.4 afficheraient des limites inventées.

**Approach:** Sonde Dart dans `tool/` réutilisant `IoHermesTransport` et `HermesRpc` sans modifier `lib/`, exécutée contre l'installation avec les chemins du corpus d'Alanc (déposé hors suivi) et un profil de test existant, passés en arguments ; URL et identifiants viennent de l'environnement. Elle éprouve `file.attach`, l'upload REST du build et le transport image constaté, puis consigne chaque résultat séparément dans `contracts/`, sous forme lisible par la machine. Aucun proxy dans la chaîne. Chaque limite porte sa preuve ; le reste reste non vérifié.

## Boundaries & Constraints

**Always:** Retenir la limite la plus restrictive observée. Vérifier la réception côté serveur (référence + relecture de session), jamais un aperçu client. Consigner nature et volume du corpus sans son contenu. Distinguer « reçu » de « analysé par le modèle ». Consigner séparément chaque surface éprouvée et marquer toute route hors contrat épinglé, avec la preuve du build qui la porte.

**Never:** Inventer une limite. Coder une limite en dur. Utiliser le profil personnel d'Alanc. Journaliser un chemin, un identifiant ou le contenu d'un fichier. Présenter un upload réussi comme une analyse. Étendre le contrat épinglé sans preuve du build installé. Modifier `lib/` pour la sonde. Faire dépendre l'app d'une route non épinglée sans arbitrage d'Alanc.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| ACCEPTÉ | Pièce sous la limite | Référence serveur + relecture confirment la pièce dans la session | Consigner le volume exact |
| REFUSÉ | Pièce au-delà d'une limite | Limite la plus restrictive entre accepté et refusé | Pas d'interpolation : seuil marqué non mesuré |
| ABSENT | Méthode ou route non exposée | Consigner `absent`, remonter à Alanc | Aucun contournement |
| INCERTAIN | Timeout, réponse invalide | Consigner `unverified` | Aucune valeur déduite du silence |
| IMAGE / MODÈLE | Image sur un profil de test | Consigner si le modèle l'analyse | `null` si non observé |

</frozen-after-approval>

## Code Map

- `contracts/openrpc.json` l.27-44 — `file.attach`, non-images ; `FileAttachParams` (`session_id` requis ; `profile`/`path`/`data_url`/`name` optionnels) ; `FileAttachResult` (`attached`, `path`, `ref_path`, `ref_text`, `uploaded`).
- `contracts/capabilities.json` l.79-85 — `file.attach` passe à `actual: present` depuis la mesure du 2026-10-24 ; seul endroit où l'état réel se consigne.
- `contracts/README.md` — section 4.1 : protocole, transports, résultats mesurés, corpus.
- `lib/data/hermes_adapter.dart` — `IoHermesTransport` l.41-161 (`dart:io`, JSON, Bearer l.81) ; `HermesRpc.submitParams` l.536. Aucun multipart.
- `lib/data/connection_repository.dart` — `_documentaryCapabilities` l.51-63 ; `_authorized` l.253 ; `gateway.capabilities` l.406-451 ; `_loadProfiles` l.565.
- `lib/models/profile.dart` — `Profile` = `key`/`label`/`isDefault` ; ni modèle ni vision (`hermes_adapter.dart` l.290-313).
- `lib/data/outbox_repository.dart` l.599 — `onStep('attachments')` réservé : 4.3 y branchera l'upload.
- `test/contracts_test.dart` — `contract(name)` lit `contracts/<name>.json` ; validation de forme ajoutée.

## Tasks & Acceptance

**Execution:**
- [x] `contracts/file-limits.json` -- contrat des limites (corpus, transports, limites par type avec `verified`/valeur nulle, vision par profil, non-vérifiés) -- 4.2 lira ces valeurs
- [x] `.gitignore` -- ignorer `_bmad-output/implementation-artifacts/corpus-pieces-jointes/` -- empêche de versionner le corpus d'Alanc
- [x] `tool/mesure_pieces_jointes.dart` -- sonde : chemins du corpus, profil cible et surfaces en arguments, auth par variables d'environnement, sortie JSON au format du contrat -- rejoue la mesure
- [x] `contracts/README.md` -- section : protocole, transport disponible, preuves, écarts avec la provenance documentaire -- sépare `install-measured` de `documentary`
- [x] `contracts/capabilities.json` -- `file.attach.actual` = `present`/`absent` **uniquement** depuis la mesure -- évite une capacité supposée
- [x] `test/contracts_test.dart` -- limite non vérifiée ⇒ valeur nulle, chaque catégorie présente, aucune donnée personnelle -- bloque une limite inventée
- [x] `test/file_measurement_test.dart` -- couvre les cinq lignes de la matrice (ACCEPTÉ, REFUSÉ, ABSENT, INCERTAIN, IMAGE / MODÈLE) -- satisfait l'audit de matrice

**Acceptance Criteria:**
- Given le corpus et un profil de test dédié, when chaque pièce est envoyée, then la réception est confirmée côté serveur dans la session visée et le volume accepté consigné.
- Given un refus ou un transport absent, when la sonde termine, then le contrat enregistre la limite la plus restrictive ou `absent`/`unverified`, sans valeur inventée.
- Given un profil de test et une image, when elle est envoyée, then le contrat indique si le modèle analyse les images, ou `null`.
- Given le contrat produit, when `flutter test test/contracts_test.dart` s'exécute, then aucune limite non vérifiée ne porte de valeur et aucune donnée personnelle n'apparaît.
- Given une installation sans transport exploitable, when la mesure échoue, then le blocage remonte à Alanc et 4.2–4.4 restent bloquées.

## Implementation Notes

- 2026-10-24 : `contracts/file-limits.json` livré d'abord `evidence: unmeasured` (toutes limites `null`, `verified: false`) ; `tool/mesure_pieces_jointes.dart` (sonde Dart, 1 967 lignes) ; section 4.1 de `contracts/README.md` ; `contracts/file-limits.json` déclaré en asset ; `.gitignore` pour le corpus.
- 2026-10-24 : audit de matrice — logique pure extraite en `classifyOutcome`, `summarizeLimit`, `visionVerdict`, couverte par `test/file_measurement_test.dart` (17 tests). `flutter analyze` : aucun problème.
- 2026-10-24 : **campagne finale** exécutée de 15:15:13 à 15:27:06 UTC sur le build `0.22.2+1690` avec le profil non-défaut `mesure-pieces-jointes` : 20 sessions, 60 copies, 3 répétitions par pièce et par surface. Les trois transports sont `present` ; `file.attach` a 30 essais, 27 copies relues et 9 pièces acceptées sur 10, `rest.image-upload` et `image.attach_bytes` 15 essais et 15 reçus chacune. La pièce texte de 1 Mo, première de la campagne, est `unverified` : copies acceptées mais session orpheline (`ws_orphan_reap`), sans réponse ni bloc serveur ; elle n'entre dans aucune limite. Plus grandes tailles acceptées : texte 10 485 812 o, image 20 965 448 o, PDF 10 485 858 o, bureautique 10 485 797 o. Aucun refus observé : les `maxBytes` sont des bornes inférieures.
- 2026-10-24 : le nombre n'a pas de plafond observé ; `maxCount` reste `null` avec `threshold.count: lower-bound` (3 pièces acceptées par session). `unverified` liste les quatre `maxCount`. Le modèle `gpt-6-luna-900k` analyse les images (`analyzesImages: true`, preuve `marker`).
- 2026-10-24 : écart assumé — le corpus mesuré est synthétique et calibré (15 fichiers, 84 Mio) ; aucune photo ni aucun PDF réel n'a été déposé. Les MIME réels d'un appareil (JPEG/HEIC, EXIF) restent non couverts.
- 2026-10-24 : AC 1, 3 et 4 satisfaits par la campagne et les tests. AC 2 et AC 5 n'ont pas été déclenchés en réel : aucun refus et aucun transport absent n'ont été observés. Leur logique (`classifyOutcome`, `summarizeLimit`) est couverte par `test/file_measurement_test.dart` ; elle reste non éprouvée contre l'installation.
- 2026-10-24 : `summarizeLimit` distingue désormais un compte accepté (`threshold.count: lower-bound`) d'une absence de mesure ; la sortie de la sonde porte les champs `contract` et `source` de chaque transport, donc elle est directement copiable dans `contracts/file-limits.json`.
- 2026-10-24 : `pubspec.yaml` déclare l'asset, non prévu par les tâches : préparation de la lecture par 4.2, aucun impact sur 4.1.
- 2026-10-24 : **preuve de réception corrigée**. L'écho de la référence dans le prompt soumis ne compte plus : la sonde exige le bloc serveur `--- Attached Context ---` (ou les lignes `@image:`) et compte les pièces réellement présentes. Le test de 1 Mo qui passait à tort ressort désormais `unverified`, avec `maxBytes: null` et la sortie 2. `receiptVerdict` est une fonction pure couverte par cinq tests ; `test/file_measurement_test.dart` en compte 26.
- 2026-10-24 : revue à trois couches (36 constats) triée dans le journal ci-dessous. Quatre entrées de patch : statut `present` adossé à un reçu accepté, protocole documenté (variante `data_url`, budget réseau, rétention), provenance de `capabilities.json`, formulation du profil. Aucun `intent_gap` ni `bad_spec`.
- 2026-10-24 : la campagne a été interrompue par un backend Hermes en boucle (`Refusing to start: this host is already served by PID 604`), puis relancée après redémarrage de l'add-on, validé par Alanc.
- 2026-10-24 : une relance post-redémarrage a été interrompue à tort après 11 sessions : le processus attendait le réseau, il n'était pas bloqué. La campagne finale a ensuite produit 20 sessions en 12 minutes, sans intervention.
- 2026-10-24 : les textes de 5 et 10 Mo sont acceptés mais pas inlinés ; le bloc serveur les déclare « too large to inline safely » et les référence sur disque. 4.2 devra les lire par outil, pas supposer leur contenu dans le contexte.
- 2026-10-24 : `pubspec.yaml` ne déclare plus l'asset : aucun code ne le charge avant 4.2, qui l'ajoutera avec son lecteur.

## Spec Change Log

## Review Triage Log

Trois couches : aveugle (A1–A18), cas limites (L1–L10), vérification (V1–V8).
Les constats V sont pré-vérifiés par leur couche. « Corrigé » signifie que le
code de la revue ne produit plus le résultat décrit.

| # | Constat | Verdict | Preuve |
|---|---|---|---|
| A1 | `maxBytes` vérifiés alors que `refusedBytes` est vide | false | `threshold.bytes` vaut `lower-bound` pour les quatre catégories et le README l'explicite ; aucune règle machine ne manque. |
| A2 | Trou JPEG/HEIC/EXIF absent du contrat | false | `limits.image.observed.mediaTypes` ne contient que `image/png` et le README consigne l'écart ; le contrat porte donc l'information. |
| A3 | `proof.attempts` compte les pièces | false | Corrigé : `_transport` émet `pieces`, `repetitions` et `attempts` (somme des appels réels). |
| A4 | Un seul horodatage de départ | false | Corrigé : `install.measuredAt` et `install.finishedAt` bornent la campagne ; chaque preuve tombe dans l'intervalle. |
| A5 | `corpus.location` constant, campagne partielle en `install-measured` | false | Corrigé : `corpus.complete` et une entrée `unverified` signalent une campagne incomplète ; la localisation est celle du corpus documenté. |
| A6 | `_hasUsableTransport` accepte une route image | false | Corrigé : `hasUsableTransport` exige `file.attach` `present` **et** `proof.accepted > 0`, avec test dédié. |
| A7 | `present` alors que tout est refusé | low | `present` ne décrit que l'existence de la méthode ; `hasUsableTransport` bloque désormais, mais le contrat peut encore écrire `present` avec `accepted: 0`. → patch |
| A8 | Variante `data_url` et `uploaded` non consignés | low | `parameters: ['data_url']` est désormais consigné ; l'inflation base64 et le fait que `uploaded` n'est pas la preuve restent à documenter. → patch |
| A9 | Aucune section app ni budget de 15 s | low | La sonde passe par `IoHermesTransport` (15 s par étape) et a accepté 20 Mo ; l'intention exclut un proxy, mais le budget client n'est pas écrit. → patch |
| A10 | `install.build` non comparé à `release.json` | false | La sonde consigne le build observé ; `release.json` reste documentaire et `realAcceptance` porte l'acceptation globale, pas la mesure de 4.1. |
| A11 | `capabilities.file.attach` sans preuve ; surfaces image absentes | low | Les routes image hors contrat épinglé n'ont pas à entrer dans `capabilities.json` (frontière de provenance) ; l'entrée `file.attach` doit porter sa preuve. → patch |
| A12 | `.hermes-mesure.env` non documenté | false | La sonde ne lit que l'environnement ; ce fichier est un lanceur local ignoré, pas une source d'identifiants du code. |
| A13 | Sessions et copies laissées sans rétention | low | 20 sessions et 60 copies restent sur le profil de test, sans propriétaire ni rétention documentés. → patch |
| A14 | Le compte de 3 n'est pas prouvé par pièce | false | Le serveur suffixe les copies (`-2`, `-3`) et le bloc contient trois lignes distinctes ; `received` compte chaque référence. |
| A15 | Marqueur `BANANE` publié, pas de contrôle négatif | false | Le marqueur n'est ni contenu du corpus ni secret ; les images sans marqueur servent de contrôle et `visionVerdict` n'accorde `true` qu'au marqueur. |
| A16 | Commande exacte absente de la spec | low | Rejeté : la correction demandée est une modification de la spec de ce build. |
| A17 | Asset déclaré sans lecteur | false | Corrigé : l'asset a été retiré de `pubspec.yaml` ; 4.2 l'ajoutera avec son lecteur. |
| A18 | Journaux de spec vides | low | Rejeté : la correction demandée est une modification de la spec de ce build. |
| L1 | Session non fermée sur exception | false | Corrigé : `_measure` ferme dans `finally` sans masquer le résultat. |
| L2 | Codes RPC de refus classés incertains | false | Aucun code de refus n'est documenté ; classer en incertain est la ligne INCERTAIN de la matrice, et `4018` a été retiré faute de source. |
| L3 | `image.attach_bytes` accepte `attached` sans référence | false | Corrigé : `references.isEmpty` renvoie `missing-reference`. |
| L4 | `referenceStored` circulaire | false | Corrigé : `receiptVerdict` n'accepte que le bloc serveur ou les lignes `@image:`. |
| L5 | `_isAttachmentRow` accepte un échec | false | Corrigé : fonction supprimée avec l'ancien reçu. |
| L6 | Négation testée avant le marqueur | false | Corrigé : marqueur et dénégation donnent `ambiguous` ; la dénégation seule donne `false`. |
| L7 | `attempts` compte les pièces, compteurs qui se recouvrent | false | Corrigé : `attempts` somme les appels et `accepted`/`refused`/`unverified`/`absent` sont exclusifs. |
| L8 | Refus à la répétition >1 publié en `maxCount` | false | Corrigé : ce refus est ambigu et `maxCount` reste toujours `null` en production. |
| L9 | AC1 prouvé par l'écho du prompt | false | Corrigé : le reçu exige une ligne rédigée par le serveur. |
| L10 | AC5 faux, `present` sur un serveur qui refuse tout | false | Corrigé : `hasUsableTransport` exige un reçu accepté ; la sortie 2 est testée. |
| V1 | `_readReceipt` non testé, `true` injecté | false | Corrigé : `receiptVerdict` pure, cinq tests (écho seul, bloc serveur, pièce absente, lignes image, sans ligne). |
| V2 | `maxBytes` jamais comparé aux observations | false | Corrigé : `contracts_test` exige l'égalité avec le maximum accepté sous le plafond refusé et `evidence[].bytes <= maxBytes`. |
| V3 | Liste `unverified` vidable | false | Corrigé : biconditionnelles pour `maxBytes`, `maxCount`, `vision` et `transports`. |
| V4 | `_limit` jamais exercé | false | `contracts_test` valide l'artefact produit (maxBytes, preuves, catégories) ; une agrégation fausse échoue sur le contrat réel. |
| V5 | `referenceStored` satisfait par le prompt | false | Corrigé, même correctif que L4. |
| V6 | Codes RPC de refus jamais consignés | false | Même réfutation que L2 : sans code documenté, l'incertain est la seule sortie honnête. |
| V7 | `proof.attempts` et compteurs qui se recouvrent | false | Corrigé, même correctif que L7. |
| V8 | Garde de profil limité à `isDefault` | low | Le garde rejette le profil par défaut alors que le README parle du « profil personnel » ; `install.profile` reste un rôle, jamais la clé réelle. → patch |

**Entrées groupées et routage**

1. **G1 — `present` sans preuve** (A7) : patch. Le statut d'un transport
   n'est `present` qu'avec au moins un reçu accepté ; sinon `unverified`, et
   l'entrée correspondante rejoint `unverified`.
2. **G2 — protocole sous-documenté** (A8, A9) : patch. Le README consigne la
   variante `data_url`, l'inflation base64, le budget de 15 s par étape et le
   fait que `uploaded` n'est pas la preuve retenue.
3. **G3 — provenance de `capabilities.json`** (A11) : patch. L'entrée
   `file.attach` porte `evidence`, `measuredAt` et `source` ; les routes image
   restent hors de ce fichier.
4. **G4 — README imprécis** (A13, V8) : patch. Propriétaire, rétention et
   nettoyage des sessions et copies ; « profil personnel » devient « profil
   par défaut ».

Aucun `intent_gap` ni `bad_spec` : pas de boucle de revue.

## Design Notes

`contracts/file-limits.json` porte `evidence`, `install` (build, rôle de profil,
`measuredAt`, `finishedAt`), `corpus` (localisation, complétude, catégories),
`transports` (contrat, source, paramètres, statut et `proof` : pièces,
répétitions, essais, reçus), `limits` (`maxBytes`/`maxCount`/`verified`,
`threshold`, `observed`, `evidence`) et `vision`. Une limite non mesurée vaut
`null` + `verified: false` ; `evidence` ne passe à `install-measured` qu'avec
date et build observés. Un transport n'est `present` qu'avec au moins un reçu
accepté.

Le corpus vit dans `_bmad-output/implementation-artifacts/corpus-pieces-jointes/`, ignoré par Git. Le transport image constaté sur le build est mesuré et consigné comme **hors contrat épinglé** ; son adoption par l'app exige un arbitrage d'Alanc avant 4.2.

## Verification

**Commands:**
- `flutter test test/contracts_test.dart` -- expected: succès, assertions de non-invention incluses
- `flutter analyze` -- expected: aucun avertissement nouveau
- `dart run tool/mesure_pieces_jointes.dart --aide` -- expected: usage affiché, aucun accès réseau

**Manual checks (if no CLI):**
- Une entrée par catégorie du corpus ; chaque limite porte sa preuve ou son `null`.
- Aucun corpus, chemin absolu, identifiant ou secret dans le dépôt ni les journaux.
