---
title: 'Story 3.5 — Demander l’arrêt du travail en cours'
type: 'feature'
created: '2026-10-24'
status: 'done'
baseline_commit: 'a62a349341ed6e05fe1fd901420e3028ec842ba3'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="intention réservée à l’humain — modification après renégociation uniquement">

## Intent

**Problème :** La conversation expose le travail et ses terminaux, mais aucune commande pour en demander l’arrêt.

**Approche :** Persister une intention locale ciblée, appeler `session.interrupt` une fois, puis distinguer « Arrêt demandé » et « Arrêt confirmé » selon les preuves reçues.

**Décision UX approuvée :** Pendant le travail, remplacer le bouton rond d’envoi par une icône carrée d’arrêt, avec nom accessible « Arrêter ». Conserver le champ de saisie et son texte. Le rappel des effets déjà produits reste visible près de la saisie.

## Boundaries & Constraints

**Toujours :** Outbox propriétaire des intentions ; repository propriétaire de la projection. Persister connexion, profil, session durable, runtime, génération et tour observé avant transmission ; revérifier après chaque attente. Préserver refonte autorisée et brouillon. Rappel : « L’arrêt n’annule pas les actions déjà effectuées. » Commande accessible avec clavier, activités repliées, texte 200 %, cible 48 dp et annonce sans doublon.

**Jamais :** Injecter `stopRequested` dans la projection ; confirmer depuis un résultat RPC ou le silence ; renvoyer automatiquement après reprise ou sur un autre tour ; inventer une identité serveur. Une preuve documentaire ne valide pas l’installation personnelle.

## I/O & Edge-Case Matrix

| Situation | Résultat attendu | Repli |
|---|---|---|
| Tour actif, première pression | Intention persistée puis un seul RPC ; « Arrêt demandé » | Échec de stockage : aucun RPC, erreur lisible |
| Pressions répétées ou deux vues de la même session | Une opération en vol par cible | Aucun double appel |
| Cible terminée, génération/profil/connexion modifiés pendant une attente | Pas de transmission tardive | Demande périmée |
| Résultat RPC, délai dépassé, coupure ou redémarrage client | Aucune confirmation implicite, intention conservée | Issue inconnue, aucun renvoi automatique |
| Terminal `message.complete.status=interrupted` du contexte courant | Projection `stopped` ; « Arrêt confirmé » | Terminal réussi/échoué : montrer cette issue |
| Reconnexion ou nouveau tour | Afficher l’état resynchronisé ; ancienne intention sans effet sur le nouveau tour | Sans preuve : état inconnu |
| RPC absent/refusé ou réponse invalide | Erreur explicite, brouillon conservé | Aucun autre protocole d’arrêt |

</frozen-after-approval>

## Code Map

- `contracts/openrpc.json`, `event-mapping.json` : `session.interrupt(session_id, profile, expected_hosted_task_id?)`, réponse `interrupted/not_interrupted` distincte du terminal `message.complete`.
- `lib/data/hermes_adapter.dart` : formats `HermesRpc`, transport existant `ConnectionGateway.call`.
- `lib/data/outbox_repository.dart`, `lib/models/draft.dart` : opérations, runtime/génération/reprise ; ne pas reprendre une session pour transmettre une ancienne intention.
- `lib/data/conversation_repository.dart`, `lib/models/timeline.dart` : projection, tours et files par session ; préserver mapping terminal.
- `lib/data/storage/migrations.dart` : migration additive, préserver `profile_accents` préexistant.
- `lib/features/conversation/draft_view_model.dart`, `draft_view.dart`, `lib/ui/components/composer.dart`, `work_state_label.dart` : commande et annonce ; préserver Otc.

## Tasks & Acceptance

