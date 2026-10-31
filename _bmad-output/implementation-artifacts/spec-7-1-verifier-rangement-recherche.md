---
title: '7.1 — Vérifier le rangement et la recherche sur mon installation'
type: 'feature'
created: '2026-10-30'
status: 'done'
delivery: 'preparation-only'
story_validated: partial
validation: '2026-10-31 — session.title, session.set_hidden, session.delete et session.list include_hidden confirmées par les essais 7.2–7.5 sur téléphone ; sonde non jouée ; session.archive et recherche serveur non vérifiées'
installation_validation: 'pending'
baseline_commit: 'd9a7920fbf71213b354f3e00a086f6167e690cc6'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** le schéma amont ne prouve pas les capacités de rangement/recherche de Hermes installé.

**Approche :** sonder un corpus dédié ; consigner contrat, erreurs, effets et fixtures anonymisées. Sans prérequis, livrer les essais reproductibles sans valider 7.1, puis poursuivre selon les dépendances.

## Boundaries & Constraints

**Toujours :** préserver les briefs et l’epic 6. Identifier build, provenance et portée. Distinguer observé, documentaire, synthétique, absent et non vérifié. Exclure les secrets des fichiers et sorties. Limiter les mutations aux identifiants dédiés déclarés ; aucun rejeu après résultat incertain.

**Jamais :** modifier l’autre checkout, fusionner, publier, accéder aux bases privées, changer le profil global ou valider par simulation. Aucun écran ni migration dans 7.1.

## I/O & Edge-Case Matrix

| Scénario | Entrée / état | Résultat attendu | Erreur |
|---|---|---|---|
| Lecture | Installation authentifiée, profil dédié | Capacité et liste observées, build identifié | Refus d’authentification distinct de panne |
| Mutation | Session dédiée autorisée, titre/masquage/archivage/suppression | Réponse puis comparaison liste/historique ; contrôle autre client | Timeout : résultat incertain, aucune répétition |
| Méthode absente | Refus explicite de méthode inconnue | Absence enregistrée, fonction indisponible | Refus de paramètres ne prouve pas l’absence |
| Isolation | Profil ou identifiant non autorisé | Aucun appel de mutation | Refus local explicite |
| Recherche | Surface exposée inspectée | Recherche constatée ou couverture non vérifiée ; repli local documenté | Ne pas déduire l’absence du seul schéma amont |

</frozen-after-approval>

## Code Map

- Les deux briefs : périmètre provisoire, distinct du plan intégré.
- `contracts/README.md` : aucun contrat capturé dans cette branche.
- `_bmad-output/planning-artifacts/architecture/architecture-Hermes Mobile-2026-10-20/.working/gateway-contract.openrpc.json` : copie documentaire `5eee5d02e85eaad32dfade3030d27fcfad204e72`, non certifiée sur installation.
- Schéma : `session.title(session_id, profile?, title?)` vise le runtime ; sans titre, lecture. `session.delete(session_id, profile?)` vise l’ID stocké. `session.set_hidden(session_id, hidden, profile?)` et `session.archive(session_id?, session_key?, archived?, profile?)` touchent la lignée : autoriser celle-ci explicitement. `session.list(profile?, title?, limit?, include_hidden?)` ne prouve aucune recherche plein texte ; `session.history(session_id, profile?)` lit les messages durables.
- `ARCHITECTURE-SPINE.md`, même dossier : AD-3/5/7/8. Copies `.working/hermes_cli__web_server_chat.py`, `hermes_cli__web_routers__chat_ws.py`, `hermes_cli__web_routers__profiles.py` : `/api/ws`, jeton/ticket, GET `/api/profiles`. Routes login/ticket inconnues ; ne pas les inventer. `gateway.capabilities` n’inventorie pas les méthodes.
- `lib/main.dart` : squelette ; attendre les repositories de l’epic 6.
- `pubspec.yaml` : réutiliser `http` et `web_socket_channel`.

## Tasks & Acceptance

