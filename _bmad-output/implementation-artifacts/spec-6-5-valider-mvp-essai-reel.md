---
title: 'Story 6.5 — Valider le MVP par un essai réel'
type: 'chore'
created: '2026-10-30'
status: 'done'
baseline_commit: 'ecbedeeac543f8cf874e1e204ddc3b1a948022ac'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/story-5-5-verification/rapport-g3.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Les stories sont implémentées, mais aucun essai global sur le téléphone d'Alanc ne démontre l'acceptation du MVP. G3 reste ouverte.

**Approche :** Installer une release du code courant, dérouler les parcours sur le téléphone et Hermes réels, recueillir les preuves et rédiger un verdict traçable. Alanc réalise les gestes et confirme les observations ; l'agent prépare, installe par ADB et rapproche les preuves serveur.

## Boundaries & Constraints

**Toujours :** Annoncer chaque installation et action externe avant exécution. Alanc installe le plugin et redémarre Hermes ; accès Samba de l'agent en lecture seule. Identifier révision, APK, version du plugin, build Hermes et dates UTC. Utiliser deux profils existants (`default` et `mesure-pieces-jointes`) et des conversations dédiées à l'essai. Conserver uniquement des preuves expurgées : aucun secret, contenu personnel ni identifiant complet. Séparer preuves historiques et nouveaux constats. Toute indisponibilité ou dérogation figure au rapport ; seul Alanc peut retirer ou reporter un contrôle obligatoire.

**Jamais :** Accepter le MVP sur des fixtures, tests automatisés ou un simple upload réussi. Déclarer une notification reçue sur la seule réponse FCM 200. Rejouer automatiquement un envoi incertain. Effacer les données de l'app, changer le mode d'autorisation ou corriger silencieusement la configuration serveur.

## I/O & Edge-Case Matrix

| Scénario | Entrée / action | Preuve attendue | Écart |
|---|---|---|---|
| Démarrage et profils | Ouvrir l'app normalement, choisir deux profils | Nouvelle conversation par défaut, profils sans configuration manuelle, échanges et historiques séparés | Bloquant si non constaté |
| Corpus 4.1 | Envoyer texte long, image, PDF et DOCX depuis le téléphone | Réception dans le bon fil côté Hermes, volume et format ; réception distincte de l'analyse | Upload seul insuffisant |
| Travail | Déplier une action puis arrêter un travail | Détail lisible et état arrêté confirmé par Hermes | Demande locale insuffisante |
| Interventions | Répondre à `clarify`, autoriser puis refuser une action de test sans danger | Réponse et décisions prises en compte par Hermes | Capacité non démontrée signalée |
| Résultat | Faire écrire un fichier, télécharger puis ouvrir ; couper le réseau avant un autre téléchargement | Copie ouverte par l'application adaptée ; échec visible et réessayable | Aucun faux succès |
| Notification | Envoyer puis quitter l'app, toucher la notification | Réception constatée et bon fil ouvert, avec journal corrélé | G3 ouverte sans preuve suffisante |
| Résilience | Brouillon conservé pendant coupure/reconnexion ; coupure après envoi | Texte et pièces conservés ; compteur d'exécutions serveur corrélé aux envois volontaires | Toute incertitude reste explicite |
| Accessibilité | Refaire les parcours essentiels avec TalkBack, texte 200 % et clavier affiché | Actions nommées, accessibles et visibles, sans débordement | Contrôle manquant bloquant |

**Retour d'Alanc pendant l'essai :** Les quatre types de fichiers sont lus. L'affichage des documents joints montre trop d'informations et prend trop de place ; corriger cette ergonomie en conservant le sélecteur natif.

**Décision d'Alanc (2026-10-30, consignée à 16:46:50Z) :** « marque comme terminé, je voudrais ensuite passer au dev de l'epic 7 ». Clôturer la story 6.5 et reporter les contrôles restants, y compris le rejeu ergonomique +24 et les corrélations serveur. Cette décision autorise la poursuite vers l'epic 7 ; elle ne constitue pas une preuve de réussite des essais non joués et ne ferme pas G3.

</frozen-after-approval>

## Code Map

- `lib/ui/components/attachment_list.dart`, `lib/features/conversation/draft_view.dart`, `lib/ui/content.dart`, `lib/ui/tokens.dart` — correctif demandé pendant M02 : résumé compact des pièces jointes (icône/aperçu, nom et taille, retrait accessible ≥48 dp) ; retirer le MIME brut et l'état local routinier de l'affichage principal, préserver progression, erreurs, réessai et sémantique des états. Conserver le nom complet accessible malgré ellipse visuelle. Éviter que plusieurs pièces poussent la saisie hors écran avec le clavier ; limiter la hauteur du bloc si nécessaire avec défilement accessible. Ne modifier ni transport, ni stockage, ni sélection native. Mettre les détails secondaires sur demande seulement si nécessaires.

- `README.md`, `.fvmrc`, `pubspec.yaml` — construction release signée ; relever la version installée avant de choisir un versionCode supérieur.
- `contracts/README.md` — G4 fermée, FR13/14 retenus ; `clarify`, `approval`, `write_file` et téléchargement authentifié déjà implémentés.
- `tool/mesure_pieces_jointes.dart`, `contracts/file-limits.json`, `corpus-pieces-jointes/README.md` — corpus 4.1 synthétique et réception serveur ; ne pas relancer la campagne complète pour remplacer le parcours mobile.
- `server/hermes-plugin/README.md`, `story-5-5-verification/rapport-g3.md`, `deferred-work.md` — plugin requis ≥ 1.0.2, écarts G3 existants à conserver et rapprocher du nouvel essai.
- `spec-6-4-recuperer-fichiers-produits-hermes.md` — résultats persistés localement ; un snapshot peut perdre les cartes, limite à relever si rencontrée.
- `_bmad-output/planning-artifacts/architecture/architecture-Hermes Mobile-2026-10-20/ARCHITECTURE-SPINE.md`, `contracts/release.json` — portes et acceptation globale ; aucune clôture sans preuve.

