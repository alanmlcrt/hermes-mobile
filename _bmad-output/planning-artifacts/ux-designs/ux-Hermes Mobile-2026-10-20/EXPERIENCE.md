---
name: Hermes Mobile
status: draft
updated: 2026-10-20
language: fr
sources:
  - ../../prds/prd-Hermes-Mobile-2026-10-20/prd.md
  - ../../prds/prd-Hermes-Mobile-2026-10-20/addendum.md
  - .memlog.md
---

# Hermes Mobile — Expérience

## Foundation

**Confirmé.** Application Android personnelle pour Alanc ; iPhone anticipé. L'application est l'interface de son Hermes existant : il choisit un profil et lui demande par conversation d'interagir avec un MCP déjà présent. Hermes possède les capacités et effectue le travail.

[DESIGN.md](DESIGN.md) est la référence visuelle. Aucun système de composants ni stack n'est choisi. Le thème suit automatiquement le mode clair/sombre du téléphone et ses couleurs sur Android. Les tokens visuels étant encore vides, aucune référence de token n'est inventée dans ce brouillon.

Le [PRD](../../prds/prd-Hermes-Mobile-2026-10-20/prd.md) reste la source des exigences. Ci-dessous : **exigence PRD** = socle à couvrir ; **proposé** = hypothèse à confirmer ; **dépendance architecture** = comportement non garanti par le serveur à ce stade.

**Accord MVP et évolution.** Alanc accepte la base visuelle actuelle pour le premier MVP et demande qu’elle puisse évoluer, y compris par une refonte. L’architecture et le développement doivent reprendre les [contraintes de design évolutif](ui-evolution-requirements.md) : présentation, composants et illustrations remplaçables ; état des conversations et communication avec Hermes indépendants de leur rendu. Une modification visuelle ne doit ni perdre un brouillon ni relancer un outil. Les [maquettes acceptées](mockups/exchange-conversation.html) servent de référence de départ, pas de logique de production.

## Information Architecture

Surfaces **logiques**, pouvant partager un même écran. Leur présentation de navigation n'est pas décidée.

| Surface | Accès connu / à définir | Besoin porté |
| --- | --- | --- |
| Connexion | Première association ou connexion refusée ; mécanisme ouvert. | FR-1 : accès à Hermes. |
| Profils et historique | Alanc choisit un profil ; accès visuel à définir. | FR-3/FR-10 : profils existants et conversations distinctes. |
| Conversation | Profil choisi ; nouvelle conversation à l'ouverture normale selon FR-2. | FR-4/FR-8 : demande et lecture, continuité du travail. |
| Préparation des pièces jointes | Depuis une demande ; commande à définir. | FR-5/FR-6 : fichiers avant envoi et dans l'historique. |
| Suivi et détails | Dans la conversation, détails à déplier. | FR-7/FR-12 : comprendre l'activité et demander l'arrêt. |
| Retour de fin | Notification hors app vers la conversation concernée. | FR-9 : retrouver le travail terminé. |
| Intervention / résultat | Dans la conversation, si retenus et disponibles. | FR-13/FR-14 **proposés**, à trancher avec l'architecture. |

Aucun écran d'administration ou de consultation de la configuration des profils au MVP. La fermeture des parcours n'est pas acquise : seul le début de la session centrale est raconté.

## Voice and Tone

**Confirmé.** Mots du quotidien, interface compréhensible sans connaissances techniques. Les termes métier Profil et Conversation suivent le PRD. Les détails exacts d'Hermes restent accessibles sans dominer le fil ; microcopies précises à rédiger après choix des surfaces.

## Component Patterns

Les noms correspondent au tableau Components de DESIGN.md ; ce sont des regroupements logiques, sans choix de widgets.

