---
title: '7.2 — Renommer une conversation'
type: 'feature'
created: '2026-10-30'
updated: '2026-10-31'
status: 'done'
delivery: 'preparation-only'
story_validated: false
route: 'dispatch'
baseline_commit: '6da4606b33526e41ce984b6b1208d0be52c27481'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/specs/spec-7-2-renommer-conversation/implementation.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Alanc veut reconnaître une conversation dans son historique en lui donnant un titre parlant, partagé avec Hermes et ses autres clients.

**Approche :** proposer « Renommer » sur la conversation, transmettre le nouveau titre par la méthode vérifiée et ne l'afficher qu'après confirmation distante. Conserver la saisie en cas d'échec et réconcilier les titres lors d'une actualisation.

## Boundaries & Constraints

**Toujours :** cibler ConnectionKey + ProfileKey + SessionKey, identifiants opaques sensibles à la casse. Étendre l'adaptateur et les repositories existants après intégration de leur base. Sérialiser les mutations par session, conserver les saisies, distinguer refus, absence de méthode et résultat incertain. Normaliser seulement les espaces externes du titre pour comparer et envoyer. Utiliser les composants, tokens et frontières vue/ViewModel/repository existants.

**Jamais :** créer un fil pour renommer une ancienne conversation, remplacer la fonction distante par un titre local, rejouer automatiquement une mutation incertaine ou déclarer la compatibilité serveur à partir de simulations. Ne pas modifier l'autre checkout ni ses essais. Ne pas fusionner automatiquement la base epic 6.

## I/O & Edge-Case Matrix

| Scénario | Entrée / état | Résultat attendu | Erreur |
|---|---|---|---|
| Validation | Titre non vide, différent | Une requête sur la cible exacte ; affichage après confirmation | Ancien titre et saisie conservés |
| Sans mutation | Titre vide, espaces, identique ou annulation | Aucun appel | Validation compréhensible |
| Concurrence | Double validation, changement de profil ou réponse ancienne | Une mutation en cours ; aucune projection d'une autre cible modifiée | Résultat rattaché à sa clé d'origine |
| Réponse perdue | Timeout après envoi | État incertain et actualisation proposée | Aucun rejeu automatique |
| Capacité absente | Absence explicitement vérifiée | Action indisponible expliquée | Aucun contournement |
| Confirmation différée | Réponse documentaire `pending` | Aucun succès définitif présumé | Qualification réelle préalable requise |

## Décisions (2026-10-31)

- `session.title` non qualifiée : implémenter maintenant contre le contrat documentaire, avec tests simulés. La story est livrée « préparation seulement » et n'est pas déclarée validée tant que la qualification réelle (sonde 7.1 sur installation) n'est pas faite.
- Spec conservée entière (~2 000 tokens) malgré le dépassement de la cible.

</frozen-after-approval>

## Code Map

- `contracts/epic-7/methods.json` : `SessionTitleParams {session_id (requis), profile?, title?}` → `SessionTitleResult {title (requis), session_key?, pending?}`. `verification.md` : identifiant runtime attendu, non vérifié.
- `lib/models/connection_gateway.dart` : `ConnectionGateway.call` lève `RpcError(code)` (refus ; -32601 = méthode absente), `AppError('transport.offline')` (rien écrit) ou `AppError('rpc.uncertain')` (envoyé, sans réponse).
- `lib/data/hermes_adapter.dart` `HermesRpc` (l.462+) : ajouter `titleParams` / `titled` sur le modèle de `listParams` / `sessions` ; réponse mal formée → `contract.invalid_response`.
- `lib/models/timeline.dart` `ConversationGateway` (l.858) : ajouter `rename(...)` à côté de `sessions(...)`.
- `lib/data/conversation_repository.dart` : `sessions()` (l.607) vérifie la connexion courante ; runtime obtenu par `resumer.resume(key)` (l.653), chemin de reprise existant, sans création.
- `lib/features/history/history_view_model.dart` : `refresh()` écarte les réponses périmées via `_request` ; `sessions` jamais mis en cache.
- `lib/features/history/history_view.dart`, `lib/ui/components/history_row.dart` : liste et ligne (`ListTile`) ; `HistoryNotice` pour messages live.
- `lib/app/routes.dart` (l.263) : construit `HistoryViewModel` ; `test/history_test.dart` : faux gateways réutilisables.
- `lib/ui/content.dart` : tous les libellés.

## Tasks & Acceptance

**Execution :**
- [x] `lib/data/hermes_adapter.dart` -- `HermesRpc.titleParams(runtime, profile, title)` et `titled(result)` → `({String title, bool pending})` -- dialecte isolé et validé.
- [x] `lib/models/timeline.dart`, `lib/data/conversation_repository.dart` -- `rename(TimelineKey, String title)` : connexion courante, reprise pour runtime, un seul appel en cours par clé, erreurs traduites (`rename.missing`, `rename.refused`, `rpc.uncertain`, `rename.pending`) ; aucun titre local publié.
- [x] `lib/features/history/history_view_model.dart` -- état de renommage par session (en cours, erreur, saisie conservée), validation trim/vide/identique, cible figée au lancement ; succès → titre confirmé remplacé dans `sessions`.
- [x] `lib/ui/components/history_row.dart`, `lib/features/history/history_view.dart` -- menu « Renommer » en fin de ligne ; méthode absente constatée → entrée désactivée avec explication.
- [x] `lib/features/history/rename_conversation_dialog.dart` -- champ initialisé et nommé, erreur annoncée, progression, annulation, focus rendu à la ligne.
- [x] `lib/ui/content.dart` -- libellés.
- [x] `test/rename_conversation_test.dart` -- matrice complète, réponse ancienne, `pending`, actualisation qui reprend le titre distant.

