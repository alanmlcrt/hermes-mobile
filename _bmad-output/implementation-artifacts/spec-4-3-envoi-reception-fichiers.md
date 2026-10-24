---
title: 'Story 4.3 - Envoyer mes fichiers et savoir s’ils sont reçus'
type: 'feature'
created: '2026-10-24'
status: 'done'
baseline_commit: '3708252e2aeb8417a3eeb642aa4ee3441024a34c'
route: 'dispatch'
review_loop_iteration: 0
context: ['{project-root}/contracts/file-limits.json']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Alanc doit connaître la réception de chaque pièce dans la bonne conversation. Le pipeline réserve cette étape mais ne téléverse rien.

**Approach:** Envoyer les copies privées après création de session, conserver les références serveur, afficher les états individuels et bloquer le prompt sur échec ou doute.

**Décision d'Alanc :** implémenter et valider 4.2 avant 4.3. La sélection et les copies privées sont maintenant implémentées et validées.

**Décisions validées à la reprise :** `attached=true` avec référence serveur valide confirme le téléversement avant prompt ; seule la preuve serveur dans l’historique après soumission autorise « reçu ». Sans preuve, rester « téléversé, réception à vérifier ». Activer PNG via `image.attach_bytes`, mesuré hors extrait épinglé ; bloquer JPEG avant tout téléversement jusqu’à mesure. Ne pas modifier les contrats mesurés.

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

## Code Map

- `lib/models/attachment.dart`, `lib/models/draft.dart` : modèles locaux et méthodes de pièces dans `OutboxGateway` livrés par 4.2.
- `lib/data/outbox_repository.dart` : `send`, opération persistée puis `ensureSession`, étape `attachments` avant `prompt.submit`. Le blocage 4.2 des brouillons à pièces devra être remplacé par le pipeline vérifié. Préserver gardes et rapprochement.
- `lib/data/storage/migrations.dart` : migration 11 avec `outbox_attachments`, pièces ordonnées par brouillon ; `lib/data/storage/attachment_files.dart` gère les copies privées.
- `tool/mesure_pieces_jointes.dart:658` : `_attachFile` ; 726 `_attachImageBytes` ; 923 `_readReceipt` ; 979 `receiptVerdict`. Preuve postérieure au prompt.
- `contracts/openrpc.json:280` : `file.attach`, résultat `attached/ref_path/ref_text/uploaded`. `contracts/file-limits.json` : MIME et surfaces mesurés.
- `contracts/README.md`, section « Transports et écarts documentaires » : adoption des transports image soumise à arbitrage ; la mesure de vision ne vaut que pour le profil de test. `lib/data/file_limits.dart` : réutiliser les limites, mais séparer l’exception de sélection JPEG de l’autorisation de téléversement.
- `lib/data/outbox_repository.dart`, `_writeAttachment`, `send`, `_commitAccepted`, `resume` : réutiliser sérialisation, garde synchrone, révision de texte et génération de socket ; conserver les copies après acceptation et séparer pièces déjà envoyées des prochaines pièces du brouillon.
- `lib/features/conversation/draft_view_model.dart`, `blockedReason`/`send` : deux blocages 4.2 à remplacer ensemble. `lib/ui/components/attachment_list.dart` : état actuellement toujours « sélectionné ».
- `test/outbox_repository_test.dart`, `test/support/connection_fakes.dart` : infrastructure des tests.

## Tasks & Acceptance

**Execution:**
- [x] `lib/models/attachment.dart`, `lib/models/draft.dart` : étendre les interfaces 4.2 aux états et références.
- [x] `lib/data/storage/migrations.dart`, `lib/data/outbox_repository.dart` : persister cible, liste figée et tentatives ; contrôler avant prompt.
- [x] `lib/data/outbox_repository.dart` : réutiliser les succès uniquement dans leur scope d’origine ; rendre une tentative interrompue incertaine au redémarrage ; conserver les copies après acceptation sans les renvoyer avec la demande suivante.
- [x] `lib/data/attachment_transport.dart` : contrat retenu, refus et incertitude distincts.
- [x] `lib/features/conversation/draft_view_model.dart`, `lib/features/conversation/draft_view.dart`, `lib/ui/components/attachment_list.dart`, `lib/ui/content.dart` : états accessibles, retrait, nouvel essai.
- [x] `test/attachment_send_test.dart`, `test/outbox_repository_test.dart` : matrice et absence de prompt sur échec.

**Acceptance Criteria:**
- Given un brouillon avec pièces, when l’envoi réussit, then les références du scope d’origine figurent dans le prompt.
- Given une pièce refusée ou incertaine, when le pipeline s’arrête, then aucun prompt ne part et texte comme copies restent disponibles.
- Given une pièce en cours, reçue ou échouée, when son état change, then un libellé accessible le distingue sans dépendre de la couleur.
- Given une vision inconnue, when une image est présentée, then aucune analyse n’est promise.
- Given un redémarrage pendant un téléversement, when le brouillon est rechargé, then la pièce est incertaine et aucun renvoi automatique ne se produit.
- Given une acceptation suivie d’une nouvelle demande, when elle est envoyée, then les anciennes pièces conservées ne sont pas jointes une seconde fois.

## Implementation Notes

Investigation initiale du 24 octobre : 4.2 absente. À la demande d'Alanc, 4.2 a ensuite été implémentée, revue et validée avant reprise de 4.3. Aucun code 4.3 modifié. Empreinte prévue : migration SQLite, modèle, transport, pipeline et interface ; effets externes lors des envois.

