# Réalisation et acceptation — 7.4 — Masquer et retrouver des conversations

## Provenance et état réel

Exigences reprises de `../../../EPIC-7-REFERENCE.md`, section de cette story. Ce document est un extrait provisoire, non intégré au plan de master. La spec 7.1 existe dans `../../implementation-artifacts/spec-7-1-verifier-rangement-recherche.md` et reste en attente de validation. Cette rédaction ne valide aucune capacité ni dépendance.

## Conditions de démarrage

- 7.1 : choix de méthode, portée sur la lignée, liste des masquées et opération inverse vérifiés ; sans ces preuves la fonction ne démarre pas.
- Epic 6 : historique, adaptateur, réconciliation, navigation et erreurs ; 7.3 pour conserver les marqueurs si elle est intégrée.

Avant de passer en ready-for-dev : vérifier ces prérequis, remplacer les chemins proposés par les chemins réellement intégrés, confirmer les choix ci-dessous et faire approuver la spec dans bmad-build. Si une dépendance manque, conserver draft et documenter le manque ; ne pas créer une seconde implémentation concurrente.

## Cartographie de la base

- `../../../lib/main.dart` : squelette Flutter observé ; les couches ciblées ci-dessous sont à intégrer ou à retrouver après epic 6.
- `../../../lib/data/README.md`, `../../../lib/models/README.md`, `../../../lib/features/README.md` : frontières des responsabilités.
- `../../../contracts/README.md` : contrat installé à enrichir par 7.1 ; ne pas prendre les schémas amont pour preuves.
- `../../../pubspec.yaml` : HTTP, WebSocket, SQLite et routage déjà déclarés ; aucune dépendance nouvelle décidée par cette spec.

## Choix de réalisation proposés

- Appliquer le changement de section après confirmation ; garder la ligne en attente pendant l’appel. Une réponse perdue impose de vérifier les listes avant toute nouvelle action.
- « Annuler » envoie l’opération inverse, elle aussi confirmée ; ce n’est pas un rollback local. Sérialiser masquer/rétablir par session.
- La disparition du message éphémère ne supprime jamais la possibilité de rétablir depuis « Masquées ». Ne pas inventer de durée imposée : reprendre celle du composant existant et ses adaptations d’accessibilité.
- Distinguer chargement, section vide, erreur et données conservées. Au changement de profil, abandonner l’affichage de résultats appartenant à la sélection précédente.
- Si la méthode affecte une lignée, expliquer sa portée confirmée avant validation ; aucune mutation hors périmètre de test pendant la qualification.

## Tâches ordonnées

- [ ] `lib/data/hermes/hermes_rpc.dart` — Ajouter uniquement les appels de masquage, liste et inverse qualifiés par 7.1.
- [ ] `lib/data/repositories/conversation_repository.dart` — Réconcilier listes principale/masquée sur confirmation et conserver les données locales.
- [ ] `lib/features/history/history_view_model.dart` — Porter section, progression, annulation et erreurs avec cibles stables.
- [ ] `lib/features/history/hidden_conversations_view.dart` — Composer « Masquées », ouverture et rétablissement accessibles avec les composants existants.
- [ ] `lib/features/history/history_view.dart` — Relier le menu « Masquer » et le message « Annuler » à la section masquée.
- [ ] `test/features/history/hidden_conversations_test.dart` — Tester le parcours, les erreurs, l’isolation et l’absence de purge locale.

Les chemins des tâches sont relatifs à la racine du projet et sont des cibles proposées. Étendre les propriétaires existants après intégration, sans créer de repository, route ou migration en doublon.

## Critères d’acceptation

- **AC-1** — Étant donné un fil visible et une capacité disponible, quand Alanc le masque, alors le fil quitte la liste après confirmation et « Annuler » est proposé.
- **AC-2** — Étant donné un masquage confirmé, quand Alanc choisit « Annuler », alors l’inverse serveur est appelé et le fil revient seulement après confirmation.
- **AC-3** — Étant donné des fils masqués, quand Alanc ouvre « Masquées », alors il peut les retrouver, les ouvrir et les rétablir dans leur profil.
- **AC-4** — Étant donné une erreur serveur pendant le masquage, quand l’appel échoue, alors le fil reste visible et l’erreur est expliquée.
- **AC-5** — Étant donné une erreur pendant l’opération inverse, quand le rétablissement échoue, alors le fil reste masqué et une nouvelle tentative explicite reste possible.
- **AC-6** — Étant donné une réponse perdue, quand l’appel expire, alors l’état à vérifier est signalé, aucun rejeu implicite ne survient et les listes peuvent être actualisées.
- **AC-7** — Étant donné un fil épinglé avec brouillon et pièces locales, quand il est masqué puis rétabli, alors ses données locales et marqueurs sont conservés.
- **AC-8** — Étant donné une méthode indisponible ou une section vide, quand l’historique est présenté, alors l’indisponibilité ou l’absence de masquées est expliquée distinctement d’une erreur.
- **AC-9** — Étant donné un texte agrandi et le lecteur d’écran, quand Alanc masque puis rétablit, alors les actions et résultats sont annoncés et le rétablissement reste accessible après disparition du message éphémère.

## Vérification attendue

- Exécuter `rtk proxy fvm flutter analyze` et `rtk proxy fvm flutter test` après implémentation ; tester chaque critère dans les fichiers ciblés.
- Vérifier sur téléphone Android : texte agrandi, clavier, lecteur d’écran, retour au bon profil et redémarrage. Les tests simulés ne prouvent pas la compatibilité de Hermes installé.
- Pour toute action distante, utiliser le profil et les sessions dédiés qualifiés en 7.1 ; vérifier les effets depuis un autre client sans toucher aux essais epic 6.
- Consigner résultats, limites et éventuels blocages avant de déclarer la story terminée. Aucun test de code ni essai serveur n’a été exécuté pendant cette rédaction.
