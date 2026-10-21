---
title: 'Story 2.6 — Retrouver et reprendre mes conversations par profil'
type: 'feature'
created: '2026-10-21'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '064ed6894a55ae43d18faff2ea0f7c67177a5e4b'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/recherche-contrat-epic-2.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Une conversation envoyée disparaît de l'app dès qu'Alanc en commence une autre ou relance : aucune liste, aucune route pour la rouvrir et poursuivre.

**Approach:** Un écran « Conversations » liste les sessions du profil via `session.list {profile}` ; ouvrir une ligne mène à `/c/<ConnectionKey>/<ProfileKey>/<SessionKey>` (clé stockée), qui affiche le fil par la resynchronisation de 2.4 et permet de poursuivre avec un brouillon propre à cette conversation. « Nouvelle conversation » ramène à l'accueil.

## Boundaries & Constraints

**Always:**
- Lecture distante par `ConversationRepository` (projection distante) : liste `session.list {profile, limit}` dans l'ordre fourni par le serveur ; états chargement, vide (« Aucune conversation pour ce profil ») et erreur distincts ; actualisation manuelle. Ligne : titre (ou aperçu, sinon libellé générique), date locale lisible, nombre de messages ; noms accessibles.
- Accès : bouton « Conversations » dans l'écran de conversation, sur le profil de cette conversation (ou du brouillon neuf) ; le profil listé est affiché.
- `/c/<ConnectionKey>/<ProfileKey>/<SessionKey>` : `ConnectionKey` doit être la connexion courante, sinon retour à l'accueil. `OutboxRepository` fournit le brouillon de suite de cette conversation (get-or-create par (connexion, profil, `stored_session_id`), index unique, migration en ajout seul) ; l'écran réutilise la vue de conversation (fil + composer) et déclenche la resynchronisation 2.4 (snapshot à la première ouverture). Envoyer y passe par le pipeline 2.2 sur cette session.
- Cloisonnement : toute clé (liste, projection, brouillon) inclut connexion + profil ; identifiants comparés en respectant la casse ; aucune donnée d'un profil affichée sous un autre.
- Accueil : `openNewDraft` ne rend plus que des brouillons sans session (le texte de suite d'une conversation reste sur son brouillon, retrouvable via la liste). « Nouvelle conversation » → `/` → nouveau brouillon, sans fil vide enregistré.
- Changement d'URL du serveur : `ConnectionKey` inchangée, liste et brouillons restent rattachés.
- Libellés dans `Content`, tokens, composant de ligne d'historique dans la galerie (états chargement/vide/erreur/liste).

**Never:**
- Pas de suppression, d'archivage, de renommage, ni de recherche ; pas de pagination au-delà du `limit` par défaut.
- Pas de nouvelle sémantique de reprise : réutiliser `resync` de 2.4.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Liste | `session.list` 3 lignes | 3 lignes dans l'ordre serveur | N/A |
| Vide | `sessions: []` | Message « historique vide » | N/A |
| Erreur | erreur RPC / hors ligne | Message d'erreur distinct + Réessayer | Aucune liste périmée présentée comme à jour |
| Ouvrir | ligne `abc` | `/c/<conn>/<profil>/abc`, fil resynchronisé | Échec reprise : message, brouillon intact |
| Poursuivre | texte saisi dans `/c/...` | Envoi sur la session `abc`, aucune `session.create` | N/A |
| IDs voisins | profils A et B, sessions `Abc` et `abc` | Fils et brouillons séparés | N/A |
| Autre connexion | `/c/<autre>/...` | Retour à l'accueil | N/A |
| Nouvelle | « Nouvelle conversation » depuis `/c/...` | Brouillon neuf du profil, aucune session | N/A |

</frozen-after-approval>

## Code Map

- `lib/data/conversation_repository.dart` -- projection, `resync` (2.4) : ajouter la liste.
- `lib/data/hermes_adapter.dart` (`HermesRpc`) -- décodage `session.list` (`sessions[]` : `id`, `title`, `preview`, `started_at`, `message_count`).
- `lib/data/outbox_repository.dart` -- `openNewDraft` (filtre à resserrer), brouillons avec `stored_session_id`, `ensureSession`/`resume`.
- `lib/data/storage/migrations.dart` -- index unique (connexion, profil, `stored_session_id`).
- `lib/app/routes.dart` -- routes typées, `resolveLaunchTarget`, `/draft/:draftKey`, garde d'authentification.
- `lib/features/conversation/*` -- vue/ViewModel de conversation à réutiliser pour `/c/...`.
- `lib/ui/components/*`, `lib/ui/content.dart`, `lib/ui/gallery.dart` ; `contracts/fixtures/` (`session-list.json` synthétique).
- `test/support/connection_fakes.dart`, tests de flux existants.

## Tasks & Acceptance

**Execution:**
- [x] `lib/data/hermes_adapter.dart`, `contracts/fixtures/session-list*.json` -- décodage + fixtures.
- [x] `lib/data/conversation_repository.dart`, `lib/models/*` -- liste par profil avec états.
- [x] `lib/data/storage/migrations.dart`, `lib/data/outbox_repository.dart` -- brouillon de suite par conversation, `openNewDraft` resserré.
- [x] `lib/app/routes.dart`, `lib/features/history/*`, `lib/features/conversation/*` -- écran Conversations, route `/c/...`, « Nouvelle conversation ».
- [x] `lib/ui/*` -- ligne d'historique accessible + galerie.
- [x] `test/*` -- matrice I/O, migration, sémantique à 200 %.

**Acceptance Criteria:**
- Given deux profils, when Alanc ouvre l'historique de l'un puis de l'autre, then chaque liste ne contient que les sessions de son profil et le profil listé est annoncé.

## Implementation Notes

## Spec Change Log

## Review Triage Log

| # | Source | Constat | Verdict | Preuve / route |
|---|--------|---------|---------|----------------|
| 1 | blind, edge, gap | Index unique v7 sans dédoublonnage : base illisible si doublons | medium | Doublons improbables (une session par brouillon) mais impact bloquant ; correction bornée. patch |
| 2 | blind, gap | `resumeFailed` ne notifie pas ; drapeau jamais effacé à la fermeture | medium | `_failed.add` sans `_changes.add`. patch |
| 3 | blind, edge, gap | Double décodage du chemin `/c/`, `connection!` au toucher | low | Lien malformé ou déconnexion pendant l'écran. patch (correction directe) |
| 4 | edge | Sélecteur de profil sur un brouillon de suite | maybe-false | 2.5 rend une conversation commencée en lecture seule ; à vérifier. patch (vérification) |
| 5 | blind, edge | `message_count` décimal, `started_at` hors limites | low | Une ligne invalide fait échouer toute la liste. patch |
| 6 | blind, edge | Liste tronquée à 200 sans signal ; lignes non bornées à 200 % | low | Correction simple. patch |
| 7 | gap | `resumeFailed` réel, réponses désordonnées, accès non authentifié, profil demandé inconnu, échec d'ouverture `/c/` : non testés | medium | Gaps vérifiés. patch |
| 8 | blind, edge | Écran d'historique insensible aux changements de connexion ; liste d'une autre connexion pendant l'appel | low | Déconnexion → redirection ; actualisation manuelle. rejeté |
| 9 | edge | `openNewDraft` sans tri | false | Index unique partiel : un seul brouillon neuf par couple. rejeté |
| 10 | blind, edge | Texte de suite visible seulement via l'historique | low | Choix de la spec (FR2 : accueil = nouvelle conversation). rejeté |
| 11 | blind | Format de date figé, `/history/<profil inconnu>` | low | Français 24 h voulu ; profil inconnu = liste vide ou erreur serveur. rejeté |

## Verification

**Commands:**
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat analyze` -- expected: aucun problème
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat test` -- expected: tous verts
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat build apk --debug` -- expected: build réussi
