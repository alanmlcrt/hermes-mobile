# Epic 7 — Tests à faire par Alanc

Code des stories 7.2 à 7.6 livré en préparation seulement (commits 73349a3, bb23229, 3f3e694). Les 705 tests automatiques passent, mais ils simulent Hermes : rien n'est prouvé sur l'installation réelle. Faire les essais sur un **profil Hermes dédié**, avec des conversations jetables, jamais sur les essais epic 6.

## 1. Sonde 7.1 (avant tout essai sur le téléphone)

Procédure complète : `contracts/epic-7/README.md`. Résumé :

1. Renseigner `HERMES_ORIGIN`, `HERMES_PROFILE` (profil dédié), `HERMES_SESSIONS` (IDs jetables) et le jeton ou le ticket.
2. Lecture seule : `~/fvm/versions/3.47.7/bin/dart run tool/sonde_rangement.dart`. Vérifier que les listes avec et sans masquées répondent.
3. Une mutation par lancement, avec les variables `HERMES_AUTHORIZE_*`, `HERMES_TARGET_SESSION` et `HERMES_VALUE` / `HERMES_NEW_TITLE` :
   - `session.title`
   - `session.set_hidden` (`true`, puis `false` pour rétablir)
   - `session.delete` sur une conversation jetable
4. Pour chaque mutation, vérifier l'effet depuis un autre client Hermes. Reporter les résultats dans `contracts/epic-7/capabilities.json` et `verification.md`.

Points à observer, car le code fait ces hypothèses :

- `session.set_hidden` accepte l'**ID stocké** et rend `{hidden, session_key}`.
- `session.list` avec `include_hidden: true` renvoie aussi les masquées.
- `session.delete` rend `{deleted: <ID stocké>}` et refuse une conversation active.
- Ce que touche le masquage sur une lignée compressée.

Si une réponse diffère, me le signaler : l'adaptateur (`lib/data/hermes_adapter.dart`) est le seul endroit à corriger.

## 2. Sur le téléphone

Construire l'APK release avec `--build-number` supérieur à celui installé.

### 7.2 Renommer
- Renommer depuis le menu « ⋮ » : le titre change seulement après confirmation et se voit depuis un autre client.
- Titre vide ou identique : refusé sans appel.

### 7.3 Épingler et non lu
- Épingler B puis A, puis redémarrer l'app : B puis A restent en tête.
- Désépingler B puis le réépingler : il passe après A.
- Lancer une demande, quitter le fil avant la fin : à la fin, la ligne est en gras avec « Non lu ». L'ouvrir l'enlève, et « Marquer non lu » le remet, y compris après redémarrage.

### 7.4 Masquer
- Masquer : la ligne disparaît après confirmation et le message « Annuler » apparaît. Toucher « Annuler » la fait revenir.
- La section « Masquées » liste le fil ; « Rétablir » le remet dans la liste principale.
- Le brouillon et l'épingle du fil sont toujours là après masquage puis rétablissement.

### 7.5 Supprimer
- Supprimer une conversation jetable : le dialogue est lu clairement au lecteur d'écran, et « Annuler » n'envoie rien.
- Confirmer : la ligne disparaît, et la conversation n'existe plus dans un autre client.
- Pendant qu'un travail est en cours : suppression refusée, avec une explication.
- Mode avion au moment de confirmer : pas de suppression, rien n'est effacé.
- Notification de fin d'une conversation supprimée : l'app ouvre l'accueil avec « Cette conversation a été supprimée ».

### 7.6 Rechercher
- « resume » trouve « Résumé » dans un titre ; un mot présent seulement dans un message déjà ouvert sur le téléphone est trouvé.
- « Tous les profils » : les résultats sont groupés par profil, et chacun ouvre le bon fil.
- Vider le champ fait revenir la liste normale.

### Accessibilité, pour chaque écran
- Texte agrandi à 200 % : rien ne déborde.
- TalkBack : épinglé, non lu, états « à vérifier » et passages trouvés sont annoncés.

## 3. Limites connues (voir `deferred-work.md`)
- Les marqueurs d'un fil supprimé depuis un autre client ne sont pas purgés.
- Une suppression « à vérifier » le reste jusqu'à une nouvelle tentative manuelle.
- Un fil laissé ouvert, app en arrière-plan, ne devient pas non lu.
- La recherche est locale uniquement ; les accents gérés sont ceux des lettres latines courantes.
