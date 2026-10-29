# Plugin d'essai `hermes-mobile-spike`

Essai minimal : vérifier que le hook Hermes `on_session_end` se déclenche pour les
tours lancés depuis l'app et voir quel `session_id` il porte. Le plugin ajoute une
ligne JSON par tour à `session-end.jsonl` (dans son dossier) et une ligne `INFO`
dans `logs/agent.log`. Il ne copie que des métadonnées (identifiants, booléens,
modèle, plateforme) : jamais de contenu, pas de réseau, pas de commande slash,
pas de FCM. Toute erreur d'écriture devient un avertissement, le tour continue.

Auto-vérification locale : `python server/hermes-plugin/hermes-mobile-spike/__init__.py`.

Profil visé : **`.hermes` uniquement** (affiché « default »). Partage Samba :
`\\homeassistant.local\addon_configs\0a6523c6_hermes_agent\.hermes\` (noté `HERMES_HOME` ci-dessous).

## Installation (Alanc)

1. **Copie** — copier le dossier `server/hermes-plugin/hermes-mobile-spike/`
   (seulement `plugin.yaml` et `__init__.py`) vers `HERMES_HOME\plugins\hermes-mobile-spike\`.
2. **Sauvegarde** — copier `HERMES_HOME\config.yaml` en
   `config.yaml.bak-avant-spike` (même dossier).
3. **Activation**, au choix :
   - terminal de l'add-on : `hermes plugins enable hermes-mobile-spike` (accepter la demande de consentement si elle apparaît) ;
   - ou éditer `config.yaml` et ajouter **seulement** la ligne `- hermes-mobile-spike`
     à la liste `plugins.enabled` existante, sans remplacer les autres entrées.
     Exemple indicatif (la liste réelle peut différer) :
     ```yaml
     plugins:
       enabled:
         - homeassistant
         - rtk-rewrite
         - hermes-mobile-spike
     ```
4. **Redémarrage** — redémarrer l'add-on Hermes depuis Home Assistant.
5. **Vérification** — `hermes plugins list` (ou `/plugins` dans une conversation)
   montre `hermes-mobile-spike` chargé ; `logs/agent.log` ne contient aucun
   avertissement `hermes-mobile-spike` ni erreur de chargement du plugin.

## Essais

Depuis l'app, sur le profil `.hermes` :

1. un tour complet (message court, attendre la réponse) ;
2. un tour arrêté (envoyer une demande longue, puis « Arrêter »).

Noter l'heure de chaque tour. L'agent lit ensuite, en lecture seule via Samba,
`HERMES_HOME\plugins\hermes-mobile-spike\session-end.jsonl` et compare
`session_id` à la table `sessions` de `HERMES_HOME\state.db`.

Attendu : une ligne par tour, `completed: true` pour le premier,
`interrupted: true` pour le second, `platform` et `session_id` renseignés.

## Désinstallation

1. `hermes plugins disable hermes-mobile-spike`, ou retirer la ligne de
   `plugins.enabled` (ou restaurer `config.yaml.bak-avant-spike`).
2. Supprimer `HERMES_HOME\plugins\hermes-mobile-spike\` (journal compris).
3. Redémarrer l'add-on.

---

# Plugin d'essai `hermes-mobile-notify` (étude 2)

Envoie une notification FCM **générique** (titre « Hermes », corps fixe selon
l'issue : terminé / échoué / arrêté) au téléphone à chaque fin de tour. `data`
ne porte que `outcome` et `sessionId` ; aucun contenu de conversation. L'envoi
part dans un fil en arrière-plan : le tour n'attend jamais le réseau, et toute
erreur (jeton absent, clé absente, FCM en échec) devient une ligne de journal.
Seuls les tours `platform: tui` (l'app) notifient ; les autres (ex. sous-agents
`subagent`) sont journalisés `skipped`, `reason: platform`.

- Commande `/hermes-mobile-token <jeton>` : mémorise le jeton FCM dans
  `HERMES_HOME\hermes-mobile\fcm-token`. L'app l'appelle elle-même
  (`command.dispatch`) avant chaque envoi de message.
- Journal : `HERMES_HOME\plugins\hermes-mobile-notify\session-end.jsonl`, une
  ligne par fin de tour (`action: sent | skipped | failed`, `status` HTTP,
  `reason`, `duration_ms`, `outcome`, métadonnées de l'essai 1) et une ligne
  `event: token` par enregistrement du jeton. Du jeton, seuls les 8 derniers
  caractères (`token_tail`) sont écrits ; `agent.log` reçoit une ligne `INFO`
  `hermes-mobile-notify …` par tour.

Auto-vérification locale : `python server/hermes-plugin/hermes-mobile-notify/__init__.py`.

Profil visé : **`.hermes` uniquement**.

## Installation (Alanc)

1. **Copie du plugin** — copier `plugin.yaml` et `__init__.py` de
   `server/hermes-plugin/hermes-mobile-notify/` vers
   `HERMES_HOME\plugins\hermes-mobile-notify\`.
2. **Clé du compte de service** — créer le dossier `HERMES_HOME\hermes-mobile\`
   et y copier `\\homeassistant.local\share\hermes-notifier\service-account.json`
   sous le nom `service-account.json`. Ne jamais la mettre dans le dossier du
   plugin ni dans le dépôt.
3. **Sauvegarde** — copier `HERMES_HOME\config.yaml` en
   `config.yaml.bak-avant-notify`.
4. **Activation** — `hermes plugins enable hermes-mobile-notify`, ou ajouter la
   ligne `- hermes-mobile-notify` à `plugins.enabled` dans `config.yaml`.
5. **Désactivation de `hermes-mobile-spike`** — il journaliserait chaque tour
   en double : `hermes plugins disable hermes-mobile-spike` (ou retirer sa ligne
   de `plugins.enabled`). Son dossier peut rester ou être supprimé.
6. **Redémarrage** — redémarrer l'add-on Hermes depuis Home Assistant.
7. **Vérification** — `hermes plugins list` montre `hermes-mobile-notify` chargé ;
   `/hermes-mobile-token` sans argument répond par l'usage ; `logs/agent.log`
   ne contient aucune erreur de chargement du plugin.

L'**observateur** (add-on `hermes-notifier`) n'est pas touché par cet essai :
si les notifications de l'observateur sont activées dans l'app, un tour peut
produire deux notifications (une de chaque source). Pour juger le plugin seul,
désactiver les notifications de l'observateur dans les réglages de l'app.

## Enregistrement du jeton

Automatique : l'app (nouvel APK) envoie `/hermes-mobile-token` avant chaque
message si le jeton FCM est disponible (permission de notification accordée).
Après le premier message envoyé depuis l'app, `HERMES_HOME\hermes-mobile\fcm-token`
existe et le journal porte une ligne `event: token`. Une erreur est ignorée par
l'app : le message part quand même.

## Désinstallation

1. `hermes plugins disable hermes-mobile-notify` (ou retirer la ligne, ou
   restaurer `config.yaml.bak-avant-notify`).
2. Supprimer `HERMES_HOME\plugins\hermes-mobile-notify\` (journal compris) et
   `HERMES_HOME\hermes-mobile\` (jeton et clé).
3. Redémarrer l'add-on.
