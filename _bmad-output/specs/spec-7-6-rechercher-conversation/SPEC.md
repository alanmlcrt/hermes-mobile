---
id: SPEC-7-6-rechercher-conversation
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

# 7.6 — Rechercher une conversation

> Contrat de rédaction ; non approuvé pour développement. Lire les compagnons. Les choix proposés ci-dessous restent révisables avant le démarrage.

## Why

Alanc veut retrouver un fil en quelques mots, sans parcourir tout son historique et sans confondre les profils.

## Capabilities

- **CAP-1**
  - **intent:** Rechercher dans les titres, aperçus et contenus déjà chargés.
  - **success:** Les résultats ignorent casse et accents ; les passages correspondants sont mis en évidence dans le texte original.
- **CAP-2**
  - **intent:** Compléter par la recherche serveur si disponible.
  - **success:** La méthode vérifiée en 7.1 est utilisée et fusionnée sans doublon ; sinon la couverture locale est explicitement indiquée.
- **CAP-3**
  - **intent:** Rechercher dans tous les profils de la connexion.
  - **success:** L’option « Tous les profils » regroupe les résultats par profil identifié ; ouvrir un résultat conserve sa cible complète.
- **CAP-4**
  - **intent:** Comprendre une absence de résultat ou une erreur.
  - **success:** L’état vide est distinct du chargement, d’un échec et de résultats partiels accompagnés d’une erreur.

## Constraints

- Les données sont cloisonnées par ConnectionKey + ProfileKey + SessionKey ; les identifiants restent opaques et sensibles à la casse.
- Hermes possède les données distantes. Une mutation passe par l’adaptateur unique, attend sa confirmation et n’est jamais rejouée automatiquement après un résultat incertain.
- Les vues ne font ni réseau ni écriture persistante ; les ViewModels commandent les repositories. Réutiliser les composants et tokens du thème, avec clavier, texte agrandi et lecteur d’écran.
- Cette spécification reste en préparation : la base isolée ne contient que le squelette Flutter. Réconcilier les chemins proposés avec les couches livrées par l’epic 6 avant implémentation ; aucun résultat de 7.1 n’est présumé.
- Aucun chargement de tous les historiques distants pour simuler une recherche plein texte ; le cache existant fixe la couverture locale.
- Une réponse obsolète ne remplace pas les résultats de la requête ou du profil courant. Les requêtes ne traversent pas les connexions.
- Ne pas indexer les messages internes masqués, secrets ou pièces jointes ; seuls les contenus affichables déjà présents et les données de liste sont concernés.
- Une capacité de recherche non vérifiée n’est pas activée. Un refus ou une panne ne devient pas « aucun résultat ».

## Non-goals

- OCR, analyse de pièces jointes, recherche web, recherche floue, synchronisation intégrale hors ligne et recherche entre plusieurs connexions.

## Success signal

Le texte « resume » retrouve « Résumé » dans un titre ou un message déjà chargé, avec le bon passage et le bon profil ; une recherche vide et une panne produisent des états distincts.

## Assumptions

Les choix de réalisation proposés dans `implementation.md` doivent être confirmés ou ajustés au démarrage. Aucun ne constitue une capacité serveur observée.
