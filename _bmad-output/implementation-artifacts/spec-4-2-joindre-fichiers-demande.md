---
title: 'Story 4.2 - Joindre des fichiers à une demande'
type: 'feature'
created: '2026-10-24'
status: 'done'
baseline_commit: '2460013e60472d7b913304cc8e719010bdbf863c'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/contracts/file-limits.json'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Le brouillon ne connaît aucune pièce jointe : ni stockage privé, ni sélection, ni liste, ni retrait. 4.1 a mesuré limites et transports, mais l'app ne peut encore rien joindre, et le « + » du 23 octobre était retiré faute de service établi.

**Approach:** Donner au brouillon une liste de pièces dont les octets sont copiés dans l'espace privé `attachments/<DraftKey>/`, alimentée par une feuille « Photos / Fichiers » ouverte depuis le composer, validée contre `contracts/file-limits.json`, affichée avec aperçu image ou nom, type et taille, et retirable pièce par pièce. Les pièces survivent au redémarrage. Leur téléversement reste à 4.3.

## Boundaries & Constraints

**Always:** Copier les octets dans l'espace privé avant d'afficher une pièce. Lire les limites dans `contracts/file-limits.json`, jamais en dur. Refuser une pièce hors limite avec sa raison. Afficher les limites dans la feuille de sélection. État `selected` seulement ; envoi, reçu et échec appartiennent à 4.3. Nom accessible sur chaque action, cible ≥ 44 px, libellés sur les tokens, état jamais par la seule couleur. Conserver brouillon et pièces en cas d'erreur.

**Never:** Modifier `contracts/`. Transmettre un chemin du téléphone au serveur. Inventer une limite ou présenter un format non mesuré comme vérifié côté serveur. Exception de sélection locale validée : accepter JPEG en plus de PNG, sous la borne `limits.image.maxBytes` du contrat ; la réception JPEG reste à vérifier avant son activation dans 4.3. Utiliser `revision` pour les pièces. Toucher au pipeline `send` hors blocage. Créer un second fichier SQLite. Exécuter un fichier. Nommer un fichier sur disque avec le nom fourni par le téléphone.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| ACCEPTÉE | Fichier d'un type mesuré ou JPEG autorisé localement, sous `maxBytes` de sa catégorie | Copie privée, ligne listée, aperçu si image | Volume réel consigné ; sélection locale distincte d'une réception serveur |
| REFUS TAILLE | Octets > `maxBytes` de sa catégorie | Aucune copie, raison nommant la limite | Brouillon intact |
| REFUS TYPE | Type absent des types mesurés et différent de `image/jpeg` | Aucune copie, raison nommant le type | Aucune promesse de prise en charge |
| RETRAIT | Appui sur « Retirer » | Ligne et copie supprimées | Suppression échouée : ligne conservée, erreur affichée |
| REDÉMARRAGE | App tuée puis brouillon rouvert | Mêmes pièces, mêmes libellés | Copie absente : pièce signalée, jamais rechargée depuis l'extérieur |
| PERMISSION | Sélection refusée ou échouée | Aucune pièce | Raison expliquée, brouillon intact |
| ENVOI AVEC PIÈCES | Brouillon à pièces, tentative d'envoi depuis l'interface ou le view model | Envoi bloqué avec raison jusqu'à 4.3 | Aucun texte envoyé seul, aucune pièce perdue, aucun texte effacé |

</frozen-after-approval>

## Décisions validées — 24 octobre 2026

- **Images :** PNG et JPEG (`image/png`, `image/jpeg`, extensions `.png`, `.jpg`, `.jpeg`) acceptés dans le brouillon. JPEG est autorisé par Alanc pour la sélection locale ; seul PNG a une preuve de réception dans le contrat actuel. Ne pas étendre implicitement cette décision à HEIC ou à tous les types `image/*`. Vérifier JPEG avant d'activer son téléversement dans 4.3.
- **Envoi avant 4.3 :** bloquer tout envoi d'un brouillon portant des pièces avec une raison explicite ; ne jamais envoyer son texte seul.
- **Nombre de pièces :** aucun plafond imposé et aucune ligne de limite de nombre dans la feuille tant que `maxCount` est `null`.
- **Longueur :** conserver la spec complète malgré le dépassement du seuil de 1 600 tokens.

