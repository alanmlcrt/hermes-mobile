# Réalisation et acceptation — 7.5 — Supprimer une conversation

## Provenance et état réel

Exigences reprises de `../../../EPIC-7-REFERENCE.md`, section de cette story. Ce document est un extrait provisoire, non intégré au plan de master. La spec 7.1 existe dans `../../implementation-artifacts/spec-7-1-verifier-rangement-recherche.md` et reste en attente de validation. Cette rédaction ne valide aucune capacité ni dépendance.

## Conditions de démarrage

- 7.1 : session.delete, identifiant stocké, réponse positive et preuve permettant de trancher une réponse perdue.
- Epic 6 : états de travail/intervention, opérations non résolues, brouillons/pièces et routage des notifications.
- 7.3 : propriétaire et schéma des marqueurs ; 7.4 : inclure la section masquée dans la réconciliation si intégrée.

Avant de passer en ready-for-dev : vérifier ces prérequis, remplacer les chemins proposés par les chemins réellement intégrés, confirmer les choix ci-dessous et faire approuver la spec dans bmad-build. Si une dépendance manque, conserver draft et documenter le manque ; ne pas créer une seconde implémentation concurrente.

## Cartographie de la base

- `../../../lib/main.dart` : squelette Flutter observé ; les couches ciblées ci-dessous sont à intégrer ou à retrouver après epic 6.
- `../../../lib/data/README.md`, `../../../lib/models/README.md`, `../../../lib/features/README.md` : frontières des responsabilités.
- `../../../contracts/README.md` : contrat installé à enrichir par 7.1 ; ne pas prendre les schémas amont pour preuves.
- `../../../pubspec.yaml` : HTTP, WebSocket, SQLite et routage déjà déclarés ; aucune dépendance nouvelle décidée par cette spec.

## Choix de réalisation proposés

- Créer un état persistant de suppression en attente/inconnue et conserver la clé complète. Recharger cet état après redémarrage.
- Coordonner ConversationRepository et OutboxRepository dans la file par session : vérifier activité et envois, réserver la suppression, bloquer un nouvel envoi puis appeler Hermes. Un refus du serveur conserve tout.
- Après accusé positif, enregistrer un tombstone local puis effectuer le nettoyage idempotent. Une panne pendant le nettoyage doit permettre de reprendre sans rappeler session.delete.
- Le tombstone ne contient pas le contenu supprimé. Il permet de reconnaître la cible d’une notification tardive et de ne pas recréer le fil.
- Pour un résultat inconnu, réconcilier par la méthode de preuve retenue en 7.1. Sans preuve définitive, garder l’état « à vérifier » et toutes les données ; ne pas inventer de garantie de cohérence.
- Si une nouvelle exécution apparaît pendant la vérification, refuser la suppression et expliquer qu’il faut arrêter puis attendre la confirmation.

## Tâches ordonnées

- [ ] `lib/data/hermes/hermes_rpc.dart` — Exposer la suppression vérifiée et ses erreurs, sans politique de répétition automatique.
- [ ] `lib/data/repositories/conversation_repository.dart` — Coordonner la commande par session, la confirmation, l’incertitude et le tombstone avec OutboxRepository.
- [ ] `lib/data/repositories/outbox_repository.dart` — Fournir la garde atomique contre les envois et le nettoyage idempotent des brouillons/pièces appartenant au fil.
- [ ] `lib/data/storage/conversation_deletion_store.dart` — Persister l’état de suppression et le tombstone via migration en ajout seul à réconcilier avec la base intégrée.
- [ ] `lib/features/history/delete_conversation_dialog.dart` — Afficher conséquence définitive, confirmation, blocage et résultat à vérifier sans retrait anticipé.
- [ ] `lib/app/router.dart` — Résoudre une notification visant un tombstone vers l’accueil et le message « conversation supprimée ».
- [ ] `test/data/conversation_deletion_test.dart` — Tester courses, refus, timeout, redémarrage et reprise du nettoyage sans second appel distant.
- [ ] `test/app/deleted_conversation_notification_test.dart` — Tester les liens tardifs et l’isolation entre profils/connexions.

Les chemins des tâches sont relatifs à la racine du projet et sont des cibles proposées. Étendre les propriétaires existants après intégration, sans créer de repository, route ou migration en doublon.

## Critères d’acceptation

- **AC-1** — Étant donné un fil sans travail ni envoi non résolu, quand Alanc choisit « Supprimer » puis confirme, alors la conséquence définitive sur Hermes est annoncée, un seul appel part et la ligne reste jusqu’au succès.
- **AC-2** — Étant donné le dialogue de confirmation, quand Alanc annule, alors aucune requête et aucun nettoyage ne surviennent.
- **AC-3** — Étant donné un travail actif ou un envoi incertain, quand la suppression est demandée ou confirmée après changement d’état, alors elle est refusée avec une explication, sans interrompre implicitement le travail.
- **AC-4** — Étant donné une réponse positive, quand le nettoyage aboutit, alors brouillon, copies privées de pièces, épingle et marqueur de ce fil sont effacés sans toucher aux autres.
- **AC-5** — Étant donné une coupure pendant l’appel, quand le résultat est inconnu puis l’app redémarre, alors le fil reste à vérifier et les données sont conservées jusqu’à preuve définitive, sans rejeu automatique.
- **AC-6** — Étant donné une réponse positive suivie d’une panne locale, quand l’app reprend, alors le nettoyage reprend à partir du tombstone sans seconde suppression serveur.
- **AC-7** — Étant donné un fil supprimé, quand une notification de fin tardive est ouverte, alors l’accueil affiche « conversation supprimée », sans erreur ni recréation du fil.
- **AC-8** — Étant donné une liste incomplète, quand la session n’y apparaît pas, alors cela ne déclenche aucun nettoyage local.
- **AC-9** — Étant donné un lecteur d’écran actif, quand le dialogue est parcouru, alors la conséquence irréversible, les choix et le blocage sont annoncés clairement.

## Vérification attendue

- Exécuter `rtk proxy fvm flutter analyze` et `rtk proxy fvm flutter test` après implémentation ; tester chaque critère dans les fichiers ciblés.
- Vérifier sur téléphone Android : texte agrandi, clavier, lecteur d’écran, retour au bon profil et redémarrage. Les tests simulés ne prouvent pas la compatibilité de Hermes installé.
- Pour toute action distante, utiliser le profil et les sessions dédiés qualifiés en 7.1 ; vérifier les effets depuis un autre client sans toucher aux essais epic 6.
- Consigner résultats, limites et éventuels blocages avant de déclarer la story terminée. Aucun test de code ni essai serveur n’a été exécuté pendant cette rédaction.