**Acceptance Criteria :**
- Étant donné une modification depuis Desktop, quand l'historique est actualisé avec succès, alors le titre distant apparaît dans le seul profil concerné.
- Étant donné clavier, lecteur d'écran et texte agrandi, quand le dialogue est utilisé puis fermé, alors champ, erreur et boutons sont nommés et utilisables et le focus revient à la conversation.
- Étant donné une dépendance non vérifiée, quand le bilan est établi, alors la story n'est pas déclarée validée.

## Implementation Notes

- Réalisé le 2026-10-31 contre le contrat documentaire seulement (« préparation seulement ») : `session.title` reste non qualifiée sur installation ; la story n'est pas validée.
- `ConversationRepository.rename` : runtime lié sur la socket courante réutilisé, sinon `resumer.resume(key)` ; une seule mutation par clé (`rename.busy`) ; échec de reprise → `rename.unreachable` (titre jamais envoyé, `transport.offline` et `contract.invalid_response` propagés) ; -32601 mémorisé par (connexion, génération de socket), donc retesté après reconnexion.
- `contract.invalid_response` et `connection.mismatch` proposent aussi l'actualisation (résultat à vérifier), en plus de `rpc.uncertain` et `rename.pending`.
- Une actualisation garde les saisies et efface les erreurs non en cours ; un renommage confirmé n'est appliqué qu'à la liste de sa connexion d'origine.
- Menu de ligne : `MenuAnchor` + `IconButton` (focus rendu explicitement au bouton du menu après le dialogue). Aucune modification de `routes.dart` nécessaire.

## Spec Change Log

## Review Triage Log

Passe 1 (2026-10-31) — trois relecteurs (aveugle, cas limites, lacunes de vérification).

| # | Constat | Verdict | Preuve / route |
|---|---|---|---|
| 1 | Titre confirmé pendant une actualisation perdu, liste possiblement antérieure | medium | `_listed = null` pendant `refresh()` ; succès non appliqué, dialogue fermé. patch : nouvelle actualisation |
| 2 | Fermeture par fond ou Retour sans `dismissRename` | medium | `showDialog` sans `whenComplete` ; brouillon/erreur périmés à la réouverture. patch |
| 3 | « Annuler » actif pendant l'envoi, résultat tardif invisible | low | Résultat conservé dans `_renames`, revu à la réouverture ; succès appliqué à la ligne. rejeté |
| 4 | `contract.invalid_response` de la reprise annoncé comme titre à vérifier | low | Rethrow l.47 ; `session.title` jamais envoyé. patch |
| 5 | `session_key` validé puis ignoré | maybe-false | Dépend du comportement réel de Hermes (re-clé ?) ; à trancher par qualification. defer |
| 6 | Branches non testées (génération, reprise, needsRefresh, refresh) | medium | Constats lacunes 1–5 confirmés ; patch tests |
| 7 | Pas de longueur max du titre | low | Limite serveur inconnue ; champ mono-ligne filtre les retours. rejeté |
| 8 | `_renames` jamais purgé | low | Clé de session d'une autre connexion identique improbable. rejeté |
| 9 | `content.dart` non formaté | false | `dart format --set-exit-if-changed` ne signale pas `lib/ui/content.dart` |
| 10 | Reprise du renommage concurrente d'une autre reprise | maybe-false | `OutboxRepository.resume` sans verrou par clé ; effet serveur de deux `session.resume` inconnu. defer |
| 11 | Spec absente du diff | false | Exclue volontairement ; transmise séparément comme claims |
| 12 | Validation pendant un chargement → « connexion changée » | low | Dialogue modal ; lignes absentes pendant le chargement. rejeté |
| 13 | `renameMissing` non renotifié après reconnexion | low | Réévalué à la prochaine notification/actualisation. rejeté |
| 14 | Renommage après `dispose()` du repository | false | Repository disposé en fin d'app, aucune vue active |
| 15 | Focus perdu après « Actualiser » depuis le dialogue | low | Rechargement volontaire de la liste, comme le bouton d'en-tête existant ; fermetures Annuler/validation rendent le focus (testé). rejeté |

## Design Notes

Runtime : `session.title` attend un identifiant runtime (documentaire). Une ancienne conversation passe par la reprise existante (`session.resume`, aucun fil créé), comme son ouverture. `pending: true` = titre non confirmé : message « en attente, actualisez » et ancien titre conservé. -32601 mémorise « indisponible » pour la connexion courante.

## Verification

**Commands :**
- `C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat analyze --no-pub` -- aucune alerte.
- `C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat test --no-pub` -- tous les tests passent.

**Manual checks :**
- Android : clavier, texte agrandi, TalkBack, focus, changement de profil ; sur installation : renommage visible depuis un autre client après actualisation.
