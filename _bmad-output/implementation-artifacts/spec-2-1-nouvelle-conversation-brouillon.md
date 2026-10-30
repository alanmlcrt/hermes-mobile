---
title: 'Story 2.1 — Préparer une demande sur une nouvelle conversation'
type: 'feature'
created: '2026-10-21'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'b4f6609777781e6ed2f4a723037697b23c8a8aa2'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Après connexion, l'app affiche la liste des profils : aucune conversation n'est prête et rien de ce que tape Alanc n'est conservé.

**Approach:** À l'ouverture normale, `resolveLaunchTarget()` ouvre `/draft/<DraftKey>` sur le profil courant (choix explicite mémorisé, sinon `is_default` fourni par Hermes). Le brouillon est écrit dans SQLite (`outbox_drafts`) par un nouvel `OutboxRepository` à chaque modification, sans aucun appel Hermes.

## Boundaries & Constraints

**Always:**
- Un brouillon « nouvelle conversation » par couple (`ConnectionKey`, `ProfileKey`) : réutilisé à chaque lancement tant qu'il n'est pas soumis. `DraftKey` est un UUID local.
- Texte conservé à l'octet près, sans limite de longueur ni interprétation de `/`. Écritures sérialisées par brouillon, la dernière saisie gagne.
- Profil courant = `snapshot.selectedProfile`, sinon `connection.selectedProfile`. Aucun profil inventé : sans profil, l'accueil affiche le choix du profil existant.
- Bouton d'envoi présent, nommé « Envoyer », désactivé avec une explication lisible (l'envoi arrive après validation du serveur, story 2.2). Lien vers « Mes profils » depuis la conversation.
- Libellés dans `lib/ui/content.dart`, valeurs visuelles via `lib/ui/tokens.dart`, composant de saisie dans la galerie.
- Frontières : les vues n'importent pas `lib/data` ; le contrat `OutboxGateway` vit dans `lib/models`.

**Never:**
- Aucune création de session, aucun envoi, aucun appel réseau nouveau (G1 non validée).
- Ne pas modifier le profil actif global, ni les migrations existantes (ajout seul).
- Pas de Stream ni de statut d'opération (`OperationKey`, `sending`…) : story 2.2.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Ouverture normale | Authentifié, profil courant connu | Redirection `/` → `/draft/<DraftKey>`, champ vide ou brouillon existant | N/A |
| Relance après kill | Brouillon « abc » enregistré | Même `DraftKey`, texte « abc » | N/A |
| Long collage | 200 000 caractères avec emojis et `/cmd` | Texte relu identique depuis SQLite | N/A |
| Aucun profil | Découverte échouée, pas de choix mémorisé | Écran des profils (états existants) | Pas de brouillon créé |
| Saisies rapides | Plusieurs écritures concurrentes | Valeur finale = dernière saisie | Écriture échouée → message `storage.unavailable`, texte gardé à l'écran |

</frozen-after-approval>

## Code Map

- `lib/app/routes.dart` -- `/` choisit connexion ou profils ; à étendre : redirection asynchrone vers `resolveLaunchTarget()`, routes `/draft/:draftKey` et `/profiles`. `refreshListenable: profiles` déjà branché.
- `lib/app/bootstrap.dart` -- ouvre la base unique et construit `ConnectionRepository` ; y construire aussi `OutboxRepository` sur la même `Database`.
- `lib/main.dart` -- `MainApp(gateway:)` ; ajouter l'outbox, disposer avant le gateway (qui ferme la base via `closeStorage`).
- `lib/data/storage/migrations.dart` -- registre `connectionMigrations` (indice+1 = version) : ajouter la migration 3 `outbox_drafts`.
- `lib/data/storage/connection_store.dart`, `test/connection_store_test.dart` -- modèle de store SQLite et de test via `sqflite_common_ffi`.
- `lib/models/connection.dart` -- `ConnectionKey.create()` : génération UUID à extraire pour `DraftKey`.
- `lib/models/connection_gateway.dart`, `lib/features/profiles/*` -- modèle d'interface gateway et de ViewModel/vue à imiter.
- `lib/ui/components/*`, `lib/ui/gallery.dart`, `lib/ui/content.dart` -- composants, galerie, libellés à étendre.
- `test/support/connection_fakes.dart` (`Harness`) -- fakes réseau ; `test/main_app_test.dart`, `test/architecture_imports_test.dart`, `test/visual_literals_test.dart` doivent rester verts.

