# Salons — contrat documentaire

status: documentary

Aucun appel réel, aucune fixture issue de l'installation, aucune validation G5.
`methods.json` extrait les déclarations legacy ET canoniques et leurs schémas
référencés du fichier OpenRPC versionné. Des déclarations diffèrent : l'app utilise
les méthodes annoncées par `groups.capabilities.methods`, sans essayer un autre
dialecte après un refus. `retry` suit les paramètres legacy (`task_id`) ; `discard`
utilise le contexte complet du schéma canonique, uniquement si la méthode est
annoncée. Les autorisations utilisent les quatre identifiants de la demande.
Aucun événement poussé de salon n'est déclaré dans `x-notifications` : reprise
par `groups.state` et journal paginé `groups.log`, ordonné par `seq`.
`groups.send` documente l'idempotence par `event_id`, mais elle n'a pas été
constatée sur l'installation : un envoi incertain reste à vérifier, sans rejeu.
`driver: true` décrit le pilote serveur ; sa continuité app fermée reste à tester.
La modification des membres n'a pas de méthode documentée.

## Activer Bot Mode sur deux profils (Alan uniquement)

1. Ouvrir `\\homeassistant.local\addon_configs\0a6523c6_hermes_agent\.hermes\`.
   Repérer les `profile.yaml` de **deux profils de test existants** en vérifiant
   leur nom ; ne pas modifier les autres profils ni le profil global par défaut.
2. Copier chacun de ces deux fichiers en `profile.yaml.before-epic-8`.
3. Dans chacun, fusionner la clé ci-dessous avec le bloc `ui_meta` existant
   (ne pas créer deux blocs YAML du même nom) :

   ```yaml
   ui_meta:
     hermes-bots: true
   ```

4. Conserver la configuration `agent.bot_mode_protocol` existante. Le contrat
   fourni ne documente ni sa valeur ni son éventuelle nécessité : si Hermes
   refuse l'activation, relever le message et la version avant toute autre
   modification ; ne pas inventer une valeur de protocole.
5. Recharger/redémarrer l'add-on Hermes si nécessaire, puis ouvrir Salons dans
   l'app. Les deux profils doivent être proposés comme éligibles ; sinon relever
   le message. Cette procédure est documentaire, pas encore vérifiée sur l'add-on.
6. Pour annuler : restaurer uniquement ces deux sauvegardes, puis recharger
   l'add-on. Garder les sauvegardes jusqu'à la fin des essais.

## Points encore non vérifiés

Forme réelle des payloads de messages, activités, escalades et autorisations ;
erreurs du serveur ; Bot Mode sur l'add-on ; arrêt confirmé ; idempotence ;
limites de tours ; notifications app fermée. Aucun hook de notification salon
n'est décrit par OpenRPC. Ne pas présenter une notification locale comme une
preuve de notification app fermée. Les fichiers restent hors périmètre 8.1–8.7.

## Conventions préparées dans l'app, à confirmer au téléphone

- Messages : `message.*`, texte dans `payload.text`, attribution par `actor.id`
  rapproché du `member_id` ou du profil ; activités `tool.start` / `tool.complete`.
- Escalade dans le fil : mention `@user` d'un message d'agent ; attente globale
  selon `driver_status.blocked`. Les seuils de 10 messages / 3 tours ne sont
  jamais calculés côté téléphone à partir de suppositions.
- Tâches : `driver_status.pending_actions`, `kind: retry`, `task_id`, état explicite
  `failed` pour réessayer. Un résultat inconnu n'offre jamais Réessayer ; Abandonner
  requiert aussi `member_id` et `execution_generation`.
- Autorisations : action `kind: approval`, champs `request_id`, `task_id`,
  `member_id`, `execution_generation`, `description`, `command`. Si l'identité ou
  le contenu manque, la carte l'explique et ses décisions restent indisponibles.
  Les cartes résolues restent pendant l'ouverture du fil ; leur historique après
  redémarrage dépend des événements réellement fournis par Hermes.
- Notifications : réception préparée pour `{roomId, outcome}` avec les issues
  `needs_user` / `approval`, libellé générique et regroupement Android par salon.
  Aucun relais Hermes n'est installé ni modifié. **La livraison app fermée reste
  à qualifier et peut être absente.** Une cible inconnue ou ambiguë ouvre l'accueil
  avec explication. Le salon doit avoir été chargé localement au moins une fois.
- Journal : relecture complète paginée, contrôle de la continuité des séquences,
  conservation du dernier cache si une page échoue. Le volume important n'a pas
  encore été mesuré ; le fil est actualisé tant que l'app est au premier plan.

Ces conventions sur des objets JSON ouverts ne sont pas des fixtures observées.
Les tests automatisés simulent le contrat et ne valident pas l'installation.
