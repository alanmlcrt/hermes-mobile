---
title: 'Story 4.4 - Retrouver mes fichiers dans l’historique'
type: 'feature'
created: '2026-10-26'
status: 'done'
baseline_commit: '9a07563a7a20cee8e1b81e19baeeb9af2d489475'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Après réouverture d’une conversation, les pièces envoyées doivent rester identifiables dans leur message. Actuellement, seuls leurs noms sont ajoutés au texte local ; les copies privées restent indéfiniment conservées.

**Approche :** Afficher des pièces structurées dans les messages utilisateur, à partir des métadonnées locales durables et du rapprochement distant existant. Conserver nom, type et état après nettoyage ; afficher un aperçu image lorsque la copie privée est disponible.

## Boundaries & Constraints

**Toujours :** Isoler connexion/profil/session et opération/message. Exiger une opération acceptée, une ligne utilisateur rapprochée sans ambiguïté et la preuve distante propre à chaque pièce avant suppression de sa copie. Persister les métadonnées avant nettoyage. Distinguer réception et analyse. Réutiliser tokens, libellés accessibles et mise en page compatible avec texte à 200 %.

**Jamais :** Rattacher une pièce par similitude du texte, par nom seul ou par position approximative. Nettoyer une pièce du brouillon courant ou sans preuve. Réenvoyer automatiquement. Exécuter un fichier, ouvrir automatiquement une application, télécharger une URL ou interpréter une référence serveur comme chemin local. Inventer des métadonnées pour des fichiers envoyés depuis un autre appareil.

## I/O & Edge-Case Matrix

| Scénario | Entrée / état | Résultat attendu | Gestion d’erreur |
|---|---|---|---|
| Réouverture | Pièces et message connus localement | Nom, type, état dans le bon message | Texte historique conservé |
| Image | Copie privée disponible | Aperçu accessible | Copie absente/corrompue : nom et type seuls |
| Preuve distante | Opération acceptée, ligne exacte, pièce reçue | Métadonnées durables puis copie supprimée | Suppression échouée : reprise ultérieure sans perte |
| Doute / partiel | Preuve absente pour une pièce | Copie de cette pièce conservée | Aucune confirmation ou suppression supposée |
| Redémarrage | Arrêt entre persistance et suppression | Même rattachement ; nettoyage reprenable | Suppression idempotente |
| Isolation | Même nom ou même numéro de ligne ailleurs | Aucun mélange entre scopes | Aucun rattachement ambigu |

</frozen-after-approval>

## Code Map

- `lib/models/timeline.dart` : `UserItem`, `withRow`, sérialisation JSON ; ajouter les pièces sans casser les anciennes projections.
- `lib/models/attachment.dart` : métadonnées et états existants ; distinguer absence après nettoyage d’un fichier manquant avant envoi.
- `lib/data/conversation_repository.dart` : `accepted`, `_fromHistory`, `load`, `resync` ; propriétaire des projections. Le rattachement positionnel existant des bulles ne constitue pas une preuve pour les pièces.
- `lib/data/outbox_repository.dart` : `_commitAccepted`, `_confirmReceipts`, `_readPendingReceipts`, `reconcile` ; réutiliser les preuves exactes et gardes de génération de socket de 4.3.
- `lib/data/storage/migrations.dart` : version 12 ; métadonnées dans `outbox_attachments`, instantanés dans `outbox_operation_attachments`, ligne dans `outbox_operations`. Migration additive uniquement si nécessaire.
- `lib/data/storage/attachment_files.dart` : suppression privée validée par clés, réutilisable.
- `lib/features/conversation/draft_view.dart`, `lib/ui/components/message_bubble.dart`, `lib/ui/content.dart` : rendu des `UserItem` et libellés. Aucun changement nécessaire à la liste des sessions.
- `lib/data/hermes_adapter.dart` : `history` expose ligne/rôle/texte, sans contrat de téléchargement ni métadonnées structurées garanties.

## Tasks & Acceptance

**Exécution :**
- [x] `lib/models/attachment.dart`, `lib/models/timeline.dart` : représenter et sérialiser les pièces historiques avec lecture rétrocompatible.
- [x] `lib/data/conversation_repository.dart`, `lib/data/outbox_repository.dart` : hydrater les pièces depuis les données durables, par scope et identité prouvée du message ; actualiser le fil après rapprochement sans renvoi.
- [x] `lib/data/storage/attachment_files.dart`, `lib/data/outbox_repository.dart`, `lib/data/storage/migrations.dart` : nettoyage par pièce après persistance et preuve ; reprise après interruption ou erreur, sans effacer les métadonnées.
- [x] `lib/features/conversation/draft_view.dart`, `lib/ui/components/message_bubble.dart`, `lib/ui/content.dart` : afficher nom/type/état et aperçu disponible ; ajouter un composant dédié si nécessaire.
- [x] `test/attachment_history_test.dart`, `test/attachment_send_test.dart`, `test/resync_test.dart`, `test/attachment_store_test.dart` : couvrir la matrice, les anciennes données 4.3, les demandes suivantes et les profils/sessions distincts.
- [x] `test/attachment_flow_test.dart` : vérifier l’affichage dans une conversation rouverte, les noms longs, le repli d’image et le texte à 200 %.