**Execution :**
- [x] `contracts/epic-7/README.md` — protocole, dépendances ; titre/masquage/suppression partagés, épingle/non-lu locaux.
- [x] `tool/sonde_rangement.dart` — REST/RPC, configuration et jeton/ticket par environnement ; lecture par défaut, mutations une par une avec autorisation profil/identifiants/lignée. Délais bornés, aucun rejeu, capture structurée anonymisée avant écriture ; aucune erreur brute ni secret affiché.
- [x] `test/sonde_rangement_test.dart` — transport simulé : isolation, corrélation, anonymisation, méthode inconnue distincte des autres erreurs, timeout sans rejeu, redirections refusées et fermeture des connexions.
- [x] `contracts/epic-7/methods.json`, `contracts/epic-7/capabilities.json` — schémas candidats et constats par méthode/build/preuve, initialement non vérifiés.
- [x] `contracts/epic-7/fixtures/` — répertoire préparé pour les captures anonymisées réelles, actuellement vide ; exemples synthétiques confinés aux tests. Captures réelles en attente, conformément au repli approuvé.
- [x] `contracts/epic-7/verification.md` — effets avant/après, autre client, limites, choix masquage/recherche et intégration après epic 6.

**Acceptance Criteria :**
- Étant donné un corpus dédié accessible, quand les quatre méthodes sont essayées, alors paramètres, réponses, erreurs, effets sur listes et autre client sont traçables par preuve anonymisée.
- Étant donné l’inspection disponible, quand la recherche est évaluée, alors disponibilité et couverture sont justifiées ; toute incertitude reste explicite.
- Étant donné un prérequis manquant, quand le bilan est établi, alors les essais restants sont reproductibles et 7.1 reste non validée.

## Implementation Notes

- 30/10/2026 : sonde indépendante, manifestes documentaires, protocole et bilan livrés sans changement de `lib/` ni des dépendances. Les fichiers préparatoires existants sont conservés.
- Livraison de préparation uniquement selon le repli approuvé : aucun corpus ni accès authentifié disponible. Captures, effets interclients, build et couverture de recherche restent ouverts ; aucune capacité ni validation réelle revendiquée.
- Vérification directe : analyse statique sans alerte et 24 tests passés (16 scénarios de sonde, 8 contrôles existants), SDK épinglé 3.47.7. Audit de matrice : lectures/authentification, quatre mutations/avant-après, absence explicite, isolation et recherche non vérifiée couverts. Les tests prouvent l’outil, pas le serveur.
- Après revue et corrections : 32 tests passés (24 scénarios de sonde et 8 contrôles d’architecture), analyse complète sans alerte et deux JSON valides. Le statut `done` désigne exclusivement la livraison de préparation autorisée ; **la story 7.1 n’est pas validée sur installation** et les essais réels restent à effectuer.

## Spec Change Log

## Review Triage Log

Revue du 30/10/2026 ; H = revue aveugle, E = cas limites, V = vérification, O = contrôle du coordinateur.

