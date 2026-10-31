---
id: SPEC-7-5-supprimer-conversation
status: done
delivery: validated
story_validated: true
validated: 2026-10-31
validation: essai Alanc sur téléphone (APK release 25/26) contre Hermes installé
implemented_in: 3f3e694
updated: 2026-10-31
created: 2026-10-30
implementation_readiness: implemented
companions:
  - implementation.md
  - ../../implementation-artifacts/epic-7-context.md
sources: []
---

# 7.5 — Supprimer une conversation

> Contrat de rédaction ; non approuvé pour développement. Lire les compagnons. Les choix proposés ci-dessous restent révisables avant le démarrage.

## Why

Alanc veut supprimer définitivement un fil depuis le téléphone, avec la certitude de ce qui est effacé dans Hermes et localement.

## Capabilities

- **CAP-1**
  - **intent:** Confirmer une suppression définitive dans Hermes.
  - **success:** Le dialogue explique la conséquence distante ; seule une confirmation déclenche session.delete et la liste change après une réponse positive.
- **CAP-2**
  - **intent:** Protéger les conversations occupées ou incertaines.
  - **success:** Un travail en cours ou un envoi non résolu bloque la suppression avec explication ; un résultat incertain conserve le fil et ses données locales.
- **CAP-3**
  - **intent:** Nettoyer les données locales et gérer les liens tardifs.
  - **success:** Après confirmation, brouillon, pièces locales, épingle et marqueur sont supprimés ; une notification tardive ouvre l’accueil avec « conversation supprimée ».

## Constraints

- Les données sont cloisonnées par ConnectionKey + ProfileKey + SessionKey ; les identifiants restent opaques et sensibles à la casse.
- Hermes possède les données distantes. Une mutation passe par l’adaptateur unique, attend sa confirmation et n’est jamais rejouée automatiquement après un résultat incertain.
- Les vues ne font ni réseau ni écriture persistante ; les ViewModels commandent les repositories. Réutiliser les composants et tokens du thème, avec clavier, texte agrandi et lecteur d’écran.
- Cette spécification reste en préparation : la base isolée ne contient que le squelette Flutter. Réconcilier les chemins proposés avec les couches livrées par l’epic 6 avant implémentation ; aucun résultat de 7.1 n’est présumé.
- La suppression est irréversible côté serveur ; aucune annulation fictive. Une méthode absente désactive la fonction.
- Les protections sont réévaluées à la confirmation, puis dans la commande sérialisée : absence de socket ou ancienne fin de tour ne prouve pas l’inactivité.
- Un timeout ne justifie aucun effacement local ni nouveau session.delete. Une absence dans une liste partielle, filtrée ou excluant les masquées ne prouve pas la suppression.
- Effacer uniquement les fichiers privés appartenant à la clé ciblée ; ne pas supprimer un fichier externe choisi sur le téléphone ni une référence encore utilisée par un autre brouillon.

## Non-goals

- Suppression de masse, purge de profils, corbeille, restauration distante et suppression des données d’un autre client.

## Success signal

Une suppression confirmée enlève le fil et ses données privées, bloque les courses avec les envois et tolère une notification tardive sans recréer la conversation.

## Assumptions

Les choix de réalisation proposés dans `implementation.md` doivent être confirmés ou ajustés au démarrage. Aucun ne constitue une capacité serveur observée.