Reprise du 24 octobre : branche propre `epic/4-pieces-jointes`, continuité 4.2 étudiée ; aucun sprint-status. Alanc approuve les deux recommandations et demande de poursuivre. Migration additive, effets externes au téléversement, copies conservées. Le worker possède les modifications applicatives et tests 4.3 ; dépôt partagé, préserver les modifications des autres. Appliquer `.agents/skills/ui-ux-pro-max/SKILL.md` pour l’interface, tokens existants. Rapporter les preuves de vérification et couvrir chaque ligne de matrice.

Implémentation Orca `ctx_6bb2c2900192` sur GPT-6 Sol terminée : migration 12, instantanés des tentatives, transport, références et rapprochement de réception, retrait et essai explicite. Rapport : 405 tests réussis, 17 ignorés, analyse sans anomalie, APK debug compilé. Audit local du diff complet et exécution des 29 tests ciblés réussis avant revue ; aucune validation sur serveur réel à ce stade.

Après revue : corrections des références exactes, attribution au message courant, contrôles connexion/génération, récupération d’erreurs de préparation et d’acceptation, preuve différée sans renvoi, noms des pièces dans la projection locale, actions adaptatives à 200 %. Validation finale : 419 tests réussis (17 ignorés préexistants), 25 scénarios d’envoi explicites, analyse sans anomalie, APK debug compilé. Rapport et captures : [verification.md](story-4-3-verification/verification.md). Aucun constat différé ; essai sur Hermes réel et appareil non réalisé.

## Spec Change Log

## Review Triage Log

| ID | Verdict | Preuve et décision |
|---|---|---|
| B1 | high | Le rapprochement image utilise `contains` dans les deux sens : une référence préfixe peut être faussement reçue. Correction locale : comparaison de références complètes et régression. |
| B2 | high | Sans `user_row_id`, tous les anciens messages sont candidats. Exiger une ligne courante identifiée, ou un candidat unique au-delà du repère persisté ; sinon conserver l’incertitude. |
| B3 | medium | Une chaîne image `OK` suffit à débloquer le prompt. Valider la syntaxe de référence image mesurée, sans inventer de capacité de réception. |
| B4 | medium | La relecture des pièces après passage à `sending` échappe au `try`. La ramener dans la préparation protégée ; faute de stockage, aucun prompt et état récupérable. |
| B5 | medium | Une session reprise avec `running=true` reçoit les uploads avant le refus. Déplacer la garde existante immédiatement après résolution de session. |
| B6 | high | La comparaison SQLite ne contrôle pas la connexion/génération courante ; une reconnexion entre deux pièces réutilise un runtime périmé. Contrôler avant chaque appel externe et après lecture des octets. |
| B7 | medium | La preuve n’est relue qu’une fois après acceptation directe. Reprendre la vérification des pièces acceptées en attente à la fin du tour et lors du rapprochement, sans aucun renvoi. |
| B8 | medium | `conversation.accepted` reçoit seulement le texte, vide pour une demande à pièces seules. Ajouter les noms des pièces à la projection locale ; l’historique complet reste à 4.4. |
| B9 | medium | Tous les `RpcError` sont des refus certains, y compris les erreurs internes après effets possibles. Limiter la certitude aux rejets JSON-RPC avant exécution. |
| E1 | high | Même absence de garde connexion/génération que B6 ; correction commune, y compris lecture locale asynchrone. |
| E2 | medium | Même exception pré-soumission hors garde que B4 ; correction commune. |
| E3 | high | Même collision de références que B1, également présente pour les documents. Comparaison complète commune. |
| E4 | high | Même attribution historique sans identifiant de ligne que B2 ; correction commune. |
| E5 | high | `_accept` ignore l’échec du commit puis affiche accepté, laissant `sent=0`. Conserver une opération incertaine et interdire une nouvelle soumission de ces pièces jusqu’au rapprochement. |
| V1 | medium | Lacune pré-vérifiée : les faux récepteurs ne vérifient pas les octets, la session et le profil des deux méthodes. Ajouter des assertions au récepteur. |
| V2 | medium | Lacune pré-vérifiée : absence de cas de rapprochement avec pièces et demande suivante. Couvrir exclusion des anciennes pièces et absence de nouveau téléversement. |
| V3 | medium | Lacune pré-vérifiée : le bouton isolé et le repository sont testés séparément ; aucune traversée page → view model → repository. Ajouter ce scénario. |
| V4 | high | Collision de références document confirmée comme B1/E3 ; même correction et régression. |
| QA1 | medium | Le test 375 px à 200 % avec échec et nouvel essai reproduit un débordement de 125 px. Remplacer la rangée d’actions par un retour à la ligne utilisant les tokens existants. |

Toutes les corrections retenues portent sur des états démontrés et restent internes, sans nouvelle interface publique : routage `patch`. Aucun constat écarté ou différé. Le worker d’implémentation ayant été libéré après livraison, le coordinateur applique les corrections puis relance les vérifications.

## Verification

Vérifications exécutées, détails dans le rapport lié ci-dessus :

- `flutter test test/attachment_send_test.dart test/outbox_repository_test.dart` : matrice et invariants satisfaits.
- `flutter test` : aucune régression.
- `flutter analyze` : aucune anomalie.
- `flutter build apk --debug` : APK compilé après intégration.
