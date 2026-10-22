---
title: 'Compagnon lapin — présence en haut des profils'
type: 'feature'
created: '2026-10-22'
status: 'done'
baseline_commit: '1daa7972c58bbfa971e6a869dfa91f3a1b3afb7e'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Le compagnon v5 est disponible dans la galerie mais absent de la surface métier des profils. Otc est le nom du compagnon ; les profils Hermes ont leurs propres libellés indépendants.

**Approche :** Ajouter en tête de la surface existante « Mes profils » un panneau pour le compagnon du profil sélectionné, réutilisant RabbitCompanion et son fond pastel fixe. Conserver les commandes métier et l’aperçu en galerie. Réconcilier le dossier UX avec la priorité de la v5 approuvée.

## Boundaries & Constraints

**Toujours :** Préserver le dessin v5, les réactions, le mouvement réduit immédiat et la suspension existante. Nom en vrai texte sur surface sémantique du thème, distinct de Profile.label, avec retour à la ligne à 200 %. Fond pastel fixe issu des tokens existants, silhouette entière à 180 pixels logiques. Repartir au repos lors d’un changement de profil ou de serveur. Proposer une commande de pause accessible pour la surface. Réserver un emplacement stable pendant un chargement avec sélection encore connue, sans exposer le libellé du profil précédent.

**Décision utilisateur :** Le compagnon se nomme Otc, indépendamment des noms des profils Hermes. Afficher Otc avec chaque profil sélectionné ne renomme ni n’attribue une identité Alanc à ces profils. Le nom du compagnon est une constante de présentation explicite, sans résolution serveur ni table de correspondance. Cette clarification remplace l’interprétation initiale « un nom de compagnon par profil » des documents UX.

**Jamais :** Inventer un champ serveur, détourner Profile.label ou déduire Alanc de isDefault ou d’un libellé. Aucun éditeur de fond, lien avec génération ou trois points, nouveau thème, nouvelle dépendance ou nouvel écran de détail de profil.

## I/O & Edge-Case Matrix

| Situation | Entrée / état | Résultat attendu | Traitement |
| --- | --- | --- | --- |
| Sélection connue | Profil présent dans la liste courante | Lapin en tête nommé Otc | Libellé du profil conservé séparément |
| Changement | Autre profil ou autre serveur | Otc conservé, profil courant actualisé, pose neutre | Aucune réaction ou ancien libellé transféré |
| Nom absent ou blanc | Nom du compagnon injecté dans un test de présentation | « Compagnon » visuel et accessible | Repli du composant, sans nouvelle donnée serveur |
| Nom long | Nom injecté ou libellé de profil long, texte 200 % | Texte intégral et commandes atteignables par défilement | Aucun chevauchement |
| Chargement | Sélection connue, actualisation | Enveloppe stable, Otc indépendant du réseau | Aucun libellé de profil périmé |
| Aucun profil | Liste vide ou aucune sélection vérifiable | États métier existants, aucun compagnon autonome | Pas de sélection inventée |
| Suspension | Hors viewport, route masquée, arrière-plan | Arrêt des cycles ; reprise neutre | Contrat RabbitCompanion conservé |

</frozen-after-approval>

## Code Map

- `lib/models/profile.dart` — seulement key, label, isDefault ; conserver ce modèle.
- `lib/data/hermes_adapter.dart:295` et `contracts/fixtures/profiles.json` — name/display_name/is_default uniquement ; fixtures synthétiques, aucun lien stable à Alanc.
- `lib/data/storage/connection_store.dart` — sélection locale par connexion ; aucun nom de compagnon.
- `lib/features/profiles/profiles_view.dart` — ListView sous SafeArea, statut serveur, commandes, ProfileChoice et capacités ; point d’intégration avant ces contenus.
- `lib/features/profiles/profiles_view_model.dart` — snapshot et sélection via ConnectionGateway ; profil courant à vérifier, aucune résolution de nom de compagnon nécessaire.
- `lib/ui/components/rabbit_companion.dart` — API name/size/active/paused ; suspension automatique route, viewport, TickerMode et lifecycle. Sous-vue masquée conservée : fournir active:false.
- `lib/ui/tokens.dart`, `lib/ui/content.dart`, `lib/ui/gallery.dart` — palette et dimensions RabbitTokens, textes de production séparés de GalleryContent, aperçu existant à préserver.
- `test/profiles_test.dart`, `test/support/connection_fakes.dart` — harness métier existant ; `test/rabbit_companion_test.dart` et `test/gallery_test.dart` assurent les régressions du lot 1.
- `_bmad-output/planning-artifacts/ux-designs/ux-Hermes Mobile-2026-10-22/` — DESIGN, EXPERIENCE, mockups/contextes.html : mentions taupe, v2 courante et dessin encore ouvert à corriger ou qualifier comme archives ; bitmap v5 inspecté et prioritaire.

## Tasks & Acceptance