## Code Map

- `contracts/file-limits.json` — source unique : `limits.<catégorie>.maxBytes`, `maxCount` (`null`), `observed.mediaTypes`. Lecture seule.
- `lib/models/draft.dart` l.15-34 `Draft` ; l.84-115 `OutboxGateway` : y déclarer les méthodes de pièces, seule surface vue par `lib/features`.
- `lib/models/attachment.dart` (nouveau) — `Attachment`, `AttachmentState`, `AttachmentCategory`, `PickedFile`, `AttachmentPicker`.
- `lib/data/storage/migrations.dart` l.127-137 — ajouter la migration 11 en fin de liste ; conventions `*_key TEXT PRIMARY KEY`, `COLLATE BINARY`, `created_at` ISO-8601, aucune FK déclarée.
- `lib/data/storage/database.dart` l.15 — version déduite de la liste, rien à changer.
- `lib/data/outbox_repository.dart` l.236-289 (`openNewDraft`, `openContinuation`), l.292-355 (`reassignNewDraft`, suppression du brouillon cible l.319-329), l.358-385 (`draft`), l.922-929 (`_draft`). Ne pas modifier l.535-698 (`send`) ni l.599 (`onStep('attachments')`).
- `lib/data/file_limits.dart` (nouveau) — lecteur de l'asset, `categoryOf`, `maxBytesFor`, `refusal` ; associer aussi `image/jpeg` à la catégorie image pour la sélection locale, sans modifier les types observés du contrat.
- `lib/data/storage/attachment_files.dart` (nouveau) — `attachments/<DraftKey>/`, copie, suppression, nom de fichier = clé locale.
- `lib/data/attachment_picker.dart` (nouveau) — `file_picker` (galerie et documents), erreurs traduites en `AppError`.
- `lib/features/conversation/draft_view_model.dart` l.138-160 (`blockedReason`), l.176-179 (`send`) — pièces, ajout, retrait, blocage.
- `lib/ui/components/composer.dart` l.37-107 — slot d'action facultatif à gauche, bouton 44 px ; l.109-115, idiome de région live à réutiliser.
- `lib/ui/components/attachment_list.dart` (nouveau) — liste et tuile : aperçu, nom, type, taille, « Retirer ».
- `lib/features/conversation/draft_view.dart` l.136-211 — insérer la liste avant `Composer` (l.188) et passer l'action « Joindre ».
- `lib/ui/content.dart` l.5+ et l.240+ (`error(code)`) — libellés FR, refus, permission.
- `lib/ui/gallery.dart` l.149-192 et `test/gallery_test.dart` l.462-470, 507-520 — section pièces jointes et comptes exacts à mettre à jour.
- `pubspec.yaml` l.10-34 — `file_picker` déjà présent l.23, ajouter `path_provider: 2.1.6` (déjà transitif), déclarer l'asset `contracts/file-limits.json`.
- Contraintes : `test/architecture_imports_test.dart` l.14-41 (features ↛ data), `test/visual_literals_test.dart` (tokens seuls), `test/outbox_repository_test.dart` l.62-88 (persistance/redémarrage), `test/support/connection_fakes.dart` l.248-372 (`MemoryOutbox`).

## Tasks & Acceptance

