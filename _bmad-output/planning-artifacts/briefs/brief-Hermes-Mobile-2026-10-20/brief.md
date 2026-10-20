---
title: "Hermes Mobile — brief produit"
status: draft
created: 2026-10-20
updated: 2026-10-20
---

# Hermes Mobile

## Le produit et son utilisateur

Hermes Mobile est une application personnelle pour converser à distance avec les profils d'une installation Hermes existante. Android est prioritaire ; les choix de conception devront permettre une version iPhone ultérieure, sans engagement de livraison simultanée. L'application sert son créateur seul au départ.

Sa valeur tient à une expérience dédiée : sélectionner directement un profil, échanger de longs textes, lire des réponses correctement présentées et suivre le travail de l'agent. Grok Bot et Orca sont les références citées ; Grok Bot inspire particulièrement le suivi synthétique dont les détails se déplient.

Orientation proposée après examen de Bot Mode : faire d'Hermes Mobile un client mobile du backend Hermes existant, en reprenant la présentation des profils comme agents identifiables. Conserver le choix utilisateur de nouvelles conversations distinctes. Les capacités réelles du backend installé doivent être vérifiées avant de confirmer cette orientation technique.

## Problème constaté

Hermes est installé sur le serveur de l'utilisateur, associé à Home Assistant selon sa description. Les conversations passent aujourd'hui par Discord. Son design contraint l'expérience : collage de longs textes limité sans Nitro selon l'utilisateur, recours peu pratique aux commandes `/`, rendu insatisfaisant du texte et des emojis, commandes CLI exécutées par l'agent mal intégrées à la conversation.

L'utilisateur échange avec plusieurs profils Hermes existants en les mentionnant. Son organisation actuelle nécessite un bot Discord par profil, ce qu'il juge peu pratique.

## Expérience et périmètre du MVP

- À l'ouverture de l'app, préparer une nouvelle conversation avec le profil par défaut. [ASSUMPTION] Le fil n'est enregistré qu'au premier message, pour éviter les conversations vides.
- Sélectionner un autre profil Hermes existant, retrouver ses conversations distinctes et en démarrer une nouvelle à la demande.
- Envoyer et coller de longs textes ; présenter lisiblement les réponses, emojis et blocs de code. [ASSUMPTION] Proposer une réponse progressive et expliquer les limites effectives du serveur ou du modèle, sans reprendre les restrictions de Discord.
- Envoyer des images et des pièces jointes dans les conversations. Formats, tailles et traitements possibles restent à définir selon les besoins et les capacités de Hermes.
- Configurer les profils depuis l'application. Les réglages à exposer et l'inclusion éventuelle de la création ou suppression restent à préciser.
- Accéder aux actions courantes depuis l'interface, sans imposer de commandes `/`. La liste minimale de ces actions sera précisée dans la spécification.
- Montrer une synthèse du travail en cours et permettre de déplier ses détails. [ASSUMPTION] Les détails comprennent le nom de l'outil, les commandes exécutées, leurs sorties et leur état, selon les informations réellement exposées par Hermes.
- Laisser Hermes poursuivre un travail sur le serveur lorsque l'app passe en arrière-plan ou est fermée, puis notifier sa fin. Le canal de notification reste à valider techniquement.
- Se connecter au serveur via Tailscale, déjà utilisé par le propriétaire. [ASSUMPTION] À la reconnexion, retrouver l'état du travail et les messages produits sans renvoyer la demande.

L'utilisateur demande de prendre Orca Mobile comme référence pour la connexion Tailscale. Parcours proposé : associer le serveur une première fois par QR code ou lien, mémoriser la connexion, puis retrouver directement le profil par défaut aux ouvertures suivantes. Prévoir une saisie manuelle et des erreurs distinguant serveur inaccessible et authentification refusée. Le mécanisme d'association côté Hermes reste à concevoir ; celui d'Orca n'est pas présumé compatible.

## Limites proposées, à confirmer

[ASSUMPTION] La voix, les routines, les échanges entre plusieurs agents, la gestion multi-utilisateur et l'import de l'historique Discord sont reportés. Ces exclusions ne sont pas encore validées par l'utilisateur. Les images, pièces jointes et la configuration des profils sont explicitement incluses dans le MVP.

## Réussite proposée

Ces critères serviront à juger le premier usage réel ; ils restent à valider :

- Depuis son téléphone hors du domicile, l'utilisateur peut ouvrir l'app et envoyer un premier message au profil par défaut sans passer par Discord ou une commande `/`.
- Il peut échanger un texte représentatif de ses usages longs, avec une réponse lisible. La taille de référence sera fixée avant les tests.
- Il peut alterner entre deux profils et retrouver séparément leurs conversations, sans mélange d'historique.
- Il peut suivre une action, en consulter le détail et retrouver son résultat après avoir quitté l'app ; une notification lui signale la fin du travail.

## Inconnues à résoudre avant l'implémentation

Version de Hermes et capacités activées ; mode de déploiement exact sur le serveur Home Assistant ; accès aux profils, aux conversations et aux événements d'exécution ; authentification de l'app ; faisabilité des notifications Android lorsque l'app est fermée. Le serveur qui continue de tourner ne garantit pas, à lui seul, la livraison d'une notification.

La reprise de l'historique Discord et les limites proposées ci-dessus doivent être confirmées. Les sources, possibilités d'intégration et contraintes techniques sont conservées dans `addendum.md`.

L'utilisateur demande également une inspiration visuelle de Grok Bot ou Muse ; les liens exacts des deux références ont été demandés pour éviter les homonymes. Le skill `ui-ux-pro-max` demandé est installé localement dans `.agents/skills/ui-ux-pro-max` pour le travail de design.

## Suite envisagée

Élargir progressivement l'application aux fonctionnalités des références qui améliorent réellement l'usage de Hermes. Leur sélection viendra après validation du parcours conversationnel personnel ; aucune parité complète n'est promise au MVP.
