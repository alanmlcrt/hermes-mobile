---
title: 'Story 2.5 — Choisir le profil de ma nouvelle conversation'
type: 'feature'
created: '2026-10-21'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'f863b25e1c1a313a5f80360e5c21e98a07dee210'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** La nouvelle conversation part toujours sur le profil courant ; choisir un autre profil dans « Mes profils » ne change pas le brouillon ouvert, et rien n'indique clairement à quel agent la demande ira.

**Approach:** Un sélecteur de profil dans l'écran de nouvelle conversation (et le retour de « Mes profils » ouvert depuis ce brouillon) rattache le brouillon au profil choisi, enregistre ce choix explicite et l'affiche ; une conversation déjà commencée garde son profil.

## Boundaries & Constraints

**Always:**
- Brouillon neuf (`stored_session_id` nul) : choisir le profil P rattache son texte à P dans une transaction `OutboxRepository` (seul auteur). Si P a déjà un brouillon neuf : vide → supprimé puis rattachement ; non vide → les deux brouillons échangent leur profil (aucun texte perdu). La `DraftKey` affichée reste celle du texte en cours ; la route reste `/draft/<DraftKey>`.
- Le choix est aussi enregistré comme choix explicite via `ConnectionGateway.selectProfile` (local au téléphone, jamais le profil actif global de Hermes) ; il sert d'accueil à la relance quand Hermes ne fournit pas de défaut ou que la découverte échoue. Aucun profil inventé.
- Conversation commencée (`stored_session_id` présent) : profil affiché en lecture seule ; changer la sélection (sélecteur absent, « Mes profils ») n'affecte que le prochain fil.
- Sélecteur : bouton libellé « Profil : <nom> » qui ouvre la liste des profils (réutiliser `ProfileChoice`), désactivé pendant un envoi en cours ; profil actif identifiable sans couleur seule ; noms accessibles ; utilisable à 200 %.
- Depuis un brouillon neuf, « Mes profils » renvoie le profil choisi à l'écran du brouillon, qui le rattache comme ci-dessus.

**Never:**
- Pas d'appel réseau nouveau ; pas de modification du profil d'une session existante ; pas d'écran d'administration des profils.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Changer de profil | brouillon neuf « abc » sur A, choix B (sans brouillon) | Brouillon « abc » sur B, libellé B, choix B enregistré | N/A |
| Cible vide | B a un brouillon neuf vide | Brouillon vide supprimé, « abc » passe sur B | N/A |
| Cible non vide | B a un brouillon neuf « xyz » | « abc » sur B, « xyz » sur A | N/A |
| Conversation commencée | brouillon avec session sur A, choix B | Profil A inchangé ; prochain fil sur B | N/A |
| Relance sans défaut | choix B enregistré, Hermes sans `is_default` ou découverte en échec | Accueil sur le brouillon de B | N/A |
| Écriture échouée | transaction en erreur | Brouillon et profil inchangés | `storage.unavailable` affiché |

</frozen-after-approval>

## Code Map

- `lib/data/outbox_repository.dart` -- `openNewDraft`, index unique partiel « nouveau brouillon » (`stored_session_id IS NULL`) : ajouter le rattachement transactionnel.
- `lib/models/draft.dart` -- contrat `OutboxGateway` à étendre.
- `lib/features/conversation/draft_view.dart`, `draft_view_model.dart` -- écran du brouillon, état d'envoi, libellé de profil existant (`Content.draftProfile`).
- `lib/features/profiles/profiles_view.dart`, `lib/app/routes.dart` (`/profiles` poussé depuis le brouillon) -- retour du profil choisi.
- `lib/data/connection_repository.dart` `selectProfile`, `_loadProfiles` (choix explicite prioritaire puis `is_default`) ; `resolveLaunchTarget` dans `lib/app/routes.dart`.
- `lib/ui/components/profile_choice.dart`, `lib/ui/content.dart`, `lib/ui/gallery.dart` -- composant à réutiliser, libellés, galerie.
- `test/support/connection_fakes.dart` (`MemoryOutbox`), `test/draft_flow_test.dart` -- fakes et tests existants.

## Tasks & Acceptance

**Execution:**
- [x] `lib/models/draft.dart`, `lib/data/outbox_repository.dart` -- `reassignNewDraft(DraftKey, ProfileKey)` transactionnel (matrice).
- [x] `lib/features/conversation/*`, `lib/ui/*` -- sélecteur accessible, lecture seule pour une conversation commencée.
- [x] `lib/app/routes.dart`, `lib/features/profiles/*` -- retour de « Mes profils » vers le brouillon neuf.
- [x] `test/*` -- matrice I/O, relance avec choix enregistré, sémantique à 200 %.

**Acceptance Criteria:**
- Given un brouillon neuf, when Alanc choisit un autre profil au lecteur d'écran, then le nouveau profil est annoncé et le texte saisi est intact.

## Implementation Notes

## Spec Change Log

## Review Triage Log

| # | Source | Constat | Verdict | Preuve / route |
|---|--------|---------|---------|----------------|
| 1 | blind, edge, gap | Rattachement sans effet (cible en envoi, session existante) mais choix enregistré, sans message | medium | `return` silencieux l. 106/118 puis `gateway.selectProfile`. patch |
| 2 | blind, edge | Écritures en attente de la cible non attendues | medium | Seules celles de la source sont attendues. patch |
| 3 | blind, edge | `mounted` absent après attente ; `onPicked` après échec ; double retour | medium | Retour possible sur la mauvaise route. patch |
| 4 | blind, edge | Écouteur du routeur lit `router` avant affectation | low | `late final` assigné après `addListener`. patch (correction directe) |
| 5 | blind | Bouton sans indication qu'il ouvre un choix | low | Accessibilité. patch |
| 6 | gap | Routes réelles, cible occupée, rollback d'échange, échec en mode choix : non testés | medium | Gaps vérifiés. patch |
| 7 | edge | Opérations de la cible gardent l'ancien `profile_key` après échange | low | Colonne non relue pour un brouillon neuf (le rapprochement joint sur le brouillon). rejeté |
| 8 | blind | `extra` perdu en restauration ; feuille sans état vide | low | Cas rares ; le sélecteur ne s'ouvre qu'avec des profils chargés. rejeté |

## Verification

**Commands:**
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat analyze` -- expected: aucun problème
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat test` -- expected: tous verts
- `%USERPROFILE%\fvm\versions\3.47.7\bin\flutter.bat build apk --debug` -- expected: build réussi
