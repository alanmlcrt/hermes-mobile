# Réconciliation PRD — 20 octobre 2026

**Verdict : cohérent comme proposition en brouillon.** Aucun écart bloquant de périmètre ou omission architecturale structurante repéré dans le PRD et son addendum. Ce verdict ne valide ni l'intégration réelle, ni les choix `[ASSUMPTION]`.

Sources confrontées : `prds/prd-Hermes-Mobile-2026-10-20/prd.md`, `addendum.md`, `ARCHITECTURE-SPINE.md` et `integration-evidence.md`.

| Exigence porteuse | Atterrissage dans la proposition |
| --- | --- |
| Client de communication, exécution et configuration conservées dans Hermes ; aucune administration dédiée des profils | AD-1 ; section Différé. Les usages conversationnels restent compatibles avec l'autorité serveur. |
| FR-1/3/10 : Tailscale, authentification distincte, découverte des profils existants et conversations séparées | AD-3/7/8 ; G1 exige deux profils et historique ; preuve réelle explicitement absente. |
| FR-4/7 : longs textes, rendu et activité dépliable sans inventer d'informations internes | AD-4/10 et couverture FR-4/7 ; G2 exige un texte représentatif ; détails absents conservés absents. |
| FR-5/6 : images et documents réellement reçus dans le bon fil | AD-3/6/7 ; G2 et relevé d'intégration n° 6. L'API compatible OpenAI seule est explicitement insuffisante, conformément à l'addendum. |
| FR-8, NFR-2 : travail accepté indépendant du mobile, reprise sans renvoi implicite et sans perte du brouillon | AD-1/4/5 et conventions Brouillons ; G1 exige reprise et G3 rattrapage durable. |
| FR-9 : notification de fin app quittée, retour au bon fil | AD-9 et G3 ; notification distincte de la continuité du travail, sans dépendre d'une socket mobile vivante. Le nouveau composant serveur reste proposé et à rendre déployable. |
| FR-12 : arrêt demandé distinct de l'arrêt confirmé, sans annulation des effets passés | AD-5, G1 ; contrôle lié à l'exécution observée et absence de confirmation sur perte réseau. |
| FR-13/14 et saisie pendant le travail encore à trancher | G4 ; pas d'adoption implicite des approbations, de leur politique ou de la récupération des résultats. AD-5 conserve la saisie pendant cette indécision. |
| NFR-1/3/4 : accessibilité, secrets protégés, capacité obligatoire manquante bloquante | AD-7/8/10/11 ; notifications et portes de validation maintiennent l'obligation au lieu de la remplacer par un avertissement. |
| Android personnel et futur iPhone ; reports encore proposés | Graine Flutter Android/iOS, livraison iOS distincte ; Différé conserve les reports et l'exclusion de l'administration. |

## Limites conservées correctement

- **G1 reste bloquante avant validation et stories d'intégration.** « Dernière version » et Tailscale ne prouvent pas le dépôt/build, l'URL native, l'authentification ou les contrats de l'add-on. L'évidence amont épinglée n'est pas présentée comme celle du serveur personnel.
- **G2/G3 restent à démontrer de bout en bout.** Corpus utilisateur, octets reçus côté Hermes, notifications sur téléphone réel et reprise après panne ne sont pas remplacés par des fixtures ou une simulation.
- **G4 conserve les décisions produit ouvertes.** Issues notifiées, interventions et FR-13/14 ne doivent pas devenir des exigences adoptées par simple découpage de stories.

Les détails de parcours ou de rendu propres au PRD restent à lire avec les documents UX ; les recopier sous forme de nouveaux AD n'améliorerait pas la convergence des unités de développement.
