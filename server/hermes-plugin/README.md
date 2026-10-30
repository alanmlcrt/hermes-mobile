# Plugin Hermes `hermes-mobile-notify`

Envoie une notification FCM **générique** (titre « Hermes », corps fixe selon
l'issue : terminé / échoué / arrêté) au téléphone à chaque fin de tour. `data`
ne porte que `outcome` et `sessionId` ; aucun contenu de conversation. L'envoi
part dans un fil en arrière-plan : le tour n'attend jamais le réseau, et toute
erreur (jeton absent, clé absente, FCM en échec) devient une ligne de journal.
Seuls les tours `platform: tui` (l'app) notifient ; les autres (sous-agents
`subagent`, `cron`…) sont journalisés `skipped`, `reason: platform`.

- Commande `/hermes-mobile-token <jeton>` : mémorise le jeton FCM dans
  `HERMES_HOME\hermes-mobile\fcm-token`. L'app l'appelle elle-même
  (`command.dispatch`) avant chaque envoi de message, sans jamais bloquer
  l'envoi. Un seul jeton par profil : le dernier téléphone qui l'envoie reçoit
  les notifications du profil.
- Erreurs FCM : un seul nouvel essai, environ 2 s plus tard, sur erreur réseau
  ou HTTP 5xx ; tout refus 4xx échoue sans nouvel essai. Un jeton refusé
  (`UNREGISTERED`) est oublié (fichier `fcm-token` supprimé) jusqu'au prochain message envoyé depuis l'app. Pas de
  file durable : si Hermes s'arrête en plein tour, la notification est perdue.

Auto-vérification (lancée aussi par la CI) :
`python server/hermes-plugin/hermes-mobile-notify/__init__.py`.

## Profils et `HERMES_HOME`

Le plugin s'installe **par profil**. Chaque profil a son propre `HERMES_HOME`,
avec son dossier `plugins\` et son `config.yaml` :

- profil par défaut (affiché « default ») : `.hermes\` ;
- autre profil : `.hermes\profiles\<nom>\`.

Partage Samba : `\\homeassistant.local\addon_configs\0a6523c6_hermes_agent\`.
Ainsi, pour le profil par défaut,
`HERMES_HOME` = `\\homeassistant.local\addon_configs\0a6523c6_hermes_agent\.hermes\`.

## Installation sur un profil (Alanc)

1. **Copier le plugin** — copier `plugin.yaml` et `__init__.py` de
   `server/hermes-plugin/hermes-mobile-notify/` vers
   `HERMES_HOME\plugins\hermes-mobile-notify\`.
2. **Copier la clé** — copier le fichier du compte de service Firebase vers
   `HERMES_HOME\hermes-mobile\service-account.json` (créer le dossier
   `hermes-mobile\` si besoin). Source : `.hermes\hermes-mobile\service-account.json`
   (déjà installée). Jamais dans le dossier du plugin ni dans le dépôt.
   La clé est celle d'un compte de service du projet Firebase personnel, avec le
   rôle `roles/firebasecloudmessaging.admin` : clé JSON générée depuis la console
   Firebase (Paramètres du projet → Comptes de service), à garder hors dépôt.
3. **Activer** — ajouter **seulement** la ligne `- hermes-mobile-notify` à la
   liste `plugins.enabled` de `HERMES_HOME\config.yaml`, sans retirer les autres
   entrées ; pour le profil par défaut, `hermes plugins enable hermes-mobile-notify`
   dans le terminal de l'add-on fait de même.
4. **Redémarrer** — redémarrer l'add-on Hermes depuis Home Assistant.

Mise à jour : recopier `plugin.yaml` et `__init__.py` (étape 1) puis redémarrer.
Version minimale : **1.0.2** (avant 1.0.1, quitter l'app après un tour envoie un faux « arrêté »).
Le profil `.hermes` porte encore la version des essais (qui notifie aussi les
sous-agents) : y recopier la version actuelle.

Si `hermes-mobile-spike` (plugin de l'étude 1, retiré du dépôt) est encore actif
sur un profil, le désactiver (`hermes plugins disable hermes-mobile-spike` ou
retirer sa ligne de `plugins.enabled`) et supprimer
`HERMES_HOME\plugins\hermes-mobile-spike\`.

## Vérification

- `hermes plugins list` (ou `/plugins` dans une conversation) montre
  `hermes-mobile-notify` chargé ; `/hermes-mobile-token` sans argument répond
  par l'usage ; `logs/agent.log` ne contient aucune erreur de chargement du plugin.
- Après un premier message envoyé depuis l'app (permission de notification
  accordée), `HERMES_HOME\hermes-mobile\fcm-token` existe et le journal porte
  une ligne `event: token`.
- Un tour depuis l'app, app quittée → notification reçue, ligne `action: sent`.

## Journal

`HERMES_HOME\plugins\hermes-mobile-notify\session-end.jsonl`, une ligne par fin
de tour (`action: sent | skipped | failed`, `status` HTTP, `reason`,
`attempts`, `duration_ms`, `outcome`, métadonnées du tour) et une ligne
`event: token` par enregistrement du jeton. Du jeton, seuls les 8 derniers
caractères (`token_tail`) sont écrits ; `agent.log` reçoit une ligne `INFO`
`hermes-mobile-notify …` par tour.

Raisons courantes : `platform` (tour hors app), `session_close` (fermeture de
session sans `turn_id`, par exemple session détachée récoltée après que l'app a
été quittée : ce n'est pas une fin de tour), `no_token` (l'app n'a pas encore
envoyé de jeton, ou il a été refusé par FCM), `no_key` (clé absente),
`key_invalid`, `no_session_id`, `UNREGISTERED`, un autre code FCM tel quel
(`INVALID_ARGUMENT`, `QUOTA_EXCEEDED`, `UNAVAILABLE`…), `fcm_http` (refus sans
code), ou le nom de l'erreur réseau.

## Désinstallation

1. `hermes plugins disable hermes-mobile-notify`, ou retirer la ligne de
   `plugins.enabled`.
2. Supprimer `HERMES_HOME\plugins\hermes-mobile-notify\` (journal compris) et
   `HERMES_HOME\hermes-mobile\` (jeton et clé).
3. Redémarrer l'add-on.
