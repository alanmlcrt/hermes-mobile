---
title: 'Alléger la sélection de fichiers sans afficher les limites en Mo'
type: 'chore'
created: '2026-10-26'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
baseline_commit: '56e66c3264a58cffb31da9b863598d315975aeb1'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

Retirer les plafonds en Mo de l’interface de sélection des pièces jointes. Conserver les formats et les actions Photos/Fichiers dans les composants existants. En cas de taille excessive, afficher un refus simple sans seuil numérique. Les validations mesurées restent appliquées ; la taille réelle d’une pièce sélectionnée n’est pas un plafond et reste disponible.

</frozen-after-approval>

## Implementation Notes

Changement local, réversible, sans migration ni effet externe. Retirer les lignes de plafond dans `lib/ui/components/attachment_list.dart`, simplifier le libellé de refus dans `lib/ui/content.dart` et sa sélection dans `lib/features/conversation/draft_view_model.dart`. Adapter le test de parcours existant dans `test/attachment_flow_test.dart` et réutiliser ses variantes clair/sombre, portrait/paysage et texte à 200 %. Conserver les contrôles métier et les contrats.

Implémentation : plafonds retirés, refus de taille sans seuil numérique, message générique harmonisé. Les éventuels nombres maximums de pièces sont associés à leur catégorie, avec singulier correct. Les tailles réelles des pièces restent inchangées. Aucun changement de contrat ou de seuil métier.

Vérification : `flutter test --no-pub test/attachment_flow_test.dart test/attachment_store_test.dart` : 19 réussis ; `flutter analyze --no-pub` : aucune anomalie. Le parcours teste l’absence de plafond, le refus avec et sans limites chargées, l’erreur provenant du sélecteur, le retrait, les permissions et les variantes adaptatives.

## Review Triage Log

| ID | Verdict | Preuve et décision |
| --- | --- | --- |
| B1 | low | Le retrait du libellé de catégorie rend un nombre maximum non nul ambigu. Correction directe : catégorie conservée auprès du nombre, test Photos/PDF avec nombres différents et absence de seuil de taille. Patch terminé. |
| B2 | medium | `Content.error('attachment.size')` renvoie encore à une limite affichée, utilisé par erreur du sélecteur ou état de pièce. Réutilisation du refus simple et test de l’erreur du sélecteur. Patch terminé. |
| B3 | medium | L’assertion utilisant le seul libellé de production ne détecterait pas un seuil réintroduit dans ce libellé. Assertions indépendantes sur chiffres/unités, avec et sans limites chargées. Patch terminé. |

Revue courte terminée, aucun constat différé.

Compilation : `flutter build apk --release --build-number 15 --no-pub` réussie ; APK release de 53,4 Mo. Avertissement de compilation préexistant sur la police Cupertino, sans échec de compilation.