## Tasks & Acceptance

**Execution:**
- [x] `lib/models/draft.dart` -- `DraftKey` (UUID), `Draft` immuable, `OutboxGateway` (`openNewDraft(ConnectionKey, ProfileKey)`, `draft(DraftKey)`, `saveText(DraftKey, String)`, `dispose`) -- contrat sans Flutter.
- [x] `lib/data/storage/migrations.dart` -- migration `outbox_drafts(draft_key PK, connection_key, profile_key, body, updated_at UTC ISO)` + index unique (connection_key, profile_key) -- ajout seul.
- [x] `lib/data/outbox_repository.dart` -- implémentation SQLite, écritures chaînées par brouillon -- seul auteur des brouillons.
- [x] `lib/app/routes.dart`, `lib/app/bootstrap.dart`, `lib/main.dart` -- `resolveLaunchTarget()` (ordre notification → restauration → accueil ; seul l'accueil existe), injection explicite.
- [x] `lib/features/conversation/draft_view_model.dart`, `draft_view.dart` -- charge le brouillon, enregistre chaque modification, affiche le profil, conserve le texte si l'écriture échoue.
- [x] `lib/ui/components/composer.dart`, `lib/ui/content.dart`, `lib/ui/gallery.dart` -- champ multiligne défilant + bouton d'envoi accessibles, présents dans la galerie.
- [x] `test/outbox_repository_test.dart`, `test/draft_flow_test.dart`, tests existants -- migration 2→3, matrice I/O, relance (réouverture de la base), redirection, absence d'appel de session, sémantique et texte 200 % sans débordement.

**Acceptance Criteria:**
- Given une ouverture normale authentifiée, when l'accueil s'affiche, then la route est `/draft/<DraftKey>` du profil courant et aucune requête autre que celles de l'Epic 1 n'est émise.
- Given un brouillon en cours, when l'app passe en arrière-plan puis revient, then l'écran et le texte sont inchangés.
- Given le lecteur d'écran et un texte agrandi 200 %, when Alanc parcourt l'écran, then le champ (« Votre demande ») et le bouton (« Envoyer », désactivé avec explication) sont annoncés et utilisables sans débordement.

## Implementation Notes

- `randomUuid()` extrait dans `lib/models/connection.dart`, partagé par `ConnectionKey.create()` et `DraftKey.create()`.
- `openNewDraft` : `INSERT … ON CONFLICT IGNORE` puis relecture ; l'index unique départage les ouvertures concurrentes (la redirection peut être réévaluée à chaque snapshot).
- `saveText` : chaîne de futures par `DraftKey` (une écriture échouée ne casse pas la chaîne) ; toute erreur remonte en `AppError('storage.unavailable')`. `dispose` attend les écritures en cours ; `main.dart` dispose l'outbox avant le gateway qui ferme la base.
- Redirection : seul `/` passe par `resolveLaunchTarget()` (async) ; `/draft/:draftKey` et `/profiles` ne redirigent jamais, donc une perte d'authentification ne chasse pas l'utilisateur de son brouillon. « Mes profils » est poussé (`push`) pour garder le retour.
- Le ViewModel du brouillon est possédé par l'état de la page (`DraftView(create:)`), pas par le rendu : un redessin ne recharge ni ne réécrit rien.
- Bouton « Envoyer » : `MergeSemantics` + `hint` pour que TalkBack annonce l'explication sur le bouton lui-même ; le texte visible est exclu de la sémantique pour éviter le doublon.
- Tests existants adaptés : `connection_flow_test` (après connexion, accueil = brouillon puis « Mes profils »), `gallery_test` (4 composants), `connection_store_test` (version 3), `MainApp(outbox:)`.
- Tests widget : la relance est simulée par un nouveau `ConnectionRepository` sur le stockage d'une connexion faite (réutiliser un repository déjà connecté bloque `restore()` dans la zone de test).

## Spec Change Log

## Review Triage Log

| # | Source | Constat | Verdict | Preuve / route |
|---|--------|---------|---------|----------------|
| 1 | blind, edge | Chargement échoué : composer vide affiché, la première frappe écrase le texte stocké | high | `_load` laisse `draft` nul et `loading` faux, `if (!vm.loading) Composer` → `saveText` remplace `body`. patch |
| 2 | blind, edge, gap | Clé `/draft` inconnue : composer actif, chaque frappe échoue en `storage.unavailable` trompeur | low | Même cause que #1 (composer sans brouillon chargé) ; corrigé avec #1. patch |
| 3 | blind, edge | `/draft` et `/profiles` restent affichés après perte d'authentification | medium | `redirect` ne teste que `/` ; `authenticated: false` n'arrive que sur refus d'auth ou changement de serveur (l. 127, 155, 506). patch |
| 4 | blind, edge | Changer de profil depuis « Mes profils » ne change pas le brouillon | low | Le fil reste correctement étiqueté ; choisir le profil de la nouvelle conversation est la story 2.5. defer |
| 5 | blind, edge | Choix mémorisé utilisé sans vérifier qu'il existe encore côté Hermes | low | Conforme à la règle Always ; profil supprimé côté serveur = cas rare, correctif = garde supplémentaire. rejeté |
| 6 | blind, edge | `resolveLaunchTarget` avale l'échec d'ouverture | low | Repli sur l'écran des profils, panne SQLite rare, signalement = nouvel état. rejeté (test ajouté via #10) |
| 7 | blind | Erreurs non homogènes dans `openNewDraft`/`draft` | false | Les deux appelants (`resolveLaunchTarget`, `_load`) attrapent toute exception. rejeté |
| 8 | blind, edge, gap | Pas de coalescence des écritures ; `_writes` jamais purgé | low | Une entrée par brouillon ; une écriture de 200 ko reste brève. rejeté |
| 9 | blind | Brouillons orphelins après changement de serveur | false | `confirmOrigin` conserve la `ConnectionKey` (l. 129). rejeté |
| 10 | blind | `updated_at` jamais lu | false | Colonne exigée par la spec. rejeté |
| 11 | blind | Fichiers de test non formatés | low | Correction directe par `dart format`. patch |
| 12 | blind | `Composer` sans `onSend` ni `disabledReason` possible | low | Aucun appelant dans ce cas. rejeté |
| 13 | edge | `saveText` après `dispose` sur base fermée | false | `MainApp` dispose l'outbox puis le gateway ; plus aucune frappe après. rejeté |
| 14 | edge | `DraftView` réutilisé avec une autre clé | false | go_router crée une page par emplacement, donc un nouvel état. rejeté |
| 15 | gap | Effacement du bandeau d'erreur après une écriture réussie non testé | medium | Gap vérifié par le relecteur. patch |
| 16 | gap | Repli quand `openNewDraft` échoue non testé | medium | Gap vérifié. patch |
| 17 | gap | Repli sur le choix mémorisé non épinglé | medium | Gap vérifié. patch |
| 18 | gap | Vidage des écritures en cours au `dispose` non observé ; ordre dans `main.dart` non testé | medium | Test dépôt : patch ; ordre `main.dart` : defer |

## Verification

**Commands:**
- `fvm flutter analyze` -- expected: aucun problème
- `fvm flutter test` -- expected: tous verts
- `fvm flutter build apk --debug` -- expected: build réussi

**Manual checks (if no CLI):**
- Pixel 8 Pro (APK release) : taper, passer en arrière-plan, revenir ; tuer l'app, relancer connecté → texte intact ; TalkBack et texte 200 %.