**Exécution :**
- [x] `lib/models/draft.dart`, `lib/data/storage/migrations.dart`, `lib/data/outbox_repository.dart` — modéliser, persister, restaurer et notifier l’arrêt ciblé ; verrouiller par session, sans répétition automatique.
- [x] `lib/data/hermes_adapter.dart`, `contracts/methods.json`, `contracts/capabilities.json`, `contracts/README.md` — formats et traçabilité de l’arrêt documentaire, erreurs explicites sans prétendre valider l’installation.
- [x] `lib/data/conversation_repository.dart`, `lib/models/timeline.dart` — exposer le repère nécessaire et neutraliser les intentions périmées sans y injecter l’état local.
- [x] `lib/features/conversation/draft_view_model.dart`, `draft_view.dart`, `lib/ui/components/composer.dart`, `work_state_label.dart`, `lib/ui/content.dart`, `tokens.dart`, `gallery.dart` — intégrer le choix UX approuvé et les états de démonstration.
- [x] `test/stop_flow_test.dart`, `test/outbox_repository_test.dart`, `test/resync_test.dart`, `test/hermes_adapter_test.dart`, `test/gallery_test.dart` — couvrir la matrice, notamment attente de stockage, double pression, nouveau tour, contextes différents et restauration SQLite.
- [x] `_bmad-output/implementation-artifacts/story-3-5-verification/` — consigner résultats, captures et limites ; distinguer changements préexistants et contribution 3.5.

**Critères d’acceptation :**
- Given un travail observé, when l’arrêt est demandé, then la persistance précède l’appel et l’intention reste séparée de la projection.
- Given une demande incertaine, when le réseau revient ou un nouveau tour commence, then aucun arrêt ancien n’est renvoyé et l’état reçu prévaut.
- Given clavier, activités repliées, thème sombre ou texte 200 %, when la conversation est utilisée, then l’arrêt et son rappel restent accessibles sans chevauchement.

## Implementation Notes

Spécification approuvée le 24 octobre : poursuite de l’implémentation autorisée. Les changements préexistants doivent être conservés. Plusieurs agents peuvent intervenir dans le même dépôt : ne pas annuler leurs modifications, adapter l’implémentation à l’état courant. Toutes les commandes shell doivent être préfixées par `rtk`, avec `rtk proxy` pour les commandes non reconnues, conformément à `C:/Users/alanc/.codex/RTK.md`.

Audit parent : tâches confrontées au diff et aux fichiers finaux, matrice rapprochée des tests exécutés de `stop_flow_test.dart` et du test de migration v9. Les scénarios ne sont pas ignorés ; la suite finale compte 343 réussites et 17 tests préexistants ignorés. Les vérifications RPC et reprise sont regroupées dans `stop_flow_test.dart`, sans modification nécessaire des anciens fichiers de test équivalents. Diff complet incluant les fichiers non suivis conservé en dossier temporaire ; manifest antérieur utilisé pour distinguer la contribution de cette story.

Après revue : filtre de préférence globale retiré du ciblage, changement effectif de profil toujours invalidant ; déduplication partagée avant invalidation des frontières ; récupération SQLite marquée seulement après lecture réussie. Trois tests de régression ajoutés. Test visuel portable, thèmes stabilisés, couleurs vérifiées et captures régénérées. Inspection parent des captures et des correctifs réalisée. Sept groupes de remarques préexistantes sont différés dans `deferred-work.md` ; aucune correction 3.5 restante.

Des ajustements visuels concurrents ont été constatés pendant la revue et préservés. La suite globale et les deux APK finaux ont été vérifiés après ces changements. Le commit de clôture enregistre l’état fonctionnel de l’application avec la refonte utilisée comme base ; les brouillons de conception et anciennes captures d’échec restent hors commit.

## Spec Change Log

## Review Triage Log