**Critères d’acceptation :**
- Étant donné un message envoyé avec pièces, quand la conversation est rouverte après redémarrage, alors chaque pièce reste identifiable par nom et type dans son message, avec aperçu image si disponible.
- Étant donné deux conversations de profils différents, quand chacune possède des fichiers, alors aucune pièce ne paraît dans l’autre conversation.
- Étant donné une pièce d’un message accepté et rapproché, quand sa réception est prouvée dans l’historique distant, alors sa copie privée est nettoyée et son identité reste affichable, sans exécution automatique.

## Implementation Notes

Investigation : branche propre `epic/4-pieces-jointes`, story 4.3 terminée, aucun sprint-status présent. Aucun choix fonctionnel restant ; les téléchargements et l’ouverture de fichiers ne font pas partie des critères 4.4. Effet irréversible prévu : suppression des copies privées après preuve. Empreinte : modèles, repositories, stockage, rendu et tests. Appliquer le skill UI existant.

Implémentation : migration additive 13, hydratation par opération et ligne exacte, nettoyage individuel reprenable. Audit du diff et de la matrice effectué ; 79 tests ciblés et 431 tests globaux réussis, 17 ignorés. Analyse sans anomalie et APK debug compilé. Preuves : [rapport](story-4-4-verification/implementation-report.md). Aucun essai Hermes réel.

## Spec Change Log

## Review Triage Log

| ID | Verdict | Preuve et décision |
| --- | --- | --- |
| B1 | medium | La bulle sans ligne cesse de correspondre dès que la preuve renseigne la ligne de son opération. Rattacher par opération exacte et propager la ligne prouvée ; patch. |
| B2 | medium | `_withAttachments` résout un chemin même pour une pièce nettoyée. Une exception du fournisseur annule l’hydratation ; ignorer cette résolution après nettoyage et replier les erreurs par pièce ; patch. |
| B3 | high | `_enqueue` abandonne la nouvelle bulle acceptée si la résolution du chemin échoue ; même cause que B2, préserver les métadonnées ; patch commun. |
| B4 | high | Pour PNG, un second écho du prompt reste après suppression de sa première occurrence et devient une preuve autorisant suppression. Exclure tous les échos exacts avant lecture de la preuve et ajouter la régression ; patch. |
| B5 | medium | Le second enregistrement dans `_resync` suit de nouveaux appels asynchrones sans revérification de génération. Vérifier avant publication de la projection hydratée ; patch. |
| B6 | maybe-false | Boucles et accès sériels confirmés, mais aucun volume ou délai démontrant une dégradation perceptible. Le coût de réouverture demanderait une mesure sur une longue conversation. Risque faible non démontré ; rejet de l’optimisation structurelle. |
| B7 | low | `_readPendingReceipts` conserve l’instantané local antérieur au nettoyage et peut redemander une preuve déjà durable. Relire après nettoyage est une correction directe ; patch. |
| B8 | medium | Le widget rouvert utilise une projection mémoire ; absence de traversée réelle persistance vers interface après relance. Ajouter cette vérification ; patch. |
| B9 | medium | Le succès sans ligne n’est pas testé avant resynchronisation complète ; même défaut que B1. Régression du rafraîchissement immédiat ; patch commun. |
| E1 | medium | Même disparition après ligne prouvée que B1 ; correction et régression communes ; patch. |
| E2 | high | Deux pièces peuvent recevoir la même référence ; une seule occurrence de preuve confirme et supprime actuellement les deux copies. Refuser la preuve ambiguë pour une référence partagée ; patch. |
| E3 | high | Même perte de bulle sur erreur de résolution privée que B2/B3 ; correction et test communs ; patch. |
| V1 | medium | Lacune pré-vérifiée : les tests rechargent explicitement la conversation et ne prouvent pas son rafraîchissement sur réception différée. Vérifier projection ouverte et notification sans load/resync ; patch. |
| QA1 | medium | La vérification globale après patch révèle que la garde de scope compare une clé logique de fil à la connexion active. Capturer cette dernière avant reprise et vérifier sa stabilité, tout en préservant génération et profil ; correction directe. Les attentes historiques de resynchronisation restent inchangées. |

Regroupements : B1/B9/E1/V1 (rafraîchissement), B2/B3/E3 (repli stockage), puis B4, B5, B7, B8 et E2. Corrections locales sur états démontrés, sans nouvelle interface publique. Aucun changement d’intention ni de spécification fonctionnelle nécessaire.

Corrections de revue appliquées : identité d’opération et ligne propagée, repli aperçu par pièce, copies nettoyées sans résolution de chemin, exclusion des échos exacts multiples, références partagées ambiguës, contrôle de stabilité connexion/profil/génération, relecture après nettoyage. Ajout d’un widget avec repositories réels et SQLite durable. 53 tests ciblés de correction réussis, puis 45 tests ciblés de reprise et historique réussis après QA1. Nouvelle vérification globale en cours.

Clôture : revue à trois regards terminée, tous les constats retenus corrigés, aucun constat différé. Vérification globale finale : 442 tests réussis et 17 ignorés ; analyse sans anomalie ; APK debug recompilé. Deux paires d’accolades ajoutées après la suite globale pour satisfaire l’analyse, sans modification de comportement. Rapport et preuves conservés dans `story-4-4-verification/`.

## Verification

- `flutter test test/attachment_history_test.dart test/attachment_send_test.dart test/resync_test.dart test/attachment_store_test.dart test/attachment_flow_test.dart` : matrice et invariants satisfaits.
- `flutter test` : aucune régression.
- `flutter analyze` : aucune anomalie.
- `flutter build apk --debug` : APK compilé.