| Composant logique | Règle comportementale issue du PRD |
| --- | --- |
| Connexion | Distinguer serveur inaccessible et authentification refusée ; QR/lien et secours manuel **proposés**. |
| Choix du profil | Sélectionner un profil existant et reconnaître le profil actif sans le reconfigurer. |
| Historique | Retrouver les conversations du profil ; ne pas mélanger leurs messages et fichiers. |
| Conversation | Lire le texte enrichi et le code ; streaming **proposé**. Ouvrir normalement une nouvelle conversation par défaut selon FR-2. |
| Saisie et envoi | Accepter les longs textes sans commandes `/` courantes ; préserver le brouillon en cas de coupure (NFR-2). |
| Pièce jointe | Transmettre au bon fil ; liste, retrait, aperçu et limites préalables **proposés**. |
| Suivi et détails | Présenter une synthèse puis les détails réellement exposés par Hermes ; aucun contenu interne inventé. |
| Arrêt | Demander l'arrêt depuis le fil ; attendre une confirmation du serveur avant de le présenter comme arrêté. |
| Notification de fin | Retrouver la conversation ; livraison Android app fermée à vérifier. Issues notifiées détaillées **proposées**. |
| Intervention / résultat | FR-13/FR-14 **proposés** : demande réellement émise par Hermes et fichier réellement accessible ; capacité serveur à vérifier. |

## State Patterns

Traitement minimal source ; libellés finaux et position restent ouverts.

| Surface | États à distinguer / statut |
| --- | --- |
| Connexion | Inaccessible et authentification refusée ; chargement et retour après échec à préciser. |
| Profils et historique | Profil actif ; chargement, liste vide et erreur de profils **proposés** ; historique vide et reprise à préciser. |
| Conversation | Envoi, travail, fin, erreur et état inconnu/non synchronisé **proposés** ; absence de perte du brouillon et de nouvelle exécution silencieuse exigée. |
| Préparation des pièces jointes | Sélection, envoi et échec visibles **proposés** ; échec ne vaut pas réception par Hermes. Permissions du téléphone à préciser. |
| Suivi et détails | Demande d'arrêt envoyée distincte d'arrêt confirmé ; perte réseau ne confirme jamais l'arrêt. |
| Retour de fin | Travail continuant hors app exigé ; notification de fin exigée ; refus de permission et lien de retour à préciser. |
| Intervention / résultat | Attente d'une réponse/autorisation et disponibilité d'un fichier **proposées**, sous réserve FR-13/FR-14. |

La coupure ne doit pas masquer l'échec ni déclencher une duplication silencieuse (NFR-2). Une reprise sans renvoi automatique est proposée par FR-8. Aucun envoi hors ligne ou cache complet n'est spécifié. Secrets absents des erreurs et diagnostics (NFR-3).

## Interaction Primitives

Toucher et clavier mobile doivent permettre les parcours essentiels (NFR-1). Choisir un profil, écrire, joindre, déplier les détails et demander l'arrêt sont les interactions requises. Gestes, placement des actions, comportement de Retour et prise de focus restent à définir ; aucune commande `/` imposée pour les actions courantes.

**Demande confirmée :** animations de chargement adaptées au type de tâche, représentées par des objets simples, avec davantage de mouvement et plus de familles inspirées des indicateurs Discord. La [maquette simplifiée](.working/simple-conversation.html) propose [17 familles](.working/activity-catalogue.md). La [recherche amont](.working/hermes-tool-activity-research.md) vérifie 27 outils avec leurs emojis et leur chemin de progression vers les adaptateurs. Le client doit identifier une action par un événement fiable, jamais par un emoji personnalisable ou une supposition sur le nom d’un outil MCP. Le transport réel et les capacités de l’installation personnelle restent à établir.

Pause, réduction des mouvements, arrêt hors écran et état générique sont prévus. Les dessins accompagnent un libellé lisible ; ils ne représentent ni pourcentage ni mesure réelle du travail. Le sélecteur de tâche, le catalogue défilant et la démo automatique appartiennent uniquement à l’aperçu : pas d’enchaînement de tâches réelles. Cette démo respecte pause, onglet masqué et mouvement réduit ; une action manuelle l’arrête. Le rendu Anatomy précédent a été rejeté ; le catalogue et son dynamisme attendent un retour visuel.