**Execution:**
- [x] `lib/models/attachment.dart` — modèle, catégories, interfaces de sélection — sépare features et data
- [x] `lib/data/storage/migrations.dart` — table `outbox_attachments` (clé du brouillon, clé locale, nom, type, octets, état, ordre, date) — rend les pièces durables
- [x] `lib/data/storage/attachment_files.dart` — répertoire privé par brouillon, copie et suppression — octets hors base, nom disque non fourni par le téléphone
- [x] `lib/data/file_limits.dart` + `pubspec.yaml` — lecteur du contrat et asset — aucune limite codée en dur
- [x] `lib/data/attachment_picker.dart` — sélection photos et fichiers — traduit refus et erreurs
- [x] `lib/data/outbox_repository.dart` + `lib/models/draft.dart` — ajout, retrait, lecture des pièces et nettoyage dans `reassignNewDraft` — propriétaire unique du brouillon
- [x] `lib/features/conversation/draft_view_model.dart` — état des pièces, ajout, retrait, raison de blocage — un seul point d'état
- [x] `lib/ui/components/attachment_list.dart`, `composer.dart`, `draft_view.dart`, `content.dart` — feuille de sélection avec limites, liste accessible, retrait nommé, raison de refus annoncée
- [x] `lib/ui/gallery.dart` + `test/gallery_test.dart` — états représentatifs, comptes exacts
- [x] `test/file_limits_test.dart`, `test/attachment_store_test.dart`, `test/attachment_flow_test.dart` — couvre les sept lignes de la matrice

**Acceptance Criteria:**
- Given un brouillon et une image choisie, when elle est ajoutée, then ses octets sont sous `attachments/<DraftKey>/` et une ligne l'affiche avec aperçu.
- Given une image PNG ou JPEG (`.jpg` ou `.jpeg`) sous la borne image du contrat, when elle est ajoutée, then elle est acceptée localement sans être présentée comme reçue par Hermes.
- Given un fichier non image, when il est ajouté, then son nom, son type et sa taille s'affichent.
- Given une pièce listée, when Alanc la retire, then la ligne disparaît et sa copie n'existe plus.
- Given la feuille de sélection ouverte, when Alanc choisit un fichier hors limite, then les limites sont visibles avant l'envoi et le refus nomme la raison.
- Given l'app tuée puis relancée, when le brouillon est rouvert, then ses pièces sont là, dans le même ordre.
- Given une sélection refusée, when elle échoue, then la raison est expliquée et « Joindre » comme « Retirer » portent un nom accessible.
- Given un brouillon portant des pièces, when un envoi est tenté, then aucun prompt ni téléversement ne part, la raison du blocage est affichée et le texte comme les pièces sont conservés.
- Given au moins quatre pièces valides, when elles sont ajoutées, then aucune n'est refusée pour leur nombre et leur ordre est conservé après redémarrage.

## Implementation Notes

- Alanc a demandé le 24 octobre d'implémenter 4.2 avant 4.3, avec les décisions validées ci-dessus. Les modifications de suivi Git et la spec 4.3 déjà présentes font partie de cette session ; les préserver. Le dépôt est partagé : ne pas annuler le travail des autres.
- Intégration visuelle : appliquer le skill `.agents/skills/ui-ux-pro-max/SKILL.md` et sa checklist `references/pro-rules.md`, en conservant les tokens et composants existants.
- Implémentation : migration 11, modèles et interfaces de pièces, lecteur du contrat embarqué, copies privées par clés locales, sélecteurs Photos/Fichiers, liste accessible et blocage repository/viewmodel avant tout RPC. Aucun contrat modifié.
- Revue à trois couches terminée ; actualisation sur événements du dépôt, retrait récupérable, nettoyage de copie partielle et tests des chemins réels/permissions ajoutés. 393 tests réussis (17 ignorés), analyse sans problème, APK debug compilé. Preuves et audit de matrice : [verification.md](story-4-2-verification/verification.md). Sélecteur natif sur appareil réel non vérifié.

## Review Triage Log

