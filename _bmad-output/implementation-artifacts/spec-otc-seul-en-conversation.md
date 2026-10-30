---
title: 'Otc seul comme compagnon animé en conversation'
type: 'bugfix'
created: '2026-10-23'
status: 'done'
route: 'oneshot'
baseline_commit: '89943688bfbf9de36162d710c7acb1f8cea0b74f'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="intention explicitement précisée par Alanc">

## Intent

Alanc souhaite Otc seul pendant le travail, avec les animations antérieurement approuvées : regards au repos, chatouilles locales, concentration au démarrage confirmé, regard vers le texte reçu et retour au repos. Masquer les petites illustrations des lignes d’activité dans la conversation réelle et son aperçu de galerie, sans réserver leur emplacement vide. Conserver les libellés, détails dépliables, fins reçues, statut accessible et comportement d’Otc. Le catalogue développeur isolé reste disponible comme référence. Aucun réglage ni manipulation du téléphone n’est demandé ici.

</frozen-after-approval>

## Implementation Notes

Choix de route : intention résolue par la clarification utilisateur et les contrats des lots 1/2/4 ; aucune opération irréversible. Correction locale : option de rendu dans `lib/ui/components/activity_line.dart`, désactivation dans `lib/features/conversation/draft_view.dart` et `ConversationCompanionPreview` de `lib/ui/gallery.dart`. Conserver le rendu illustré dans le catalogue développeur. Adapter la régression de conversation qui attendait les petits peintres, ajouter une assertion d’absence d’illustration tout en préservant les poses et détails ; actualiser les contrats UX courants sans modifier les anciennes specs figées. Vérifier analyse, tests pertinents et suite complète.

Implémentation : `showIllustration: false` supprime le dessin et son espacement dans les deux surfaces de conversation. Le catalogue isolé garde le rendu illustré. `RabbitCompanion`, les poses, le mapping serveur et les commandes de détail ne changent pas. Les contrats DESIGN/EXPERIENCE courants enregistrent la priorité de cette clarification.

Vérification : analyse sans anomalie ; suite complète de 346 tests verte. Tests de détails par clavier/focus et matrice 320 px/200 % exécutés dans `action_details_page_test.dart` via `support/details_capture.dart`. Régression dédiée sans colonne réservée dans `activity_line_test.dart`. Assertions supplémentaires après ouverture, fin reçue et changements de pose ajoutées après revue.

Clôture : les 15 tests de détails/galerie puis le scénario de conversation ciblé ont passé avec les assertions de revue. Build release signé numéro 5 réussi (137 s), conservé dans `build/app/outputs/flutter-apk/hermes-otc-seul-build5.apk`. Aucun élément différé. Aucun nouvel accès au téléphone ni installation depuis la demande d’arrêt des manipulations.

## Review Triage Log

| Remarque | Verdict | Preuve et traitement |
|---|---|---|
| 1 — Détails, chevron et focus non testés sans illustration | false | `action_details_page_test.dart` monte le vrai `DraftView`, qui passe désormais `showIllustration: false`. Le test clavier demande le focus, active avec Entrée et vérifie son maintien lors des mises à jour ; la matrice de `support/details_capture.dart` vérifie aussi l’expansion et le contenu. Ces tests ont passé dans les 346 tests. |
| 2 — Mise en page dépliable sans couverture étroite/agrandie | false | La même matrice ouvre les détails à 320 px et texte 200 %, avec clavier et les deux thèmes. Le titre commun aux branches statique et dépliable est construit sans dessin ni espacement ; le nouveau test d’alignement protège cette suppression. |
| 3 — Absence d’illustration non affirmée après détails/fin | low | La matrice couvre déjà les transitions et la fin accessible ; des assertions explicites `findsNothing` sont ajoutées après ouverture et enrichissement pour verrouiller le nouveau choix. Patch. |
| 4 — Aperçu testé sans illustration seulement au départ | low | La branche de rendu est constante, mais les assertions après démarrage, texte, chatouilles/terminal et retour de suspension renforcent utilement la régression. Patch. |