## Tasks & Acceptance

**Exécution :**
- [ ] `lib/ui/components/attachment_list.dart`, `lib/features/conversation/draft_view.dart`, `lib/ui/content.dart`, `lib/ui/tokens.dart` si nécessaire, tests widgets de pièces jointes — rendre le bloc compact et vérifier états, retrait/réessai, nom accessible, clavier et texte 200 %, clair/sombre et largeur mobile ; construire puis annoncer et installer la release +24 pour le rejeu d'Alanc.
- [x] `_bmad-output/implementation-artifacts/story-6-5-verification/protocole.md` — ordonner les gestes, preuves et contrôles de la matrice ; intégrer les écarts G3 et préparer des demandes sans danger.
- [ ] `story-6-5-verification/rapport-mvp.md` (même dossier) — relever les prérequis, construire puis installer la release sans perte de données ; consigner chaque essai avec preuve, date et statut (réussi, échoué, non joué ou dérogation explicite).
- [ ] `story-6-5-verification/` — joindre les preuves expurgées des scénarios et des limites ; aucune simulation comptée comme essai réel.
- [ ] `ARCHITECTURE-SPINE.md`, `contracts/release.json`, `deferred-work.md` aux chemins ci-dessus — rapprocher le verdict des portes, maintenir les blocages et ne clore que les reports démontrés.

**Critères d'acceptation :**
- Étant donné l'essai réel, quand le rapport est relu, alors chaque ligne de la matrice possède un résultat et une preuve, ou une indisponibilité expliquée.
- Étant donné les envois et brouillons contrôlés, quand les traces sont rapprochées, alors aucune duplication ni perte n'est observée ; sinon le verdict reste non accepté.
- Étant donné un contrôle obligatoire manquant ou échoué, quand le verdict est établi, alors le MVP reste non accepté sauf retrait ou report explicite d'Alanc consigné au rapport.

## Implementation Notes

- Clôture à la demande explicite d'Alanc le 2026-10-30 (16:46:50Z). Les cases non cochées ci-dessus désignent les vérifications reportées, pas du développement restant dans cette story clôturée. Le rapport et les reports consignent la décision. Aucun nouveau test ni verdict technique global revendiqué. Le checkpoint de revue final de la 6.5 n'a pas été exécuté avant cette clôture demandée.

- Correctif ergonomique demandé pendant M02 : pièces compactes, taille courte, retrait en ligne, nom complet accessible, hauteur bornée avec défilement visible ; sélecteur natif et transport inchangés. Analyse réussie, suite complète 618 réussis / 17 ignorés avant dernier ajustement puis 13 tests ciblés réussis. Rendus inspectés ; release +24 construite et installée, version relue le 2026-10-30 à 16:42:07Z. [Preuves du correctif](story-6-5-verification/ergonomie-pieces-jointes.md). Rejeu humain encore attendu avant clôture de la tâche.

- Correctif M02 préparé pour +24 : résumé compact nom/taille, retrait 48 dp, nom complet et état local dans la sémantique, états importants/réessai conservés ; zone pièces bornée et défilante avec Scrollbar, marge avant saisie et saisie de deux lignes visibles avec pièces. Transport, stockage et sélection native inchangés. Analyse et tests ciblés réussis ; rendus synthétiques et limites dans `story-6-5-verification/ergonomie-pieces-jointes.md`. Build et installation +24 repris par le coordinateur après vérification ; aucun verdict réel clos.

- 2026-10-30 : protocole et rapport provisoire créés, avec les huit lignes de la matrice et tous les écarts G3 conservés. Aucun parcours réel encore validé ; MVP non accepté, G3 ouverte, story en cours.
- Analyse Flutter et tests réussis (616 réussis, 17 ignorés), release signée 0.1.0+23 construite et installée après annonce par `adb install -r`, version relue à 16:21:21Z. Quatre pièces synthétiques 4.1 transférées après annonce pour sélection mobile ; contrôles SHA-256 identiques. Détails dans `story-6-5-verification/preuves-techniques.md`.
- Lecture health/Samba annoncée et en lecture seule : Hermes 0.22.2+1690, fichiers plugin 1.0.2 identiques au dépôt pour default, absents de mesure-pieces-jointes à 16:19:20Z. Chargement/redémarrage à confirmer par Alanc ; aucune configuration serveur modifiée.
- Suite : gestes et constats d'Alanc puis corrélation des seuls fils d'essai ; ne clore ni reports ni acceptation à partir des prérequis techniques.

## Spec Change Log

- Retour humain M02 : lecture des quatre formats réussie, mais encombrement des pièces jointes jugé inacceptable. Alanc demande de revoir la présentation après sélection ; correctif ajouté au périmètre 6.5, sélecteur natif conservé. Le défaut est visuel, sans modification des règles de réception des fichiers.

## Review Triage Log

## Verification

- `rtk proxy adb devices -l` — téléphone connecté et autorisé avant installation.
- Analyse Flutter, tests et build release via FVM — prérequis techniques, sans valeur d'acceptation réelle.
- Vérification du rapport : couverture complète de la matrice, liens de preuves valides, absence de secrets, verdict cohérent avec les portes.
