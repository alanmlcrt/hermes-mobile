---
id: SPEC-7-3-epingler-marquer-non-lu
status: done
delivery: validated
story_validated: true
validated: 2026-10-31
validation: essai Alanc sur téléphone (APK release 25/26) contre Hermes installé
implemented_in: bb23229
updated: 2026-10-31
created: 2026-10-30
implementation_readiness: implemented
companions:
  - implementation.md
  - ../../implementation-artifacts/epic-7-context.md
sources: []
---

# 7.3 — Épingler et marquer non lu

> Contrat de rédaction ; non approuvé pour développement. Lire les compagnons. Les choix proposés ci-dessous restent révisables avant le démarrage.

## Why

Alanc veut garder ses fils importants en tête et reconnaître les conversations où un travail est terminé depuis sa dernière consultation.

## Capabilities

- **CAP-1**
  - **intent:** Épingler et désépingler une conversation sur le téléphone.
  - **success:** Les épingles persistent par connexion/profil/session après redémarrage et précèdent les autres lignes dans l’ordre d’épinglage.
- **CAP-2**
  - **intent:** Reconnaître et contrôler l’état non lu.
  - **success:** Une fin de tour confirmée non consultée marque le fil non lu ; l’ouverture le marque lu et l’action « Marquer non lu » le rétablit.
- **CAP-3**
  - **intent:** Supprimer les marqueurs devenus sans objet.
  - **success:** Une disparition distante confirmée entraîne le retrait de l’épingle et du marqueur sans effacer ceux des autres conversations.

## Constraints

- Les données sont cloisonnées par ConnectionKey + ProfileKey + SessionKey ; les identifiants restent opaques et sensibles à la casse.
- Hermes possède les données distantes. Une mutation passe par l’adaptateur unique, attend sa confirmation et n’est jamais rejouée automatiquement après un résultat incertain.
- Les vues ne font ni réseau ni écriture persistante ; les ViewModels commandent les repositories. Réutiliser les composants et tokens du thème, avec clavier, texte agrandi et lecteur d’écran.
- Cette spécification reste en préparation : la base isolée ne contient que le squelette Flutter. Réconcilier les chemins proposés avec les couches livrées par l’epic 6 avant implémentation ; aucun résultat de 7.1 n’est présumé.
- Épingle et lecture restent locales au téléphone ; aucune méthode Hermes de marquage n’est inventée.
- Réussite, erreur et arrêt confirmé sont des fins de tour ; coupure, silence réseau et demande d’arrêt ne le sont pas.
- L’absence dans une page, un filtre, une liste tronquée ou une liste excluant les fils masqués ne prouve jamais une suppression.

## Non-goals

- Synchronisation des marqueurs entre appareils, ordre manuel par glisser-déposer, compteur de messages non lus et notifications supplémentaires.

## Success signal

Après redémarrage, les épingles restent ordonnées et une fin réellement nouvelle reste non lue jusqu’à consultation, sans réapparaître sur replay du même événement.

## Assumptions

Les choix de réalisation proposés dans `implementation.md` doivent être confirmés ou ajustés au démarrage. Aucun ne constitue une capacité serveur observée.
