# Salons — contrat documentaire

status: documentary

Aucun appel réel, aucune fixture issue de l'installation, aucune validation G5.
`methods.json` extrait les déclarations legacy ET canoniques et leurs schémas
référencés du fichier OpenRPC versionné. Des déclarations diffèrent : l'app utilise
le dialecte legacy annoncé par `groups.capabilities.methods`, sans repli canonique.
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
