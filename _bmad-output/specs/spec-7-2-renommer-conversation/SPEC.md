---
id: SPEC-7-2-renommer-conversation
status: draft
created: 2026-10-30
implementation_readiness: blocked-by-dependencies
companions:
  - implementation.md
  - ../../implementation-artifacts/epic-7-context.md
sources: []
---

# 7.2 — Renommer une conversation

> Contrat de rédaction ; non approuvé pour développement. Lire les compagnons. Les choix proposés ci-dessous restent révisables avant le démarrage.

## Why

Alanc veut reconnaître immédiatement un fil dans son historique en lui donnant un titre parlant, partagé avec les autres clients Hermes.

## Capabilities

- **CAP-1**
  - **intent:** Renommer depuis le menu de la conversation.
  - **success:** Un titre non vide et différent est envoyé une seule fois à la conversation ciblée ; il apparaît après confirmation serveur.
- **CAP-2**
  - **intent:** Réessayer sans perdre la saisie après un échec.
  - **success:** Le titre confirmé reste affiché ; le message explique l’échec ou l’incertitude et le texte saisi demeure disponible.
- **CAP-3**
  - **intent:** Retrouver les modifications des autres clients.
  - **success:** Après actualisation réussie, le titre confirmé par Hermes est affiché dans l’historique du bon profil.

## Constraints

- Les données sont cloisonnées par ConnectionKey + ProfileKey + SessionKey ; les identifiants restent opaques et sensibles à la casse.
- Hermes possède les données distantes. Une mutation passe par l’adaptateur unique, attend sa confirmation et n’est jamais rejouée automatiquement après un résultat incertain.
- Les vues ne font ni réseau ni écriture persistante ; les ViewModels commandent les repositories. Réutiliser les composants et tokens du thème, avec clavier, texte agrandi et lecteur d’écran.
- Cette spécification reste en préparation : la base isolée ne contient que le squelette Flutter. Réconcilier les chemins proposés avec les couches livrées par l’epic 6 avant implémentation ; aucun résultat de 7.1 n’est présumé.
- Une méthode absente désactive « Renommer » avec une explication ; aucun renommage exclusivement local ne remplace la fonction serveur.
- 7.1 doit préciser la résolution entre session stockée et runtime, notamment pour une conversation ancienne ; ne pas créer de nouveau fil pour la renommer.

## Non-goals

- Renommage automatique, création de conversation, renommage des profils et rangement par dossiers.

## Success signal

Un fil renommé depuis le téléphone est retrouvé sous son nouveau titre après actualisation sur le téléphone et un autre client, sans perte de saisie lors d’un échec.

## Assumptions

Les choix de réalisation proposés dans `implementation.md` doivent être confirmés ou ajustés au démarrage. Aucun ne constitue une capacité serveur observée.