**Ajustement confirmé ensuite :** activité présentée sous forme compacte, avec petite illustration à côté du texte. Préparation de réponse et activité inconnue : trois petits points tournants, sans bulle, immobiles sous réduction des mouvements. Écriture du code : ordinateur fixe, mouvement interne seulement. Les détails restent dépliables pour les actions ; la préparation générique n’invente pas de détails. Le contrôle d’arrêt reste accessible même lorsque l’indicateur est réduit. Voir la [recherche Sparky](.working/sparky-reference.md) pour l’inspiration et les différences voulues par Alanc.

## Accessibility Floor

Exigences NFR-1 : clavier affiché, texte agrandi et lecteur d'écran utilisables ; icônes d'action avec libellé accessible ; états exprimés autrement que par la couleur. Contrastes visuels dans DESIGN.md, encore à vérifier. Ordre de lecture, annonces des états et gestion du focus restent à préciser lors de la composition.

## Inspiration & Anti-patterns

[Muse](https://ai.meta.com/muse/) et [Grok Bot](https://x.ai/bot) : références choisies par Alanc pour une interface simple. La [recherche](.working/reference-research.md) relève conversation, délégation et suivi compréhensible ; cette interprétation ne valide pas leurs écrans ni toutes leurs fonctions. Éviter de demander à Alanc d'administrer les MCP depuis l'app ou d'imposer une vue technique principale.

## Responsive & Platform

Android d'abord ; iPhone anticipé, sans choix d'adaptation arrêté. Les mêmes fonctions doivent rester lisibles dans les deux modes système. Les couleurs dynamiques Android et leur secours sont décrits dans DESIGN.md ; aucune grille tablette, breakpoint ou interface desktop n'est décidé.

## Key Flows

### Alanc — Demander une interaction avec un MCP existant

1. **Récit utilisateur confirmé :** Alanc sélectionne un profil.
2. **Récit utilisateur confirmé :** il lui demande d'interagir avec un MCP présent sur son Hermes.

**Suite dérivée du PRD, non racontée ni validée comme parcours :** suivre le travail dans la conversation (FR-7), lire sa réponse (FR-4), retrouver sa fin après avoir quitté l'app (FR-8/FR-9).

**Climax à confirmer :** le moment précis où Alanc juge sa demande accomplie n'a pas été décrit. Aucun résultat MCP concret n'est inventé. **Échec à couvrir selon NFR-2/FR-12 :** brouillon conservé après coupure, pas de duplication silencieuse, arrêt non confirmé tant qu'Hermes ne l'a pas confirmé.

Les parcours connexion, historique, fichiers, arrêt et retour par notification restent à compléter ; leur présence dans l'IA ne constitue pas une validation de session. Les hypothèses du PRD et FR-13/FR-14 restent ouvertes.

### Scène de démonstration — échange complet

La [scène animée complète](.working/exchange-conversation.html) répond à la demande d’Alanc de voir l’enchaînement de A à Z. Le contenu est fictif, sans outil réel ni extension du périmètre produit.

1. Le message apparaît dans la saisie puis est envoyé.
2. Hermes prend en compte la demande ; trois petits points tournent.
3. Un appel MCP illustré récupère des tâches ; une recherche puis une lecture de fichier consultent des notes.
4. Un outil illustré crée le résumé ; les lignes d’activité terminées portent un signe de fin.
5. Le groupe d’outils se replie ; les trois points reviennent pour la préparation finale.
6. La réponse apparaît progressivement.
7. **Climax illustré :** le fichier `resume.md` apparaît et son contenu d’exemple peut être ouvert.

Rejouer, pause, vitesse, position et sauts d’étape servent uniquement à examiner la maquette. La scène s’arrête après une lecture ; sous réduction des mouvements elle démarre en pause, ses figures restent immobiles et la réponse n’est pas tapée caractère par caractère. Ce récit d’illustration ne remplace pas un parcours utilisateur validé et ne tranche pas les capacités serveur encore proposées dans le PRD.
