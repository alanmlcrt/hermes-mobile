# Observations partielles au téléphone — 2026-10-31

status: partial-app-observation

Alan a relevé dans Salons, release 30 :

```json
{
  "driver": true,
  "persistent_process": true,
  "protocol_version": 2,
  "seatable_profiles": null,
  "methods_count": 18
}
```

Transcription de l'écran, **pas une capture brute de la réponse RPC** : l'écran
ne permet pas de distinguer un champ `seatable_profiles` absent d'un champ null,
ni d'identifier les 18 méthodes. Aucun contenu, secret ni identifiant de salon.

Ce constat confirme que l'app reçoit l'annonce d'un pilote actif et persistant.
Il ne prouve pas encore la création, l'envoi, l'arrêt ou les notifications.
La release 31 corrige le blocage client causé par la liste optionnelle manquante.
Le contrat global reste documentaire et les stories restent non validées.

## Retour sur la release 31

Alan confirme « ok parfait ça marche » après l'essai demandé de création et
d'envoi. Il signale ensuite des handles agent1/agent2 et une zone de saisie trop
haute. Ce retour confirme le parcours de base, sans valider tous les critères
d'arrêt, de reprise ou de notification. La release 32 corrige l'interface.
