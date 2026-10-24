---
title: 'Story 4.3 - Envoyer mes fichiers et savoir s’ils sont reçus'
type: 'feature'
created: '2026-10-24'
status: 'draft'
route: 'dispatch'
review_loop_iteration: 0
context: ['{project-root}/contracts/file-limits.json']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Alanc doit connaître la réception de chaque pièce dans la bonne conversation. Le pipeline réserve cette étape mais ne téléverse rien.

**Approach:** Envoyer les copies privées après création de session, conserver les références serveur, afficher les états individuels et bloquer le prompt sur échec ou doute.

**Décision d'Alanc :** implémenter et valider 4.2 avant 4.3. La sélection et les copies privées sont maintenant implémentées et validées.

## Boundaries & Constraints

**Always:** Figer pièces et scope connexion/profil/session avant appel externe. Lire les limites mesurées. Conserver texte et copies sur échec. Distinguer reçu et analysé. Préserver la prévention des doubles envois.

**Never:** Transmettre un chemin du téléphone, exécuter un fichier, assimiler timeout et reçu, extrapoler la vision du profil de test, nettoyer avant rapprochement distant (4.4).

## I/O & Edge-Case Matrix

| Scénario | Entrée | Résultat | Erreur |
|---|---|---|---|
| Succès | Pièces confirmées | Prompt avec références | Validation avant soumission |
| Refus | Une pièce refusée | Échec individuel nommé | Brouillon conservé, retrait ou essai explicite |
| Incertain | Timeout, réponse invalide | État distinct de reçu | Aucun prompt ni répétition automatique |
| Partiel | Réussite puis échec | États durables distincts | Ne pas renvoyer aveuglément les réussites |
| Redémarrage | Interruption pendant upload | Pièce en vol incertaine | Jamais reçue par défaut |
| Isolation | Profil changé | Cible d’origine conservée | Aucun transfert vers le nouveau profil |
| Vision | Capacité inconnue/absente | Libellé explicite | Aucune promesse d’analyse |

</frozen-after-approval>

## Open Questions

1. **Confirmation préalable.** La preuve 4.1 relit l’historique après le prompt. Options : accepter `attached=true` avec référence serveur valide avant prompt, puis rapprocher après soumission ; ou exiger une preuve indépendante avant prompt, donc établir un contrat serveur supplémentaire avant activation. Tout doute bloque le prompt.
2. **Images hors contrat épinglé.** Options : adopter `image.attach_bytes`, mesuré, pour PNG et bloquer JPEG jusqu’à mesure ; ou bloquer toutes les images et activer seulement les documents épinglés. L’autorisation JPEG locale de 4.2 ne prouve pas sa réception.

## Code Map

- `lib/models/attachment.dart`, `lib/models/draft.dart` : modèles locaux et méthodes de pièces dans `OutboxGateway` livrés par 4.2.
- `lib/data/outbox_repository.dart` : `send`, opération persistée puis `ensureSession`, étape `attachments` avant `prompt.submit`. Le blocage 4.2 des brouillons à pièces devra être remplacé par le pipeline vérifié. Préserver gardes et rapprochement.
- `lib/data/storage/migrations.dart` : migration 11 avec `outbox_attachments`, pièces ordonnées par brouillon ; `lib/data/storage/attachment_files.dart` gère les copies privées.
- `tool/mesure_pieces_jointes.dart:658` : `_attachFile` ; 726 `_attachImageBytes` ; 923 `_readReceipt` ; 979 `receiptVerdict`. Preuve postérieure au prompt.
- `contracts/openrpc.json:280` : `file.attach`, résultat `attached/ref_path/ref_text/uploaded`. `contracts/file-limits.json` : MIME et surfaces mesurés.
- `test/outbox_repository_test.dart`, `test/support/connection_fakes.dart` : infrastructure des tests.

## Tasks & Acceptance

**Execution:**
- [ ] `lib/models/attachment.dart`, `lib/models/draft.dart` : étendre les interfaces 4.2 aux états et références.
- [ ] `lib/data/storage/migrations.dart`, `lib/data/outbox_repository.dart` : persister cible, liste figée et tentatives ; contrôler avant prompt.
- [ ] `lib/data/attachment_transport.dart` : contrat retenu, refus et incertitude distincts.
- [ ] `lib/features/conversation/draft_view_model.dart`, `lib/features/conversation/draft_view.dart`, `lib/ui/components/attachment_list.dart`, `lib/ui/content.dart` : états accessibles, retrait, nouvel essai.
- [ ] `test/attachment_send_test.dart`, `test/outbox_repository_test.dart` : matrice et absence de prompt sur échec.

**Acceptance Criteria:**
- Given un brouillon avec pièces, when l’envoi réussit, then les références du scope d’origine figurent dans le prompt.
- Given une pièce refusée ou incertaine, when le pipeline s’arrête, then aucun prompt ne part et texte comme copies restent disponibles.
- Given une pièce en cours, reçue ou échouée, when son état change, then un libellé accessible le distingue sans dépendre de la couleur.
- Given une vision inconnue, when une image est présentée, then aucune analyse n’est promise.

## Implementation Notes

Investigation initiale du 24 octobre : 4.2 absente. À la demande d'Alanc, 4.2 a ensuite été implémentée, revue et validée avant reprise de 4.3. Aucun code 4.3 modifié. Empreinte prévue : migration SQLite, modèle, transport, pipeline et interface ; effets externes lors des envois.

## Spec Change Log

## Review Triage Log

## Verification

- `flutter test test/attachment_send_test.dart test/outbox_repository_test.dart` : matrice et invariants satisfaits.
- `flutter test` : aucune régression.
- `flutter analyze` : aucune anomalie.
- `flutter build apk --debug` : APK compilé après intégration.
