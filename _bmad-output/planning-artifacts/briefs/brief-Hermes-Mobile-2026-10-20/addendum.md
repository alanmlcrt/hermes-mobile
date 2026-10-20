# Hermes Mobile — contexte pour la spécification et l'architecture

## Installation et accès décrits par l'utilisateur

- Hermes tourne en permanence sur le serveur Home Assistant. L'utilisateur décrit son installation comme un équivalent de Hermes sous Docker ; le conditionnement exact reste à vérifier.
- Tailscale est déjà utilisé pour accéder au serveur depuis l'extérieur.
- Plusieurs profils Hermes sont déjà utilisés via Discord, avec un bot Discord par profil dans l'organisation actuelle.
- Aucun accès au serveur n'a été effectué pendant le cadrage. Version, configuration et compatibilité restent inconnues.

## Documentation officielle examinée

- [Profils](https://hermes-agent.nousresearch.com/docs/user-guide/profiles) : profils isolant notamment configuration, mémoire, compétences et sessions.
- [Bot Mode](https://hermes-agent.nousresearch.com/docs/user-guide/bot-mode) : interface Desktop fondée sur les profils. Le Bot Chat est permanent, mais les sessions ordinaires restent possibles. Dans le Bot Chat, `/new` compacte la conversation. L'outil `message_agent` dépend du contexte canonique Bot Chat ; sa présence dans les conversations ordinaires ne doit pas être présumée.
- [Gateway multiplexé](https://hermes-agent.nousresearch.com/docs/user-guide/multi-profile-gateways) : un processus peut servir plusieurs profils. Les règles `gateway.profile_routes` permettent aussi de router les messages d'un bot partagé suivant utilisateur, serveur, canal ou fil. Cela ne démontre pas un choix de profil arbitraire par mention.
- [Connexions distantes Desktop](https://hermes-agent.nousresearch.com/docs/user-guide/multi-connection-desktop) : piste officielle pour étudier la connexion à un backend distant et la découverte des profils.
- [API Server](https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server) : interface pour clients externes avec streaming et gestion des exécutions. La reprise des sessions Discord/Desktop doit être distinguée des conversations propres à cette API ; le gateway WebSocket est une piste à examiner pour les sessions partagées.

## Points à vérifier lors de la conception technique

Comparer les interfaces officielles sur les besoins réels : découverte des profils, historique, création de conversation, événements d'outils, résultats persistants, éventuelles approbations requises par Hermes et authentification. Ne pas figer le protocole ou la stack mobile avant cette vérification.

Après réexamen de Bot Mode demandé par l'utilisateur, étudier prioritairement le backend distant utilisé par Desktop : `hermes serve`, découverte des profils via REST et connexions WebSocket. La documentation des connexions distantes prévoit Tailscale. Il s'agit d'une piste d'intégration, pas d'une compatibilité mobile ou d'une disponibilité sur le serveur déjà démontrée. Les groupes et routines documentés restent des possibilités futures, sans élargissement automatique du MVP.

Le travail doit rester exécuté par le serveur même si la connexion mobile s'interrompt. Une notification de fin exige un mécanisme distinct du simple maintien d'une connexion au premier plan ; sa faisabilité via Tailscale et son comportement app fermée devront être vérifiés.

Le suivi des actions affiche les événements fournis par Hermes. Il ne présuppose pas l'accès au raisonnement interne du modèle. Le niveau de détail disponible et les informations sensibles éventuellement contenues dans les sorties devront être traités dans la spécification.

## Référence Orca Mobile pour Tailscale

Sources officielles examinées à la demande de l'utilisateur : [Mobile companion](https://www.onorca.dev/docs/mobile) et [Remote Orca Servers](https://www.onorca.dev/docs/remote-servers).

Orca documente une association mobile par QR code ou lien, une adresse Tailscale joignable et un jeton propre à l'appareil. Le mobile conserve la connexion ; l'adresse peut être modifiée sans refaire l'association. Le mode serveur sans interface peut produire un lien destiné au mobile. Ces mécanismes appartiennent à Orca ; leur réutilisation directe avec Hermes n'est pas établie.

Adaptation proposée : téléphone et serveur accessibles sur le tailnet existant, association initiale assistée avec solution manuelle, adresse mémorisée, reconnexion et diagnostic réseau/authentification. Vérifier les fonctions d'authentification natives de Hermes avant de définir une éventuelle couche d'association. L'ajout du téléphone au tailnet et son autorisation auprès de Hermes sont deux étapes distinctes.

## Vocabulaire Hermes

Selon la section [Profiles, agents, and bots](https://hermes-agent.nousresearch.com/docs/user-guide/profiles#profiles-agents-and-bots), le profil contient l'état persistant, l'agent est l'assistant en fonctionnement et le bot de Bot Mode est la présentation d'un profil dans ce mode. Un bot Discord désigne, lui, un compte de plateforme. Vocabulaire d'interface proposé : « assistants » pour sélectionner les profils, « conversations » pour leurs sessions ; proposition non encore validée.
