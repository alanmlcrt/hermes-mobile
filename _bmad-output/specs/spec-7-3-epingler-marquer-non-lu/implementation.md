# Réalisation et acceptation — 7.3 — Épingler et marquer non lu

## Provenance et état réel

Exigences reprises de `../../../EPIC-7-REFERENCE.md`, section de cette story. Ce document est un extrait provisoire, non intégré au plan de master. La spec 7.1 existe dans `../../implementation-artifacts/spec-7-1-verifier-rangement-recherche.md` et reste en attente de validation. Cette rédaction ne valide aucune capacité ni dépendance.

## Conditions de démarrage

- Epic 6 : snapshots de conversations, identités stables de tours/événements terminaux et déduplication réellement disponibles.
- 7.1 : sémantique des listes et des conversations masquées connue avant tout nettoyage ; la préparation du stockage local peut avancer séparément.

Avant de passer en ready-for-dev : vérifier ces prérequis, remplacer les chemins proposés par les chemins réellement intégrés, confirmer les choix ci-dessous et faire approuver la spec dans bmad-build. Si une dépendance manque, conserver draft et documenter le manque ; ne pas créer une seconde implémentation concurrente.

## Cartographie de la base

- `../../../lib/main.dart` : squelette Flutter observé ; les couches ciblées ci-dessous sont à intégrer ou à retrouver après epic 6.
- `../../../lib/data/README.md`, `../../../lib/models/README.md`, `../../../lib/features/README.md` : frontières des responsabilités.
- `../../../contracts/README.md` : contrat installé à enrichir par 7.1 ; ne pas prendre les schémas amont pour preuves.
- `../../../pubspec.yaml` : HTTP, WebSocket, SQLite et routage déjà déclarés ; aucune dépendance nouvelle décidée par cette spec.

## Choix de réalisation proposés

- L’ordre d’épinglage est croissant : la première épingle reste la première ; réépingler après retrait ajoute en fin du groupe. Conserver l’ordre existant pour les fils non épinglés.
- Enregistrer une séquence locale monotone d’épinglage et un curseur de dernière fin consultée avec le marqueur manuel, sans dépendre de l’horloge serveur.
- L’ouverture marque l’état présent comme lu ; une nouvelle fin survenant ensuite rétablit non lu tant qu’elle n’est pas effectivement consultée. Ne pas utiliser le seul fait que la route soit montée en arrière-plan.
- Un replay ancien ou dupliqué ne rétablit pas non lu. Si l’identité d’une fin n’est pas établie, conserver l’incertitude plutôt qu’inventer une nouveauté.
- Le stockage des marqueurs appartient à ConversationRepository, avec migration en ajout seul et transaction locale. Un échec d’écriture est expliqué, sans annoncer une persistance acquise.

## Tâches ordonnées

- [ ] `lib/models/conversation_markers.dart` — Définir les marqueurs immuables et leur identité complète, hors Flutter.
- [ ] `lib/data/storage/conversation_markers_store.dart` — Ajouter le stockage transactionnel et une migration compatible avec le schéma réellement intégré ; ne pas fixer maintenant un numéro de version.
- [ ] `lib/data/repositories/conversation_repository.dart` — Porter les commandes locales, l’ordre des épingles, les curseurs de lecture et le nettoyage sur preuve de disparition.
- [ ] `lib/features/history/history_view_model.dart` — Exposer commandes et marqueurs ; relier la consultation réelle du fil à son état de lecture.
- [ ] `lib/features/history/conversation_list_item.dart` — Afficher des repères textuels ou iconographiques nommés et les actions accessibles.
- [ ] `test/data/conversation_markers_test.dart` — Vérifier persistance, migration, isolation, replay et ordre stable.
- [ ] `test/features/history/conversation_markers_test.dart` — Vérifier les commandes, l’ouverture et les annonces accessibles.

Les chemins des tâches sont relatifs à la racine du projet et sont des cibles proposées. Étendre les propriétaires existants après intégration, sans créer de repository, route ou migration en doublon.

## Critères d’acceptation

- **AC-1** — Étant donné trois fils A, B et C, quand Alanc épingle B puis A et redémarre l’app, alors B puis A précèdent C avec leurs repères persistants.
- **AC-2** — Étant donné B puis A épinglés, quand Alanc désépingle puis réépingle B, alors A puis B forment le groupe épinglé sans changer les données Hermes.
- **AC-3** — Étant donné deux connexions ou profils avec le même identifiant de session, quand un marqueur est modifié, alors seule la clé complète ciblée change.
- **AC-4** — Étant donné un fil non consulté depuis le début du tour, quand une réussite, une erreur ou un arrêt confirmé arrive, alors le fil devient non lu ; une coupure ou un arrêt simplement demandé ne suffit pas.
- **AC-5** — Étant donné un événement terminal déjà lu, quand cet événement est rejoué, alors le fil reste lu.
- **AC-6** — Étant donné un fil non lu, quand Alanc l’ouvre puis utilise « Marquer non lu », alors il devient lu à l’ouverture puis non lu après l’action, y compris après redémarrage.
- **AC-7** — Étant donné une liste limitée ou une conversation masquée, quand le fil manque dans la réponse, alors aucun marqueur n’est purgé sans preuve distante suffisante.
- **AC-8** — Étant donné une disparition confirmée, quand la réconciliation se termine, alors les marqueurs de ce fil sont supprimés et ceux des autres fils restent intacts.
- **AC-9** — Étant donné un lecteur d’écran actif, quand une ligne est parcourue, alors les états épinglé et non lu sont annoncés et ne dépendent pas seulement de la couleur.

## Vérification attendue

- Exécuter `rtk proxy fvm flutter analyze` et `rtk proxy fvm flutter test` après implémentation ; tester chaque critère dans les fichiers ciblés.
- Vérifier sur téléphone Android : texte agrandi, clavier, lecteur d’écran, retour au bon profil et redémarrage. Les tests simulés ne prouvent pas la compatibilité de Hermes installé.
- Pour toute action distante, utiliser le profil et les sessions dédiés qualifiés en 7.1 ; vérifier les effets depuis un autre client sans toucher aux essais epic 6.
- Consigner résultats, limites et éventuels blocages avant de déclarer la story terminée. Aucun test de code ni essai serveur n’a été exécuté pendant cette rédaction.