| ID | Verdict | Preuve et décision |
|---|---|---|
| B1 | medium | `_onOutbox` ne relit pas les pièces ; une sélection finissant sur une ancienne page peut laisser la nouvelle page obsolète. Correction locale : rafraîchir la liste sur événement du brouillon. |
| B2 | medium | Le retrait détruit les octets avant l'écriture SQLite ; un échec de suppression en base conserve une ligne sans copie. Correction locale avec conservation récupérable et test d'échec SQLite. |
| B3 | low | Un second échec de fermeture saute le nettoyage de la copie partielle ; `finally` doit garantir sa tentative. Correction directe. |
| B4 | low | Un arrêt brutal entre copie et insertion peut laisser un fichier orphelin. Rejet : incident peu fréquent, collecte au démarrage et protocole de fichiers temporaires dépassent une correction directe ; la ligne n'est jamais présentée comme sélectionnée avant insertion. |
| B5 | low | Le cache privé du sélecteur peut conserver une copie distincte. Rejet : nettoyage global de dépendance complexe et risqué pour les sélections concurrentes ; le retrait demandé concerne la copie gérée sous `attachments/<DraftKey>`. Aucun octet n'est stocké hors espace privé par ce code. |
| B6 | false | La sélection locale valide le type déclaré ; aucune inspection de signature n'est promise. Le repli après échec de décodage est explicitement prévu et couvert. Aucun fichier n'est exécuté ou présenté comme reçu. |
| B7 | low | La liste construit toutes les tuiles. Rejet : ralentissement limité aux collections exceptionnellement nombreuses ; décodage borné à 192 px, virtualisation non triviale. |
| B8 | low | Le helper de captures référence un SDK absolu local. Correction directe : résoudre la police depuis le SDK actif. |
| B9 | low | La spec préparatoire 4.3 décrit encore l'absence de 4.2. Actualiser son contexte de dépendance après livraison de 4.2 ; aucun changement au contrat utilisateur 4.2. |
| B10 | medium | Le picker réel n'est pas exécuté dans les tests, contrairement au faux injecté ; vérifier sa frontière plateforme (refus et annulation) sans prétendre à une validation sur appareil réel. Groupé avec V2. |
| E1 | low | Même nettoyage sauté que B3, constat confirmé par l'ordre des `await`. Correction directe commune. |
| E2 | medium | Même perte de copie que B2 si SQLite échoue après suppression des octets. Correction commune. |
| V1 | medium | Lacune pré-vérifiée : seuls les succès en mémoire sont testés. Ajouter une copie depuis chemin, supprimer la source et relire après redémarrage. |
| V2 | medium | Lacune pré-vérifiée : `FakePicker` injecte déjà `attachment.permission`. Tester la traduction réelle d'une erreur plateforme refusée. |

Les corrections retenues n'ajoutent aucune interface publique et portent sur des états démontrés ; routage `patch`. Aucun `intent_gap` ni `bad_spec`.

## Design Notes

Les octets vivent hors SQLite, sous `attachments/<DraftKey>/<AttachmentKey>` ; le nom affiché reste en base. Les limites affichées sont calculées depuis le contrat (Mo arrondis), sans ligne de nombre tant que `maxCount` est `null`. Les aperçus images passent par `Image.file` avec une largeur de cache bornée et un repli nom/type/taille si le décodage échoue.

## Verification

**Commands:**
- `flutter test` -- expected: succès, comptes de galerie à jour
- `flutter analyze` -- expected: aucun avertissement nouveau

**Manual checks (if no CLI):**
- Ajouter un PNG, un JPEG `.jpg`, un JPEG `.jpeg`, un PDF et un fichier trop lourd : aperçu, nom/type/taille, refus motivé.
- Retirer une pièce puis rouvrir le brouillon après redémarrage : la pièce retirée ne revient pas.
- Ajouter au moins quatre pièces puis tenter l'envoi : aucun plafond de nombre, blocage expliqué, texte et pièces conservés.
