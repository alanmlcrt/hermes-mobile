# Bilan 7.1 — validée partiellement par les essais de l'app

**Mise à jour 2026-10-31.** La sonde n'a pas été jouée, mais Alanc a essayé les
stories 7.2 à 7.6 sur son téléphone (APK release versionCode 25 puis 26) contre
son Hermes installé, sur des conversations jetables : renommer, masquer puis
annuler/rétablir, et supprimer ont produit l'effet attendu dans l'app et dans un
autre client Hermes. `session.title`, `session.set_hidden` (ID stocké),
`session.list` (`include_hidden`) et `session.delete` (ID stocké) sont donc
considérées vérifiées pour ce build. Restent non vérifiés : `session.archive`
(non utilisé), la recherche serveur, la portée exacte du masquage sur une lignée
compressée, et les cas limites (coupure pendant une suppression, notification
d'un fil supprimé).

## Bilan initial — 2026-10-30

Date : 2026-10-30. Aucun accès Hermes authentifié configuré dans l'environnement,
aucun profil/corpus dédié fourni. Aucun appel de mutation réel effectué.

## Niveaux de preuve

| Élément | Statut | Preuve / limite |
| --- | --- | --- |
| Schéma candidat | Documentaire | Copie OpenRPC, révision `5eee5d02e85eaad32dfade3030d27fcfad204e72` |
| Build installé / provenance | Non vérifié | À relever par une surface officielle |
| Authentification / profil dédié | Non vérifié | Variables et corpus indisponibles |
| GET origine port 9119 | Observation antérieure rapportée dans la spec | HTML 200 puis reprise 302 ; aucun contrat authentifié prouvé |
| session.title | Vérifié (essai app 2026-10-31) | Renommage visible dans un autre client ; cas `pending` non observé |
| session.set_hidden | Vérifié (essai app 2026-10-31) | ID stocké ; masquer puis rétablir réversible ; portée lignée non mesurée |
| session.archive | Non vérifié | Lignée entière ; ne pas assimiler à hidden sans essai |
| session.delete | Vérifié (essai app 2026-10-31) | ID stocké ; fil disparu de l'autre client ; refus pendant un travail non essayé |
| Recherche serveur | Non vérifié | Le filtre `session.list.title` ne prouve pas une recherche plein texte |
| Tests de sonde | Synthétique | Protection de l'outil uniquement, aucune validation serveur |

Vérification locale du 30 octobre 2026 avec le SDK épinglé :
contrôles ciblés après corrections de revue : analyse de
`tool/sonde_rangement.dart` et `test/sonde_rangement_test.dart` sans alerte ;
`rtk proxy fvm flutter test --no-pub test/sonde_rangement_test.dart` :
24 scénarios de sonde réussis (simulations, serveur loopback et sous-processus CLI).
FVM étant absent du PATH, ces commandes ont été exécutées avec
`C:/Users/alanc/fvm/versions/3.47.7/bin/flutter.bat`. Les checks couvrent isolation,
corrélation, projection anonyme, refus de méthode/paramètres, mutation incertaine
sans rejeu, redirections REST/WebSocket et fermeture d'une socket réelle locale.
Les régressions de revue couvrent aussi le blocage sur listes/historiques avant
mutation en erreur, le titre runtime optionnel, les résultats nuls/scalaires,
la distinction réponse de mutation reçue/contrôle après échoué, les codes de
fermeture 4401/4403, les variantes normales/masquées dans chaque snapshot, les
alias des transcriptions et les sorties CLI en échec. Les sous-processus prouvent
qu'un fichier existant garde ses octets et qu'une destination inutilisable
empêche tout accès réseau avant mutation. Aucun appel réel Hermes.

Contrôle complet final du coordinateur : `flutter analyze --no-pub` sans alerte,
`flutter test --no-pub --reporter expanded` : **32 tests réussis**, dont les
24 scénarios de sonde et les 8 contrôles d'architecture existants. Les deux
manifestes JSON se décodent correctement. Revue à trois lectures terminée,
correctifs vérifiés ; trois points des futures stories sont consignés dans
`_bmad-output/implementation-artifacts/deferred-work.md`.

Une interruption peut laisser le fichier réservé vide ou incomplet. Ce fichier
n'est pas une preuve d'absence d'effet : réconciliation manuelle par lectures et
autre client, aucun rejeu. Une réponse reçue reste enregistrée comme telle si le
contrôle après échoue ; les effets restent alors non vérifiés.

## Essais restants reproductibles

Suivre les variables et commandes de `README.md` en lecture d'abord. Conserver
une capture séparée par mutation, liée à une fiche ci-dessous. Ne jamais rejouer
une mutation incertaine. Vérifier le client officiel sur le même profil, puis un
autre profil pour l'isolation, sans exposer de contenu personnel dans le bilan.

Pour chaque essai remplir : identifiant de preuve, build et provenance officielle,
profil/session/lignée sous alias, méthode, paramètres projetés, état avant
(listes normale/masquées, titre, historique), réponse/erreur, état après, visibilité
dans un autre client, portée réelle (runtime/stocké/lignée), limites et résultat.
Une réponse RPC seule n'établit ni effet réel ni réversibilité.

1. Renommer le runtime dédié. Comparer titre/historique/listes/autre client ;
   documenter le cas `pending` et la correspondance avec l'ID stocké.
2. Masquer la lignée dédiée, comparer les deux listes et l'accès à l'historique ;
   après confirmation, démasquer dans une exécution distincte et constater la
   réapparition sur les clients. Ne pas conclure à une suppression depuis la liste.
3. Archiver puis désarchiver uniquement après confirmation, vérifier quelle liste
   ou surface officielle reflète cet état. Comparer sa portée avec `set_hidden`.
4. Supprimer une conversation stockée jetable. Relever d'abord tout travail
   distant et envoi non résolu. Après confirmation serveur, constater liste et
   historique et l'autre client ; aucune suppression mobile ou base privée.
5. Si le serveur renvoie -32601, classer cette méthode absente pour ce build.
   Conserver distinctement refus d'authentification, -32602, panne et timeout.
6. Inspecter les surfaces officiellement exposées et la recherche du client
   installé. Consigner route/méthode réellement identifiée, query, profil,
   pagination et couverture (titre, contenu, masquées, archivées, historiques
   non chargés). Ne jamais lancer une méthode inventée sur la seule base du nom.
   Contraster une requête titre dédiée et un mot présent seulement dans un
   message. Documenter l'absence uniquement si un refus explicite ou une
   inspection suffisante la prouve ; sinon conserver « non vérifié ».

## Choix et intégration

Aucun choix définitif de méthode de masquage : la réversibilité et les effets sur
la lignée attendent les preuves. Une méthode explicitement absente désactivera la
fonction correspondante avec une explication. Aucun contournement n'est retenu.

Recherche : aucun moteur serveur prouvé. Repli envisagé sur titres et messages
déjà chargés localement, avec couverture affichée explicitement et groupes par
profil. Ce repli ne prouve ni absence serveur ni couverture de tout l'historique.

Après intégration de l'epic 6, réconcilier l'adaptateur unique, les repositories,
identités connexion/profil/session, migrations en ajout seul, routes et contrats
d'exécution. Sérialiser les mutations par session, conserver les saisies et états
incertains, conditionner le nettoyage à confirmation. Épingle/non-lu restent
locaux. Aucun écran ni migration n'appartient à cette story.

7.1 reste **non validée** jusqu'aux preuves authentifiées des quatre méthodes,
leurs effets avant/après et interclients, et au bilan justifié de recherche.
