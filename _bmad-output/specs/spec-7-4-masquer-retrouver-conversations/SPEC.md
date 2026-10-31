---
id: SPEC-7-4-masquer-retrouver-conversations
status: done
delivery: preparation-only
story_validated: false
implemented_in: 3f3e694
updated: 2026-10-31
created: 2026-10-30
implementation_readiness: implemented-unqualified
companions:
  - implementation.md
  - ../../implementation-artifacts/epic-7-context.md
sources: []
---

# 7.4 — Masquer et retrouver des conversations

> Contrat de rédaction ; non approuvé pour développement. Lire les compagnons. Les choix proposés ci-dessous restent révisables avant le démarrage.

## Why

Alanc veut alléger son historique sans perdre ses conversations et pouvoir les retrouver ou les rétablir facilement.

## Capabilities

- **CAP-1**
  - **intent:** Masquer une conversation de la liste principale.
  - **success:** Après confirmation de la méthode retenue en 7.1, elle quitte la liste principale et un message éphémère propose « Annuler ».
- **CAP-2**
  - **intent:** Retrouver les conversations masquées.
  - **success:** La section « Masquées » charge les fils concernés, permet de les ouvrir et de les rétablir.
- **CAP-3**
  - **intent:** Garder un état compréhensible lors d’un échec.
  - **success:** Un masquage refusé laisse le fil visible ; un rétablissement refusé le conserve dans sa section, avec une erreur explicite.

## Constraints

- Les données sont cloisonnées par ConnectionKey + ProfileKey + SessionKey ; les identifiants restent opaques et sensibles à la casse.
- Hermes possède les données distantes. Une mutation passe par l’adaptateur unique, attend sa confirmation et n’est jamais rejouée automatiquement après un résultat incertain.
- Les vues ne font ni réseau ni écriture persistante ; les ViewModels commandent les repositories. Réutiliser les composants et tokens du thème, avec clavier, texte agrandi et lecteur d’écran.
- Cette spécification reste en préparation : la base isolée ne contient que le squelette Flutter. Réconcilier les chemins proposés avec les couches livrées par l’epic 6 avant implémentation ; aucun résultat de 7.1 n’est présumé.
- Le masquage utilise exclusivement la capacité retenue en 7.1 : masquage ou archivage réversible, avec stratégie vérifiée pour lister et rétablir.
- Ne pas confondre le masquage d’une conversation avec des messages internes dont display_kind est hidden.
- Ni suppression, ni purge des marqueurs 7.3, ni effacement du brouillon ou des pièces locales ne résulte d’un masquage.

## Non-goals

- Dossiers, archivage automatique, suppression et masquage strictement local en remplacement d’une capacité serveur absente.

## Success signal

Un fil masqué disparaît de l’historique principal, reste ouvrable depuis « Masquées » et retrouve la liste principale après annulation ou rétablissement confirmé.

## Assumptions

Les choix de réalisation proposés dans `implementation.md` doivent être confirmés ou ajustés au démarrage. Aucun ne constitue une capacité serveur observée.