**Exécution :**
- [x] `lib/features/profiles/profiles_view.dart` — vérifier la présence du profil sélectionné dans le snapshot courant, sans heuristique de libellé ni résolution du nom d’Otc.
- [x] `lib/features/profiles/profiles_view.dart` et composant de présentation sous `lib/ui/components/` si nécessaire — panneau initial, nom séparé et pause ; conserver navigation et actions.
- [x] `lib/ui/content.dart` et `lib/ui/tokens.dart` si nécessaire — centraliser textes et réglages de présentation.
- [x] `test/profiles_test.dart` — vérifier sélection, serveur, absence et longueur du nom, états vide/chargement, pause et suspension.
- [x] Dossier UX du 22 octobre — réconcilier les contradictions historiques dans DESIGN/EXPERIENCE, y compris le nom Otc indépendant des profils selon la clarification utilisateur ; qualifier contextes.html d’étude ancienne sans retoucher les images archivées.

**Critères d’acceptation :**
- Étant donné un profil sélectionné, quand la surface s’ouvre, alors le compagnon apparaît avant les autres contenus, avec son nom distinct du libellé métier.
- Étant donné les thèmes clair et sombre et le texte à 200 %, quand on affiche un nom long sur téléphone et en paysage, alors aucun débordement n’apparaît et toutes les commandes restent accessibles.
- Étant donné le lot 1, quand on chatouille le lapin, active le réglage système de mouvement réduit ou masque la surface, alors ses règles de réaction et de suspension restent effectives et la galerie demeure disponible.
- Étant donné les documents UX, quand on lit les références visuelles, alors v5 est prioritaire et les études antérieures ne rouvrent pas le dessin validé.

## Implementation Notes

Investigation : aucun contrat de nom ni identité de profil Alanc disponible ; backend personnel non contacté. Arbre initial propre, dernier commit : lot 1. La branche historique contient les stories successives et ce lot 1. Aucun effet irréversible prévu ; empreinte limitée à la surface profils, sa résolution de présentation, ses tests et le dossier UX.

Implémentation : panneau ProfileCompanionPanel, constante Content.companionName, clé de panneau par connexion/profil et maintien de sélection vérifiée au chargement. RabbitCompanion et galerie inchangés. UX réconciliée avec v5 et Otc indépendant des profils.

Vérifications : analyse sans anomalie, 237 tests réussis, APK debug application et galerie construits. Matrice couverte par les cinq tests profils et les régressions RabbitCompanion/galerie exécutées. Captures inspectées : clair normal, sombre 200 %, nom long paysage 200 % ; oreilles entières et aucun chevauchement. Voir [captures et limites](lot2-visuals/README.md). Pas de vérification sur appareil réel.

## Spec Change Log

## Review Triage Log

| Revue | Verdict | Évidence / traitement |
| --- | --- | --- |
| Chasseur aveugle — statut non cohérent avec livraison | false | `in-review` correspond à l’étape courante du workflow après exécution et avant acceptation. Gardé pendant la revue. |
| Chasseur aveugle — journaux vides malgré clarification | low, patch | La clarification Otc a modifié la décision avant implémentation ; consigner son effet ici pour préserver sa provenance. |
| Chasseur aveugle — preuve nom long du profil absente des captures | false | Le test de widget couvre le libellé métier long ; les captures documentent uniquement le nom de compagnon long. README précisé. |
| Chasseur aveugle — métadonnées captures incomplètes | low, patch | Ajout de la date, version Flutter, tailles et échelle de texte au README des preuves. |
| Chasseur aveugle — formulation laissant v4 comme support courant | low, patch | Reformulée comme historique, v5 reste l’unique dessin approuvé. |
| Chasseur aveugle — sections historiques mêlées au contrat | false | Le contrat courant en tête établit explicitement la priorité v5 et qualifie le contenu suivant d’études historiques ; les passages ambigus ont été corrigés au lot. |
| Chasseur aveugle — frontière dessin / animations floue | false | Le contrat courant distingue le dessin v5 des interactions et suspension déjà portées par lot 1 ; la présente intégration n’ajoute pas de chorégraphie. |
| Chasseur aveugle — formulation mouvement réduit | low, patch | Critère précisé comme réglage système de mouvement réduit. |
| Chasseur de cas limites | false | Aucun défaut reporté. |
| Revue des lacunes de vérification | false | Aucune lacune de vérification reportée. |

## Spec Change Log

- Clarification utilisateur avant approbation : Otc est le nom constant du compagnon, les profils gardent leurs libellés distincts. La spec et le contrat UX enregistrent ce choix sans identité Alanc déduite ni champ serveur.

## Verification

- `flutter analyze` — aucune anomalie.
- `flutter test test/profiles_test.dart test/rabbit_companion_test.dart test/gallery_test.dart test/visual_literals_test.dart` puis suite complète — succès.
- Build debug application et galerie selon outils disponibles ; inspection visuelle du panneau clair/sombre/200 % et comparaison avec la v5.
