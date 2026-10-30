# Réalisation et acceptation — 7.2 — Renommer une conversation

## Provenance et état réel

Exigences reprises de `../../../EPIC-7-REFERENCE.md`, section de cette story. Ce document est un extrait provisoire, non intégré au plan de master. La spec 7.1 existe dans `../../implementation-artifacts/spec-7-1-verifier-rangement-recherche.md` et reste en attente de validation. Cette rédaction ne valide aucune capacité ni dépendance.

## Conditions de démarrage

- 7.1 : méthode de titre, paramètres, types d’identifiants, confirmation et erreurs vérifiés sur installation.
- Epic 6 intégré : adaptateur, repository de conversations, historique et sélection de profil disponibles.

Avant de passer en ready-for-dev : vérifier ces prérequis, remplacer les chemins proposés par les chemins réellement intégrés, confirmer les choix ci-dessous et faire approuver la spec dans bmad-build. Si une dépendance manque, conserver draft et documenter le manque ; ne pas créer une seconde implémentation concurrente.

## Cartographie de la base

- `../../../lib/main.dart` : squelette Flutter observé ; les couches ciblées ci-dessous sont à intégrer ou à retrouver après epic 6.
- `../../../lib/data/README.md`, `../../../lib/models/README.md`, `../../../lib/features/README.md` : frontières des responsabilités.
- `../../../contracts/README.md` : contrat installé à enrichir par 7.1 ; ne pas prendre les schémas amont pour preuves.
- `../../../pubspec.yaml` : HTTP, WebSocket, SQLite et routage déjà déclarés ; aucune dépendance nouvelle décidée par cette spec.

## Choix de réalisation proposés

- Normaliser les espaces de début/fin pour comparer et envoyer le titre ; conserver le texte saisi pendant la correction. Une saisie composée d’espaces est vide.
- Sérialiser les mutations par session ; bloquer une deuxième validation pendant la première requête. Annuler le dialogue sans validation ne transmet rien.
- Un changement de profil pendant la requête ne change jamais sa cible. Une réponse ancienne ne remplace pas la projection d’une autre session.
- Après timeout, proposer une actualisation pour vérifier le résultat avant une nouvelle tentative explicite ; ne pas annoncer un succès à partir du seul délai écoulé.

## Tâches ordonnées

- [ ] `lib/data/hermes/hermes_rpc.dart` — Étendre l’adaptateur existant avec la méthode et les identifiants validés en 7.1 ; traduire absence, refus et erreur réseau.
- [ ] `lib/data/repositories/conversation_repository.dart` — Ajouter la commande de renommage sérialisée ; ne publier le nouveau titre qu’après confirmation puis réconcilier au prochain snapshot.
- [ ] `lib/features/history/rename_conversation_dialog.dart` — Ajouter la saisie initialisée au titre courant, validation, progression, annulation et conservation de la saisie en erreur.
- [ ] `lib/features/history/history_view_model.dart` — Relier le menu de la ligne à sa clé complète ; exposer capacité, erreur et état de validation sans appel réseau dans la vue.
- [ ] `test/features/history/rename_conversation_test.dart` — Couvrir les critères ci-dessous avec transport contrôlé et widgets accessibles.

Les chemins des tâches sont relatifs à la racine du projet et sont des cibles proposées. Étendre les propriétaires existants après intégration, sans créer de repository, route ou migration en doublon.

## Critères d’acceptation

- **AC-1** — Étant donné une conversation visible et une capacité validée, quand Alanc valide « Projet vacances », alors une requête vise sa clé exacte et le titre change uniquement après confirmation.
- **AC-2** — Étant donné un titre courant « Projet », quand Alanc valide une saisie vide, composée d’espaces ou identique après retrait des espaces externes, alors aucune requête ne part.
- **AC-3** — Étant donné un dialogue ouvert, quand Alanc annule ou valide deux fois rapidement, alors l’annulation n’envoie rien et la double validation produit au plus une requête en cours.
- **AC-4** — Étant donné un refus ou une panne, quand le renommage échoue, alors l’ancien titre reste affiché, la saisie est conservée et une erreur compréhensible permet de réessayer explicitement.
- **AC-5** — Étant donné une réponse perdue, quand le résultat devient incertain, alors aucun rejeu automatique ne survient et une actualisation permet de vérifier le titre distant.
- **AC-6** — Étant donné un titre changé sur Desktop, quand l’historique est actualisé, alors le titre distant apparaît, sans toucher aux autres profils.
- **AC-7** — Étant donné une capacité absente, quand le menu est présenté, alors la fonction indisponible est expliquée sans appel de contournement.
- **AC-8** — Étant donné un lecteur d’écran et le clavier affiché, quand Alanc ouvre puis ferme le dialogue, alors champ, erreur et boutons sont nommés, le focus revient à la conversation et le texte agrandi reste utilisable.

## Vérification attendue

- Exécuter `rtk proxy fvm flutter analyze` et `rtk proxy fvm flutter test` après implémentation ; tester chaque critère dans les fichiers ciblés.
- Vérifier sur téléphone Android : texte agrandi, clavier, lecteur d’écran, retour au bon profil et redémarrage. Les tests simulés ne prouvent pas la compatibilité de Hermes installé.
- Pour toute action distante, utiliser le profil et les sessions dédiés qualifiés en 7.1 ; vérifier les effets depuis un autre client sans toucher aux essais epic 6.
- Consigner résultats, limites et éventuels blocages avant de déclarer la story terminée. Aucun test de code ni essai serveur n’a été exécuté pendant cette rédaction.
