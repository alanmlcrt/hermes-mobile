---
title: "Hermes Mobile — PRD"
status: final
created: 2026-10-20
updated: 2026-10-20
---

# Hermes Mobile — PRD

## But et utilisateur

Permettre à Alanc d'utiliser son installation Hermes à distance depuis une application Android personnelle, en anticipant une version iPhone. Le serveur Home Assistant reste responsable de l'exécution. Tailscale est déjà utilisé. Ce PRD fixe le périmètre produit pour l'UX et l'architecture ; il ne certifie pas encore sa compatibilité avec l'installation réelle.

Le besoin vient des limites rencontrées avec Discord : longs textes, commandes `/`, rendu des réponses et présentation des exécutions CLI, gestion de plusieurs profils par des bots distincts.

L'application est un client de communication avec Hermes. Alanc lui confie librement ses demandes : préparer un environnement, travailler sur du code, configurer un profil ou faire évoluer les compétences de Hermes. Ces capacités restent exécutées et gouvernées par Hermes ; le client mobile transmet les échanges, présente l'activité et permet les interactions nécessaires. Le MVP privilégie la simplicité d'une messagerie avec une interface soignée.

## Périmètre et exclusions

Le MVP ne recrée ni moteur d'agent, ni environnement d'exécution de code, ni système d'auto-amélioration, ni administration dédiée des profils. Ces usages passent par Hermes au travers de la conversation. Une parité complète avec les fonctions de Grok Bot n'est pas un objectif du MVP.

Usage personnel et Android sont confirmés. [ASSUMPTION] Voix, routines, groupes d'agents, import Discord et diffusion publique restent reportés ; exclusions à confirmer. La livraison iPhone est anticipée, sans promesse de simultanéité.

## Vocabulaire

- **Profil** : identité Hermes persistante avec sa configuration, mémoire et compétences.
- **Agent** : assistant Hermes qui travaille avec un profil.
- **Conversation** : fil de messages rattaché à un profil ; un profil peut avoir plusieurs conversations.
- **Action** : opération d'outil effectuée par l'agent, dont l'interface présente l'état et les détails disponibles.
- **Pièce jointe** : fichier envoyé avec un message ; les images disposent d'un aperçu adapté.

## Fonctionnalités du MVP

Les FR-1 à FR-10 et FR-12 constituent le socle obligatoire ; FR-11 est retiré. Les ajouts FR-13 et FR-14 restent proposés, à trancher avec Alanc pendant l'architecture avant de créer les stories correspondantes. Les détails marqués `[ASSUMPTION]` restent à confirmer comme indiqué en fin de document ; ils ne diminuent pas les capacités obligatoires.

### Connexion et conversations

- **FR-1 — Accès distant.** Alanc peut connecter l'application à son serveur Hermes par le réseau Tailscale existant. [ASSUMPTION] Une association initiale par QR code ou lien, avec saisie manuelle de secours, mémorise la connexion. Un échec indique si le serveur est inaccessible ou si l'authentification est refusée.
- **FR-2 — Accueil.** À une ouverture normale de l'application, une nouvelle conversation est préparée avec le profil par défaut. [ASSUMPTION] Aucun fil vide n'est enregistré avant le premier envoi ; le retour temporaire dans l'app conserve le travail en cours. Une notification de fin ouvre la conversation concernée.
- **FR-3 — Profils et historique.** Alanc peut sélectionner un profil existant, retrouver ses conversations et en créer une nouvelle. Changer de profil ne mélange pas les messages ou les fichiers entre conversations.
- **FR-4 — Échanges texte.** Alanc peut saisir et coller de longs textes, lire des réponses avec emojis, mise en forme et code, sans devoir utiliser des commandes `/` pour les actions courantes. [ASSUMPTION] La réponse apparaît progressivement ; les limites du serveur ou du modèle sont expliquées sans perte du brouillon. La taille de texte de référence reste à fixer.

### Images et pièces jointes

- **FR-5 — Préparation.** Alanc peut joindre photos, captures d'écran, PDF, documents bureautiques et autres fichiers à une demande, sans être enfermé dans un scénario d'usage prédéfini. [ASSUMPTION] Il peut vérifier leur liste, voir les aperçus d'images et retirer un fichier avant l'envoi. L'application indique les limites effectives de type, de nombre et de taille avant l'envoi ; « autres fichiers » ne garantit pas la prise en charge de tous les formats.
- **FR-6 — Transmission.** Les fichiers acceptés sont transmis à la bonne conversation et restent identifiables dans son historique. [ASSUMPTION] L'état d'envoi et les échecs sont visibles ; une transmission échouée n'est jamais présentée comme un fichier effectivement reçu par Hermes. Le traitement sémantique des images dépend du modèle sélectionné et doit être explicite.

### Suivi du travail et continuité