| ID | Verdict | Preuve et décision |
|---|---|---|
| H1 | medium | `_rpc` consigne une erreur puis retourne ; un refus de liste/historique avant mutation laisse celle-ci partir. Patch : interrompre la mutation si sa base nécessaire manque. |
| H2 | medium | Le contrat `TranscriptMessage` porte `text`, `role`, `row_id`, absents de la projection ; les messages ordinaires deviennent `{}`. Patch : conserver texte/identité sous alias et rôle autorisé. |
| H3 | medium | Après réponse conclusive, `_mutationAttempted` reste vrai ; un timeout du contrôle après mutation produit à tort `uncertain_do_not_replay`. Patch : distinguer réponse reçue et contrôle échoué. |
| H4 | medium | `run` intercepte les refus et `main` annonce toujours une fin normale avec code 0. Patch : capture conservée, sortie non nulle sur échec du protocole. |
| H5 | medium | Un résultat scalaire ou nul est accepté pour les méthodes documentées comme objets. Patch : utiliser le refus de réponse RPC invalide déjà existant. |
| H6 | low | Une interruption brutale peut laisser le fichier réservé vide. Un fichier vide ne constitue aucune preuve et le protocole interdit le rejeu incertain ; journalisation continue supplémentaire rejetée pour ce scénario rare de sonde manuelle sur corpus jetable. |
| H7 | medium | Le plan préexistant 7.2 demande une confirmation sans définir le cas documentaire `pending`. Différé à la qualification 7.2, sans modifier ce plan durant 7.1. |
| H8 | maybe-false | Le plan préexistant 7.4 sérialise par session ; conflit entre IDs d'une même lignée possible mais non démontré sur installation. Risque moyen non vérifié, différé ; trancher avec portée/concurrence réelle en 7.1 puis 7.4. |
| H9 | maybe-false | Le plan préexistant 7.6 ne fixe pas de borne de latence ; aucune implémentation ni mesure ne prouve un blocage. Risque moyen non vérifié différé : mesurer un corpus représentatif lors de 7.6. |
| H10 | low | Identifiant/date automatiques absents ; le protocole prévoit déjà un fichier distinct et un identifiant manuel de preuve. Ajout de métadonnées non nécessaire au parcours courant, rejeté. |
| E1 | medium | Même défaut vérifié que H2 : `text` est exclu et l'égalité des historiques se perd. Regroupé avec H2 après verdict individuel. |
| E2 | medium | Même défaut vérifié que H1 : les erreurs RPC des lectures nécessaires n'arrêtent pas la mutation. Regroupé avec H1. |
| E3 | medium | Même défaut vérifié que H3 : timeout après réponse transforme une réponse connue en résultat incertain. Regroupé avec H3. |
| V1 | medium | Lacune pré-vérifiée : tests comptent deux listes sans vérifier `include_hidden`; une constante `false` passerait. Patch : résultats distincts et assertions par phase. |
| V2 | medium | Lacune pré-vérifiée : aucun test n'exécute `main` pour protéger un fichier existant ou refuser une destination inutilisable avant réseau. Patch : tests subprocess et serveur loopback. |
| O1 | medium | Les sources WS ferment avec 4401 pour mauvais accès et 4403 pour refus de frontière ; `_failPending` les réduit à `connection_closed`. Patch : distinguer ces fermetures des pannes réseau, sans publier leur raison brute. |

Résolution : H1–H5, E1–E3, V1–V2 et O1 corrigés et couverts par les 32 tests finaux réussis. H6/H10 rejetés comme améliorations de faible impact ; H7–H9 consignés dans `deferred-work.md`. Aucune remarque retenue de cette livraison ne reste sans traitement.

## Design Notes

Sonde indépendante de Flutter et de l’epic 6 ; aucune dépendance nouvelle. Les réponses arbitraires ne sont pas publiées : projection autorisée, pseudonymes des identifiants, textes masqués. Le manifeste garde la provenance documentaire ; le build installé et les effets interclients restent non vérifiés tant que les preuves manquent. Une réponse RPC seule ne valide ni la réversibilité ni la portée sur la lignée.

## Verification

- `rtk proxy fvm flutter analyze` et `rtk proxy fvm flutter test` : aucune régression. FVM absent du PATH ; SDK épinglé trouvé dans `C:/Users/alanc/fvm/versions/3.47.7/bin` (Flutter 3.47.7, Dart 3.13.5), utilisable directement.
- Exécuter la sonde en lecture avant les mutations dédiées ; vérifier les captures sans secrets et les observations depuis un autre client. Les tests simulés valident l’outil seulement.
- 30/10/2026 : GET origine documentée, port 9119 → HTTP 200 HTML. Authentification, build, profil dédié et capacités non vérifiés.
- Reprise du 30/10 : GET `/` sans suivre les redirections → HTTP 302 ; ni authentification ni build prouvés. Aucun accès Hermes configuré par environnement ni corpus dédié fourni. Préparer les essais ; laisser la validation réelle ouverte.