| Source | Remarque | Verdict | Preuve et traitement |
|---|---|---|---|
| Blind 1 | Arrêt désactivé sur profil ouvert depuis accueil | medium | `HomeView.onOpen` ne sélectionne pas le profil global ; la conversation possède pourtant sa clé complète. Le nouveau filtre `selectedProfile == key.profile` bloque un contexte valide. Patch : supprimer ce filtre de préférence globale, conserver connexion/runtime/génération/tour et invalidation des changements reçus. |
| Blind 2 | Double encodage dans historyPath | false | Essai Dart exécuté avec espace, barre oblique et é : `Uri(path: ...)` conserve les échappements valides et `pathSegments.last` restitue exactement chaque identité. |
| Blind 3 | Accueil cliquable avant chargement | medium | `latest` vaut null pendant l’attente, mais onTap ouvre un brouillon. Code préexistant de la refonte ; différé, non causé par 3.5. |
| Blind 4 | Erreur de liste présentée comme historique vide | medium | `FutureBuilder` ignore hasError et affiche homeNoConversation. Code préexistant ; différé. |
| Blind 5 | Liste accueil sans actualisation | medium | `_latest` est un Future final sans reprise après échec pendant le montage. Code préexistant ; différé. |
| Blind 6 | Pastilles sans action sémantique | medium | excludeSemantics masque InkResponse sans onTap sur Semantics. Réglages préexistants ; différé. |
| Blind 7 | Choix couleur concurrents et rollback | medium | choose remet previous lors d’une ancienne écriture échouée, sans vérifier une sélection plus récente. Module préexistant inchangé selon le manifest ; différé. |
| Blind 8 | Identifiant long dans trailing ListTile | medium | profile.value est sans contrainte dans trailing ; une valeur assez longue épuise la largeur à 200 %. Réglages préexistants ; différé. |
| Blind 9 | Doublon terminal/début invalide un arrêt | medium | Les révisions sont incrémentées avant `_apply` et son rejet des seq déjà vues. Un début dupliqué fait passer une demande valide à inconnue. Patch : appliquer la même déduplication avant invalidation. |
| Blind 10 | Scripts de captures préexistants liés au poste | low | chat_demo_capture/grok_capture sont des scripts locaux préexistants, hors découverte automatique. Rejet : usage occasionnel et correction nécessitant de nouveaux paramètres ; ne bloque pas 3.5. |
| Edge 1 | Récupération marquée avant lecture SQLite | medium | `_stopRecovered.add` précède la requête ; après échec puis réouverture, l’intention persistée n’est plus relue. Patch : marquer après lecture réussie ; test d’échec/reprise. |
| Edge 2 | Accueil en chargement/erreur ouvre du neuf | medium | Même défaut vérifié que Blind 3/4, préexistant ; différé ensemble. |
| Edge 3 | Pastille sans activation lecteur d’écran | medium | Même défaut que Blind 6 ; préexistant, différé ensemble. |
| Edge 4 | Regroupement historique au changement d’heure | medium | historyBucket divise une durée locale de 23 h en jours au lieu de comparer les dates calendaires. Fonction préexistante ; différé. |
| Edge 5 | Chemin SDK absolu dans test automatique | medium | stop_flow_test charge les icônes depuis C:/Users/alanc/fvm/... ; test actif non portable. Patch : résoudre le SDK utilisé par le processus de test. |
| Edge 6 | Frontières dupliquées changent la cible | medium | Même défaut vérifié que Blind 9 ; patch commun. |
| Verification 1 | Persistance des accents sans test consommateur | medium | Recherche et mutation décrites par la revue ; seul le SQL de migration est testé. Surface préexistante inchangée ; différé. |
| Verification 2 | Famille outil sans test événement réel | medium | forTool testé directement, pas le branchement du repository sur un nom reconnu. Branche préexistante avant 3.5 selon existing.patch ; différé. |
| Parent visuel | Rappel peu contrasté après changement de thème dans captures | low | Les captures normal/sombre et confirmé/clair montrent la couleur héritée du thème précédent ; les widgets explicitement stylés ont déjà changé. Stabiliser les animations de thème avant capture et vérifier le contraste du rappel ; patch du test, puis captures régénérées. |

## Design Notes

La refonte préexistante ne contient aucune demande d’arrêt ; sa réutilisation est autorisée. Sans identité serveur de tour, le contrôle de session garantit vérification locale et absence de rejeu, sans supprimer les courses entre clients distants. Aucun effet externe nécessaire ; migration additive vérifiée sur base de test.

## Verification

Vérification finale parent du 24 octobre après corrections : analyse sans anomalie ; suite complète **346 tests
réussis, 17 ignorés, aucun échec**. Matrice, quatre captures de la vraie
`DraftView`, logs finaux et limites consignés dans
`story-3-5-verification/verification.md`. Migration additive v10 vérifiée avec
conservation d’un accent préexistant. APK debug application et galerie construits.
Les états locaux restent dans l’outbox ; seul le terminal reçu confirme l’arrêt.
À 200 % avec clavier, le pied de page défile et réserve 96 dp au fil. Hermes
personnel et TalkBack sur téléphone restent non vérifiés.

- `rtk proxy C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat analyze --no-pub` : aucune anomalie ajoutée.
- Tests ciblés puis suite Flutter ; APK debug application et galerie.
- Captures petit écran clair/sombre, clavier et texte 200 % ; distinguer ces preuves d’un essai téléphone/TalkBack et d’un test Hermes réel.