- **FR-7 — Actions dépliables.** L'application montre une synthèse de l'activité et permet d'en déplier les détails fournis par Hermes. [ASSUMPTION] Ces détails comprennent les outils, commandes CLI, sorties et erreurs disponibles. Aucun contenu interne non exposé par Hermes n'est inventé.
- **FR-8 — Travail distant.** Quitter l'app ne doit pas annuler le travail accepté par le serveur. [ASSUMPTION] À la reconnexion, les messages et l'état de l'exécution sont retrouvés ; une demande au résultat incertain n'est pas automatiquement renvoyée.
- **FR-9 — Notification de fin.** Alanc est averti de la fin d'un travail alors qu'il n'est plus dans l'application. Une notification doit permettre de retrouver la conversation. [ASSUMPTION] Le résultat distingue réussite, erreur et arrêt confirmé ; ces trois issues déclenchent une notification. Le comportement app fermée et les prérequis Android devront être vérifiés sur un téléphone réel ; le transport reste à concevoir.

### Intervenir dans une conversation

- **FR-12 — Arrêter le travail.** Alanc peut demander l'arrêt de l'exécution en cours depuis la conversation, sans saisir une commande `/`. L'interface distingue une demande d'arrêt envoyée d'un arrêt confirmé par Hermes ; une perte réseau ne vaut pas confirmation. Arrêter ne signifie pas annuler les effets d'actions déjà exécutées. La portée et le délai d'interruption dépendent du serveur et devront être vérifiés.
- **FR-13 — Répondre et autoriser.** [ASSUMPTION] Quand Hermes attend une précision ou une autorisation, la demande apparaît dans la conversation et Alanc peut y répondre depuis l'app. Une autorisation présente la demande réellement émise par Hermes ; le client n'invente pas une politique d'approbation. Les interventions pendant une exécution doivent respecter les capacités du backend : leur prise en compte immédiate ou différée est explicite.
- **FR-14 — Récupérer les résultats.** [ASSUMPTION] Les fichiers rendus accessibles par Hermes sont identifiables depuis la conversation et peuvent être ouverts ou téléchargés selon leurs formats. L'interface distingue un résultat disponible d'un simple chemin de fichier serveur inaccessible depuis le téléphone.

### Découverte des profils

- **FR-10 — Profils disponibles.** Les profils existants sur Hermes sont renseignés dans l'application et peuvent être sélectionnés sans devoir les recréer ni saisir leur configuration dans le client mobile. La liste permet de distinguer les profils et d'identifier celui utilisé dans la conversation. [ASSUMPTION] Une actualisation permet de retrouver un profil ajouté côté Hermes sans réinstaller l'application ; un échec de chargement est distingué d'une liste réellement vide. Le mode et la fréquence d'actualisation restent à définir.

Le MVP ne comprend pas d'écran pour consulter ou administrer la configuration des profils. Alanc peut passer par une conversation avec le profil par défaut pour demander la configuration d'autres profils. Ce besoin ne présume pas que le serveur installé expose déjà toutes les capacités nécessaires.

L'ancien **FR-11**, consacré aux sauvegardes de réglages depuis l'application, est retiré du MVP ; son identifiant reste réservé.

## Après le MVP

Permettre de consulter les outils, serveurs MCP et skills d'un profil. Les autres informations à exposer et les éventuelles fonctions de modification seront précisées ultérieurement. La priorité reste une expérience simple, en s'appuyant autant que possible sur la conversation avec le profil par défaut pour la configuration.

## Expérience et qualité attendues

L'application privilégie la conversation et le suivi synthétique, avec des détails accessibles à la demande. Grok Bot est une référence identifiée par Alanc : [documentation](https://docs.x.ai/grok-bot/overview) et [présentation](https://x.ai/bot). En retenir l'interaction par messages avec un agent persistant et le retour vers l'utilisateur quand une intervention est nécessaire ; les choix précis de présentation restent à définir. Orca Mobile reste la référence pour l'association Tailscale. Muse est une référence facultative encore non identifiée ; aucun thème, palette ou copie d'écran n'est validé.

[ASSUMPTION] Le fil montre clairement les états disponibles : envoi, travail en cours, attente d'une réponse ou d'une autorisation, demande d'arrêt, arrêt confirmé, fin et erreur. Les détails techniques sont dépliables pour garder la conversation lisible ; un état inconnu ou non synchronisé est présenté comme tel.

- **NFR-1 — Mobile.** Les parcours essentiels sont utilisables au toucher avec clavier affiché, texte agrandi et lecteur d'écran. Les icônes d'action ont un libellé accessible ; l'état ne repose pas seulement sur la couleur.
- **NFR-2 — Fiabilité.** Une coupure réseau ne doit pas masquer un échec, perdre un brouillon existant ou provoquer silencieusement une nouvelle exécution.
- **NFR-3 — Accès.** Tailscale fournit le chemin réseau ; l'authentification auprès de Hermes reste nécessaire. Les secrets ne sont pas affichés dans les erreurs ou les journaux de diagnostic.
- **NFR-4 — Compatibilité.** Vérifier les capacités du serveur pour chaque fonction ; une fonction absente est signalée clairement. Une capacité obligatoire non démontrée sur l'installation réelle bloque l'acceptation du MVP ; la signaler ne remplace pas sa livraison. Son retrait ou son report exige une décision explicite d'Alanc.

