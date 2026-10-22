# Epic 3 Context: Suivre le travail de Hermes et l'arrêter

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Rendre le travail de Hermes compréhensible dans la conversation par des activités compactes, illustrées et dépliables, puis permettre d'en demander l'arrêt en distinguant l'intention locale de la confirmation serveur. Le mobile présente uniquement les informations réellement exposées : aucun détail supposé, raisonnement privé, pourcentage de progression ou terminal déduit du silence réseau.

## Stories

- Story 3.1: Voir l'activité de Hermes en lignes compactes
- Story 3.2: Déplier les détails d'une action
- Story 3.3: Reconnaître l'activité grâce aux illustrations animées
- Story 3.4: Compléter le catalogue des familles d'activité
- Story 3.5: Demander l'arrêt du travail en cours

## Requirements & Constraints

- Montrer une synthèse lisible du travail ; les détails techniques disponibles restent accessibles à la demande. Une information absente reste absente. Un événement inconnu conserve un rendu générique sans qualification inventée.
- Identifier les actions par les identités serveur disponibles et les familles par un mapping fiable ; un emoji personnalisable, une minuterie ou un nom d'outil MCP supposé ne prouvent aucune famille.
- Une fin d'action exige une preuve de fin d'action ; une fin du travail exige un terminal serveur. Connexion, acceptation d'envoi, exécution et arrêt demandé sont des états distincts.
- La demande d'arrêt n'annule pas les effets déjà produits. Son contrôle doit rester atteignable avec indicateur réduit, clavier affiché, texte agrandi et lecteur d'écran.
- Vérifier événements, champs et capacités sur le build installé. Une présence documentaire ou une fixture synthétique ne valide pas l'installation personnelle ; une capacité obligatoire absente revient à Alanc et ne se contourne pas silencieusement.
- Implémenter dans l'ordre 3.1 à 3.5, réutiliser les composants existants et préserver les quatre lots approuvés du compagnon. Faire approuver dans chaque spécification les arbitrages UX encore ouverts avant de coder.

## Technical Decisions

- Hermes reste propriétaire des profils, exécutions, outils et historiques. Un adaptateur unique traduit le contrat Hermes ; ni accès aux bases privées ni nouveau moteur d'agent mobile.
- La projection distante appartient au repository de conversation ; les intentions locales persistées appartiennent à l'outbox. Les vues présentent les données et transmettent les actions sans réseau ou persistance directe.
- Cloisonner toute activité et opération par connexion, profil et session ; les identités distantes sont opaques. Sérialiser les mutations par session, dédupliquer avant application et ignorer les événements d'un ancien contexte.
- Le mapping déclaratif partagé gouverne états, terminaux et `ActivityKind`. Le catalogue visuel consomme ces familles sans connaître le protocole. Les reprises utilisent le rejeu uniquement si la capacité est détectée, sinon un snapshot ; aucun rendu ne rejoue d'action.
- Persister l'arrêt avec sa cible avant transmission. `stopRequested` provient de l'opération locale et n'est jamais injecté dans la projection distante. Une issue incertaine reste inconnue, sans répétition automatique ; un contrôle limité à la session ne doit jamais être rejoué sur le tour suivant.
- Styles, dimensions et mouvements restent centralisés ; remplacer une illustration ne modifie ni le décodage des événements ni les appels Hermes.

## UX & Interaction Patterns

- Activités courtes près de petites illustrations ; détails dépliables et synthèse du groupe lorsque le travail passe à la réponse. Les dessins accompagnent un libellé et ne mesurent aucun avancement.
- Le catalogue couvre 17 familles avec repli générique et variantes immobiles. L'ordinateur de code garde son châssis fixe ; seuls lignes et curseur bougent. Pause, mouvement réduit, hors écran et arrière-plan suspendent le mouvement sans changer le travail.
- Les contrats approuvés du compagnon prévalent sur les propositions historiques : anatomie v5, Otc constant, chatouilles locales, pause et suspension conservées ; fond du profil mémorisé localement par identité, fond de conversation neutre.
- En conversation, conserver le carré de 64 px dès l'acceptation et après le terminal, une réservation commune par tour et une seule interaction sur le dernier tour. Placement latéral à largeur utile ≥360 px et texte <150 %, sinon avant le texte ; le clavier seul ne change pas ce placement.
- `WorkStateLabel` reste l'autorité, avec sa région live unique près de la saisie, hors liste paresseuse. Aucun dessin ne double l'annonce du statut ni ne retarde sa mise à jour.
- **Décisions UX approuvées en 3.1, 3.2 et 3.3 :** emplacement d'illustration de 24 px, repère neutre et texte « Fin reçue » (accessible « Fin d'action reçue »), repli automatique en « N activités » au premier fragment non vide (avec nombre sans fin confirmée), ligne entière comme commande de 48 px minimum avec chevron lorsqu'un détail est reçu, corps sélectionnable et défilable en texte/JSON, maintien ouvert du groupe au premier fragment après consultation volontaire d'un détail, et catalogue `ActivityCatalog` indexé par `ActivityKind` (`code` à châssis fixe aux traits épais + lignes/curseur mobiles, `tool` à clé oscillante + impulsion, `unknown` / repli à trois petits points en rotation 24 × 24 px sans bulle, Otc restant seul porteur de la préparation de réponse du tour ; immobilisation immédiate sous mouvement réduit, pause de la page, `completed: true`, hors écran et arrière-plan).
- **À arbitrer dans les spécifications restantes (3.4 à 3.5) :** en 3.4, compléter le catalogue des 17 familles sur les seules associations serveur vérifiées ; en 3.5, arbitrer le placement et l'apparence de la commande d'arrêt.
- Étendre la galerie avec données fictives clairement séparées du réel ; vérifier clair/sombre, petit écran, clavier ouvert, texte à 200 %, mouvement réduit, cibles tactiles, noms accessibles, focus et absence de chevauchement. Les preuves automatisées ne remplacent pas un essai lecteur d'écran sur téléphone.

## Cross-Story Dependencies

Les stories s'appuient sur le contrat de connexion et les capacités de l'Epic 1, puis sur l'envoi, la projection, la reprise et l'historique de l'Epic 2. Les illustrations et leurs variantes dépendent du mapping fiable établi pour les lignes ; les détails ne peuvent exposer que les champs disponibles. L'arrêt réutilise les garanties de persistance et de reprise sans renvoi, et sa confirmation doit rester compatible avec le mapping terminal partagé des notifications futures. Les quatre specs terminées du compagnon et les contrats UX courants du 22 octobre constituent le socle à préserver ; les maquettes et les paragraphes historiques ne rouvrent pas leurs décisions approuvées.
