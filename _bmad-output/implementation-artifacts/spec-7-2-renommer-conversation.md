---
title: '7.2 — Renommer une conversation'
type: 'feature'
created: '2026-10-30'
status: 'draft'
route: 'dispatch'
implementation_readiness: 'blocked-by-dependencies'
baseline_commit: '46398f01693f05ed5f8cb9a7dac6e5fa06419b01'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/specs/spec-7-2-renommer-conversation/SPEC.md'
  - '{project-root}/_bmad-output/specs/spec-7-2-renommer-conversation/implementation.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Alanc veut reconnaître une conversation dans son historique en lui donnant un titre parlant, partagé avec Hermes et ses autres clients.

**Approche :** proposer « Renommer » sur la conversation, transmettre le nouveau titre par la méthode vérifiée et ne l'afficher qu'après confirmation distante. Conserver la saisie en cas d'échec et réconcilier les titres lors d'une actualisation.

## Boundaries & Constraints

**Toujours :** cibler ConnectionKey + ProfileKey + SessionKey, identifiants opaques sensibles à la casse. Étendre l'adaptateur et les repositories existants après intégration de leur base. Sérialiser les mutations par session, conserver les saisies, distinguer refus, absence de méthode et résultat incertain. Normaliser seulement les espaces externes du titre pour comparer et envoyer. Utiliser les composants, tokens et frontières vue/ViewModel/repository existants.

**Jamais :** créer un fil pour renommer une ancienne conversation, remplacer la fonction distante par un titre local, rejouer automatiquement une mutation incertaine ou déclarer la compatibilité serveur à partir de simulations. Ne pas modifier l'autre checkout ni ses essais. Ne pas fusionner automatiquement la base epic 6.

## I/O & Edge-Case Matrix

| Scénario | Entrée / état | Résultat attendu | Erreur |
|---|---|---|---|
| Validation | Titre non vide, différent | Une requête sur la cible exacte ; affichage après confirmation | Ancien titre et saisie conservés |
| Sans mutation | Titre vide, espaces, identique ou annulation | Aucun appel | Validation compréhensible |
| Concurrence | Double validation, changement de profil ou réponse ancienne | Une mutation en cours ; aucune projection d'une autre cible modifiée | Résultat rattaché à sa clé d'origine |
| Réponse perdue | Timeout après envoi | État incertain et actualisation proposée | Aucun rejeu automatique |
| Capacité absente | Absence explicitement vérifiée | Action indisponible expliquée | Aucun contournement |
| Confirmation différée | Réponse documentaire `pending` | Aucun succès définitif présumé | Qualification réelle préalable requise |

</frozen-after-approval>

## Open Questions

1. Base de développement manquante : autoriser l'intégration ici de la version commitée de `epic/6-interventions` après contrôle de compatibilité (rend les couches disponibles, sans toucher à l'autre checkout), ou attendre sa livraison intégrée (aucune implémentation 7.2 pour l'instant) ? La qualification réelle de 7.1 reste nécessaire dans les deux cas.

## Code Map

- `lib/main.dart` : seul écran actuel, « Hello World ». Aucun historique, adaptateur ou repository implémenté dans cette base.
- `_bmad-output/specs/spec-7-2-renommer-conversation/` : exigences et huit critères d'acceptation conservés sans modification ; les chemins proposés doivent être remplacés par les propriétaires réels.
- `_bmad-output/implementation-artifacts/spec-7-1-verifier-rangement-recherche.md` : livraison `preparation-only`, `story_validated: false` ; aucun prédécesseur validé sur installation.
- `contracts/epic-7/capabilities.json`, `verification.md` : `session.title` non vérifiée, build et preuves absents. `methods.json` est documentaire ; runtime et ID stocké distincts, réponse `pending` possible. `tool/sonde_rangement.dart` est la sonde réutilisable, pas l'adaptateur Flutter.
- Branche `epic/6-interventions`, inspection en lecture seule : `lib/data/hermes_adapter.dart` contient `HermesRpc`, `lib/data/conversation_repository.dart` possède `sessions(connection, profile)` ; `lib/models/history.dart` porte les titres ; `lib/features/history/history_view_model.dart` actualise et écarte les réponses périmées ; `history_view.dart` et `lib/ui/components/history_row.dart` affichent la liste. Ces fichiers ne sont pas intégrés ici. Le contrat de cette branche est legacy et doit être réconcilié avec les preuves de 7.1.

## Tasks & Acceptance

**Execution :**
- [ ] `contracts/epic-7/verification.md`, `capabilities.json`, `fixtures/` — qualifier `session.title` sur installation avec corpus dédié : paramètres, identités runtime/stockée, conversation ancienne, `pending`, confirmation, erreurs et propagation interclients. Aucun contrat inventé.
- [ ] `lib/data/hermes_adapter.dart` — après intégration autorisée, étendre le dialecte RPC vérifié et ses erreurs.
- [ ] `lib/data/conversation_repository.dart` — ajouter la mutation sérialisée et la réconciliation, sans publication optimiste du titre.
- [ ] `lib/features/history/history_view_model.dart`, `history_view.dart` — relier action, capacité, cible immuable et erreurs ; aucune opération réseau dans la vue.
- [ ] `lib/features/history/rename_conversation_dialog.dart` — saisie initialisée, validation, progression, annulation, conservation des erreurs et retour du focus.
- [ ] `test/features/history/rename_conversation_test.dart` et tests des propriétaires intégrés — couvrir matrice, isolation, réponse différée et actualisation distante.

**Acceptance Criteria :**
- Étant donné une modification depuis Desktop, quand l'historique est actualisé avec succès, alors le titre distant apparaît dans le seul profil concerné.
- Étant donné clavier, lecteur d'écran et texte agrandi, quand le dialogue est utilisé puis fermé, alors champ, erreur et boutons sont nommés et utilisables et le focus revient à la conversation.
- Étant donné une dépendance non vérifiée, quand le bilan est établi, alors la story reste draft et non déclarée implémentée.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

Deux dépendances bloquent le développement : base epic 6 absente et méthode distante non qualifiée. La spec de rédaction reste intacte ; ce document porte le suivi Build. Aucun effet distant n'a été effectué. L'empreinte prévue concerne les propriétaires existants et un dialogue ; aucune migration décidée.

## Verification

- Après intégration et implémentation : `rtk proxy fvm flutter analyze`, puis `rtk proxy fvm flutter test` ; utiliser le SDK épinglé si FVM est absent du PATH.
- Sur installation dédiée : preuve anonymisée du renommage, de sa confirmation et de sa visibilité après actualisation depuis deux clients ; vérifier les anciennes sessions sans création de fil.
- Sur Android : clavier, texte agrandi, lecteur d'écran, retour du focus, changement de profil et redémarrage. Les tests simulés ne prouvent pas ces validations.