## Réussite proposée et limites

[ASSUMPTION] Le MVP est accepté après un essai Android à distance : nouvelle conversation par défaut, profils existants affichés sans configuration manuelle dans l'application, échanges avec deux profils et reprise de leur historique, long texte représentatif, image et document représentatifs effectivement reçus par Hermes, détail d'une action, puis fin d'un travail et notification après avoir quitté l'app. Les formats et volumes de référence seront choisis avant les tests. Indicateur de contrôle : aucune duplication d'exécution ni perte de brouillon pendant ces essais.

[ASSUMPTION] L'essai comprend aussi une demande d'arrêt avec confirmation serveur, une réponse à une question de Hermes et, si le backend l'expose, une décision d'autorisation et la récupération d'un fichier résultat. Un contrôle indisponible est expliqué ; il ne peut pas être déclaré validé par une simulation locale.

Avant de rédiger les tests d'acceptation, Alanc fournit un long texte, une photo ou capture, un PDF et un document bureautique représentatifs de son usage ; l'architecture consigne leurs formats et volumes ainsi que les limites effectivement prises en charge. La réception doit être vérifiée côté Hermes, au-delà d'un simple aperçu dans le client.

## Décisions et vérifications reportées

Ces points permettent de commencer l'UX et l'architecture. Leur résolution conditionne les stories concernées ou l'acceptation du MVP, selon le jalon indiqué.

| Sujet | Responsable | Jalon de résolution |
| --- | --- | --- |
| Version et déploiement Hermes ; contrat couvrant profils, conversations distinctes, historique, fichiers, événements et arrêt ; configuration via le profil par défaut | Architecture, avec accès fourni par Alanc | Avant de valider l'architecture et de découper les stories d'intégration ; toute capacité obligatoire manquante revient à Alanc |
| Association et authentification, transport des documents et résultats, reprise après coupure, notification app fermée | Architecture | Avant les stories correspondantes ; preuves sur installation réelle et téléphone Android avant acceptation |
| FR-13/FR-14, comportement des messages pendant le travail, issues notifiées de FR-9 | Alanc avec l'architecture | Avant de figer ces comportements et de créer leurs stories ; toute proposition non retenue est explicitement retirée |
| Hypothèses d'interface : accueil/reprise, streaming, brouillons, fichiers, états du fil, actualisation des profils ; direction visuelle Grok Bot | Alanc avec l'UX | Avant validation des parcours et des stories correspondantes |
| Texte et fichiers représentatifs, formats acceptés, limites de taille et de nombre | Alanc avec l'architecture | Avant rédaction des tests d'acceptation |
| Reports proposés : voix, routines, groupes d'agents, import Discord, diffusion publique | Alanc | Avant découpage des epics ; aucune de ces fonctions n'est ajoutée implicitement |

## Hypothèses à confirmer

Les mentions `[ASSUMPTION]` sont des propositions, pas des décisions utilisateur ni des capacités serveur vérifiées. Elles sont regroupées ci-dessous avec leur point de résolution dans le tableau précédent :

- FR-1/FR-2 : association QR/lien, saisie manuelle, accueil sans fil vide, reprise temporaire et ouverture depuis une notification — UX et architecture.
- FR-4 : réponse progressive, gestion des limites et conservation du brouillon — UX et architecture.
- FR-5/FR-6 : préparation des fichiers, limites et visibilité des échecs — UX et architecture, puis corpus d'acceptation.
- FR-7/FR-8 : détails d'outils disponibles et reprise sans renvoi automatique — architecture, avec présentation en UX.
- FR-9 : notifications de réussite, erreur et arrêt confirmé — Alanc avec l'architecture.
- FR-10 : actualisation des profils et distinction entre liste vide et échec — UX et architecture.
- FR-13/FR-14 : questions, autorisations et récupération des résultats — décision d'Alanc avec l'architecture.
- États du fil et protocole d'acceptation proposé — UX, puis préparation des tests avec Alanc.
- Reports de voix, routines, groupes d'agents, import Discord et diffusion publique — décision d'Alanc avant les epics.

L'exclusion des écrans de consultation et d'administration des profils du MVP et le besoin d'arrêter l'agent sont confirmés. Aucun choix de stack ou protocole n'est arrêté dans ce PRD.

Sources : brief et addendum dans `../../briefs/brief-Hermes-Mobile-2026-10-20/`. Les détails techniques et les limites d'intégration sont conservés dans `addendum.md` voisin.
