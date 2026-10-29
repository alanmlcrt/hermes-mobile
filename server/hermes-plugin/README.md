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
