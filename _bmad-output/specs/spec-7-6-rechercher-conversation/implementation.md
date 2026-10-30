# Réalisation et acceptation — 7.6 — Rechercher une conversation

## Provenance et état réel

Exigences reprises de `../../../EPIC-7-REFERENCE.md`, section de cette story. Ce document est un extrait provisoire, non intégré au plan de master. La spec 7.1 existe dans `../../implementation-artifacts/spec-7-1-verifier-rangement-recherche.md` et reste en attente de validation. Cette rédaction ne valide aucune capacité ni dépendance.

## Conditions de démarrage

- 7.1 : présence/absence/couverture de recherche serveur, paramètres, pagination et profils ; aucun nom de méthode inventé.
- Epic 6 : cache des messages affichables, liste des profils, historique, adaptateur et navigation.
- 7.2–7.5 : actualiser l’index après renommage/suppression et respecter la section principale ou masquée ; pas de dépendance à une épingle pour trouver un fil.

Avant de passer en ready-for-dev : vérifier ces prérequis, remplacer les chemins proposés par les chemins réellement intégrés, confirmer les choix ci-dessous et faire approuver la spec dans bmad-build. Si une dépendance manque, conserver draft et documenter le manque ; ne pas créer une seconde implémentation concurrente.

## Cartographie de la base

- `../../../lib/main.dart` : squelette Flutter observé ; les couches ciblées ci-dessous sont à intégrer ou à retrouver après epic 6.
- `../../../lib/data/README.md`, `../../../lib/models/README.md`, `../../../lib/features/README.md` : frontières des responsabilités.
- `../../../contracts/README.md` : contrat installé à enrichir par 7.1 ; ne pas prendre les schémas amont pour preuves.
- `../../../pubspec.yaml` : HTTP, WebSocket, SQLite et routage déjà déclarés ; aucune dépendance nouvelle décidée par cette spec.

## Choix de réalisation proposés

- Utiliser une recherche de sous-chaîne après normalisation Unicode, retrait des diacritiques et comparaison sans casse. Conserver une correspondance des positions vers le texte original pour le surlignage, y compris caractères combinés et emoji.
- La requête vide ou composée d’espaces quitte le mode recherche et retrouve la liste normale. La recherche respecte la section active ; « Tous les profils » étend les profils, pas la section.
- La fusion utilise la clé complète connexion/profil/session, jamais le titre. Préserver l’ordre courant de l’historique pour les résultats locaux ; les enrichissements distants ne dupliquent pas les lignes.
- Attribuer une génération à chaque requête et changement de portée ; ignorer les réponses antérieures et annuler les lectures quand le transport le permet.
- Afficher les résultats locaux immédiatement ; une erreur distante conserve ces résultats avec une indication de couverture partielle. Une erreur sur un profil ne fait pas disparaître les autres groupes.
- Le moteur et la normalisation sont séparés de la vue pour réemploi futur ; pas d’index SQLite FTS imposé avant connaissance du volume et du schéma intégré.

## Tâches ordonnées

- [ ] `lib/models/conversation_search_result.dart` — Définir résultat, clé complète, extrait, positions de correspondance et provenance locale/distante.
- [ ] `lib/data/search/conversation_search.dart` — Implémenter normalisation et correspondance dans les textes affichables du cache sans téléchargement massif.
- [ ] `lib/data/repositories/conversation_repository.dart` — Coordonner la portée, fusion, invalidation sur mutations et lectures serveur seulement si vérifiées.
- [ ] `lib/data/hermes/hermes_rpc.dart` — Étendre avec la recherche vérifiée uniquement si 7.1 prouve son existence ; sinon conserver le parcours local.
- [ ] `lib/features/history/history_search_view_model.dart` — Porter requête, section/profils, génération, progression et états partiels/vides/erreurs.
- [ ] `lib/features/history/history_search_view.dart` — Ajouter champ, couverture, groupes de profils, extraits surlignés et navigation accessible.
- [ ] `test/data/conversation_search_test.dart` — Tester casse/accents, Unicode, contenus locaux, isolation, fusion et réponses hors ordre.
- [ ] `test/features/history/history_search_test.dart` — Tester les groupes, les états, la portée et l’ouverture vers le bon fil.

Les chemins des tâches sont relatifs à la racine du projet et sont des cibles proposées. Étendre les propriétaires existants après intégration, sans créer de repository, route ou migration en doublon.

## Critères d’acceptation

- **AC-1** — Étant donné un titre « Résumé » et un aperçu « Vacances », quand Alanc cherche « resume » ou « VACANCES », alors les fils correspondants apparaissent avec leurs passages originaux mis en évidence.
- **AC-2** — Étant donné un mot seulement dans un message affichable déjà chargé, quand Alanc le recherche, alors le fil est trouvé sans télécharger les historiques non chargés.
- **AC-3** — Étant donné des caractères combinés et un emoji dans le texte, quand un passage correspond, alors le surlignage respecte les limites du texte original sans casser les caractères.
- **AC-4** — Étant donné une recherche serveur vérifiée, quand des résultats locaux et distants désignent le même fil, alors ils sont fusionnés une seule fois par clé complète.
- **AC-5** — Étant donné aucune recherche serveur disponible, quand Alanc recherche, alors l’app indique « Recherche dans les titres et le contenu déjà chargé ».
- **AC-6** — Étant donné plusieurs profils et des identifiants de session identiques, quand « Tous les profils » est activé, alors les résultats restent groupés et identifiés ; chacun ouvre son propre fil.
- **AC-7** — Étant donné une requête A suivie d’une requête B, quand la réponse A arrive après B, alors seuls les résultats B restent affichés.
- **AC-8** — Étant donné une requête sans correspondance puis une panne, quand la liste est rendue, alors « Aucun résultat » est distinct d’une erreur ; les résultats partiels restent visibles avec leur limite.
- **AC-9** — Étant donné un fil renommé, masqué ou supprimé, quand l’état confirmé est réconcilié, alors les résultats suivent le nouveau titre et la section, et excluent les fils supprimés.
- **AC-10** — Étant donné la recherche active, quand la saisie est vidée ou le lecteur d’écran parcourt un résultat, alors la liste normale revient sur saisie vide et le résultat expose titre, profil et extrait lisibles sans dépendre de la couleur.

## Vérification attendue

- Exécuter `rtk proxy fvm flutter analyze` et `rtk proxy fvm flutter test` après implémentation ; tester chaque critère dans les fichiers ciblés.
- Vérifier sur téléphone Android : texte agrandi, clavier, lecteur d’écran, retour au bon profil et redémarrage. Les tests simulés ne prouvent pas la compatibilité de Hermes installé.
- Pour toute action distante, utiliser le profil et les sessions dédiés qualifiés en 7.1 ; vérifier les effets depuis un autre client sans toucher aux essais epic 6.
- Consigner résultats, limites et éventuels blocages avant de déclarer la story terminée. Aucun test de code ni essai serveur n’a été exécuté pendant cette rédaction.
