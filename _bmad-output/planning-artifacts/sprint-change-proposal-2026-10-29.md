# Proposition de changement — Remplacer l'observateur par le plugin Hermes

Date : 2026-10-29. Auteur : Alanc (décision), agent développeur (analyse). Mode : revue groupée. **Statut : approuvée par Alanc le 2026-10-29 ; portée modérée.** Modifications appliquées à `epics.md`, `ARCHITECTURE-SPINE.md`, `spec-5-5` (repassée en draft) ; `epic-5-context.md` supprimé pour recompilation. Pas de `sprint-status.yaml` dans le projet.

## 1. Résumé du problème

**Déclencheur :** story 5.5 (validation G3 sur téléphone), mise en pause le 2026-10-29. Alanc juge l'installation de l'observateur trop lourde : un add-on Home Assistant de plus, un service Tailscale, une URL et un bearer à saisir par profil.

**Type :** approche remplacée par une solution plus simple, découverte pendant l'implémentation.

**Preuves :**
- [investigation-plugin-hermes-notifications.md](../implementation-artifacts/investigation-plugin-hermes-notifications.md) : `on_session_end` se déclenche à chaque tour de l'app (`platform: tui`), avec l'identifiant de session stocké.
- [investigation-2-plugin-hermes-fcm.md](../implementation-artifacts/investigation-2-plugin-hermes-fcm.md) : un plugin envoie de vraies notifications FCM (statut 200, app fermée), et le jeton passe de l'app au plugin par `command.dispatch`. Décision : go pour la bascule complète, sous conditions.

**Décision d'Alanc :** passer entièrement au plugin et retirer l'add-on Notifier, le service Tailscale et tout le code de l'observateur. L'indication « notification non suivie » est **conservée**, déclenchée quand Hermes répond 4018 (plugin absent sur le profil).

## 2. Analyse d'impact

**Epic 5 :** le but reste le même (être averti quand Hermes a fini, ouvrir la bonne conversation). Le moyen change.
- Les stories 5.1 à 5.4 sont livrées pour l'observateur ; leur code est en grande partie retiré.
- La story 5.5 est à réécrire avec le plugin.
- La porte G3 est redéfinie.

**Autres epics :** l'epic 6 n'est pas concerné. Les epics 1 à 4 ne sont touchés que par le retrait du pas « suivi de notification » dans le pipeline d'envoi (`outbox_repository.dart`).

**PRD :** FR-9 est rédigé sans observateur. Aucune modification ; le MVP reste atteignable.

**UX :** EXPERIENCE et DESIGN ne parlent pas de l'observateur. Il faut retirer la « santé de l'observateur » d'UX-DR20 et les réglages observateur du profil.

**Architecture :** AD-1, AD-8, AD-9, le schéma de déploiement, l'arborescence, la porte G3 et la section Différé.

**Technique :**
- **Supprimés :**
  - `server/notifier/` en entier ;
  - `repository.yaml` ;
  - 3 étapes de CI ;
  - `contracts/notification-deployment.json` ;
  - environ 1 500 lignes de Dart et de tests (`notification_repository.dart`, `notification_settings.dart`, tables `notification_subscriptions` et `notification_settings`, secret `observerBearer`).
- **Adaptés :**
  - le toucher de notification passe de `subscriptionId` à `sessionId`, dans `MainActivity.kt`, `firebase_notification_client.dart` et `routes.dart` ;
  - `notification-tracking.json` est réduit au payload.
- **Bloquant actuel :** l'app n'accepte que `{subscriptionId, outcome}`. Les notifications du plugin s'affichent app fermée, mais en premier plan elles sont ignorées et le toucher n'ouvre pas la conversation.

**Ce qui est perdu, et accepté :**
- **La file d'envoi durable et le rattrapage :** si Hermes plante en plein tour, aucune notification ne part.
- **Les nouveaux essais FCM :** la file en gardait trace. Il reste un nouvel essai simple en mémoire.
- **La déduplication par exécution :** le plugin envoie une notification par fin de tour `tui`.

## 3. Approche recommandée

**Ajustement direct dans l'epic 5** (option 1), en gardant l'historique :
- les stories 5.1 à 5.4 sont marquées « remplacées » ;
- trois stories sont ajoutées, et la 5.5 est réécrite.

Aucun retour arrière par `git revert` : le retrait se fait par nouvelles stories, testées.

- **Effort :** moyen, environ 3 stories et la 5.5 rejouée.
- **Risque :** faible. Le canal est prouvé en réel, et le retrait est surtout de la suppression.
- **Calendrier :** la 5.5 reste la dernière story de l'epic 5. L'epic 6 n'est pas décalé.

**Ordre :** 5.6 → 5.7 → 5.8 → 5.5. L'add-on peut être arrêté dès maintenant : sans lui, l'app affiche « notification non suivie » sans bloquer l'envoi, mais les profils sans plugin ne reçoivent plus de notification.

## 4. Modifications détaillées

### 4.1 Epics (`epics.md`)

**Epic 5 — introduction (l. 765 et 162)**

ANCIEN : « Inclut l'observateur serveur, FCM et l'ouverture depuis notification. Requiert la porte G3. »

NOUVEAU : « Inclut le plugin Hermes de notifications, FCM et l'ouverture depuis notification. L'observateur serveur des stories 5.1 à 5.4 est remplacé par le plugin (proposition du 2026-10-29). Requiert la porte G3. »

**Stories 5.1 à 5.4 :** ajouter sous chaque titre : « *Remplacée le 2026-10-29 par le plugin Hermes (5.6 à 5.8) ; conservée pour l'historique.* » Pour la 5.4, préciser : « Le routage reste ; la clé passe de `subscriptionId` à `sessionId` (5.7). »

**Nouvelle story 5.6 : Recevoir mes notifications par le plugin Hermes**

En tant qu'Alanc, je veux que Hermes envoie lui-même la notification de fin, afin de n'avoir rien d'autre à installer qu'un plugin.

- **Étant donné** le plugin `hermes-mobile-notify` installé sur un profil, **quand** un tour lancé depuis l'app (`platform: tui`) se termine, **alors** une notification FCM générique part en arrière-plan, sans retarder le tour, avec `data: {outcome, sessionId}` et sans texte, chemin ni secret. **Et** les tours des sous-agents, de cron ou d'autres plateformes ne notifient pas.
- **Étant donné** l'app qui envoie un message, **quand** elle a un jeton FCM, **alors** elle le transmet par `command.dispatch hermes-mobile-token` sans bloquer l'envoi.
- **Étant donné** FCM qui répond `UNREGISTERED`, **quand** le plugin le constate, **alors** il oublie le jeton jusqu'au prochain envoi de l'app. **Et** une erreur réseau donne lieu à un seul nouvel essai.
- **Étant donné** le dépôt, **quand** la CI tourne, **alors** l'auto-vérification du plugin s'exécute. **Et** `contracts/notification-tracking.json` ne décrit plus que le payload (titres, canal, `outcome`, `sessionId`).
- **Étant donné** la procédure d'installation, **quand** Alanc l'applique à un profil, **alors** elle tient en : copier le plugin, copier la clé, l'activer, redémarrer.

**Nouvelle story 5.7 : Basculer l'app sur le plugin**

En tant qu'Alanc, je veux que l'app ne dépende plus de l'observateur, afin de ne plus rien configurer par profil.

- **Étant donné** une notification du plugin, **quand** Alanc la touche (app à froid, à chaud ou depuis les récents), **alors** la conversation `sessionId` s'ouvre sur le bon profil. **Et** une session inconnue localement ouvre l'accueil avec une explication.
- **Étant donné** une notification reçue app ouverte, **quand** elle arrive, **alors** elle est traitée comme aujourd'hui avec `{outcome, sessionId}`.
- **Étant donné** l'envoi d'un message, **quand** `command.dispatch` répond 4018, **alors** le tour affiche « notification non suivie » sans bloquer l'envoi.
- **Étant donné** les réglages du profil, **quand** Alanc les ouvre, **alors** il n'y a plus d'URL ni de bearer d'observateur. Les explications sur la permission et l'arrêt forcé restent.
- **Étant donné** la base locale, **quand** l'app migre, **alors** une migration ajoutée supprime `notification_subscriptions`, `notification_settings` et le secret `observerBearer`. Aucune migration existante n'est modifiée.

**Nouvelle story 5.8 : Retirer l'observateur**

En tant qu'Alanc, je veux que l'add-on Notifier et son code disparaissent, afin de n'avoir qu'un seul chemin à maintenir.

- **Étant donné** le dépôt, **quand** le retrait est fait, **alors** les éléments suivants n'existent plus : `server/notifier/`, `repository.yaml`, les étapes de CI du notifier, `contracts/notification-deployment.json`, la section 5.1 de `contracts/README.md` et les mentions dans `README.md`.
- **Étant donné** Home Assistant et Tailscale, **quand** Alanc suit la procédure de la section 6, **alors** l'add-on est désinstallé, son dépôt est retiré, `/share/hermes-notifier/` est supprimé et le service `svc:hermes-notifier` n'existe plus.
- **Étant donné** `deferred-work.md`, **quand** le retrait est fait, **alors** les reports propres à l'observateur sont clos.

**Story 5.5 — critères réécrits**

ANCIEN : « scénarios G3 : app fermée, coupure réseau pendant le travail, redémarrage de l'observateur, observateur absent pendant un envoi … l'absence d'observateur produit « notification non suivie » »

NOUVEAU :
- **Étant donné** le téléphone d'Alanc et le plugin installé, **quand** sont joués les scénarios suivants, **alors** chaque fin de tour de l'app est notifiée au moins une fois, sans doublon de sous-agent, et le toucher ouvre la bonne conversation :
  - app fermée ;
  - coupure réseau pendant le travail (notification après reconnexion) ;
  - arrêt ;
  - délégation à un sous-agent ;
  - conversation reprise ;
  - `/new`.
- **Étant donné** un profil sans plugin, **quand** Alanc envoie un message, **alors** « notification non suivie » s'affiche sans bloquer l'envoi.
- **Étant donné** un redémarrage d'Hermes pendant un travail, **quand** il est joué, **alors** le résultat est consigné. La perte de la notification est acceptée et doit être expliquée.
- **Étant donné** l'arrêt forcé et la permission refusée, **quand** ils sont joués, **alors** les critères actuels s'appliquent sans changement.

**Lignes de contexte :**
- l. 57 : `server/notifier/` (après G3) → `server/hermes-plugin/`.
- l. 62 : « `subscriptionId` opaque partagé avec l'observateur » → « `sessionId` stocké, porté par la notification ».
- l. 68 : « Seuls l'adaptateur et l'observateur connaissent les formats Hermes » → « Seuls l'adaptateur et le plugin… ».
- l. 75-76 : remplacer par « Suivi = jeton transmis au plugin avant soumission, jamais bloquant ; « notification non suivie » si le plugin est absent (4018). Payload `{outcome, sessionId}` et libellé générique. FCM HTTP v1, compte de service dans `HERMES_HOME/hermes-mobile/`. »
- l. 90 : G3 → « plugin installé par profil, jeton app → plugin, filtre `tui`, version FCM, prérequis Android, essais app fermée, coupure, sous-agent, reprise ».
- l. 92 : « observateur absent pendant un envoi » → « plugin absent pendant un envoi ».
- l. 115 (UX-DR20) : retirer « et santé de l'observateur ».

### 4.2 Architecture (`ARCHITECTURE-SPINE.md`)

- **AD-1 :**
  - remplacer la règle observateur par « Le plugin de notifications tourne dans Hermes, ne soumet ni ne contrôle aucun travail, et ne lit que les paramètres du hook `on_session_end`. » ;
  - remplacer la règle `subscriptionId` par « Le payload push ne porte que `sessionId` (identifiant stocké) et l'issue. ».
- **AD-8 :** supprimer « et l'observateur authentifie le mobile avec un credential qui lui est propre ». Le jeton FCM passe par la connexion Hermes déjà authentifiée.
- **AD-9, réécrit :** « Notification par plugin Hermes ».
  - Un plugin `on_session_end` par profil notifie les fins de tour `tui` via FCM HTTP v1, en arrière-plan. Le hook est borné à 30 s par Hermes.
  - Le jeton est transmis par l'app (`command.dispatch`), sans jamais bloquer. Une réponse 4018 donne « notification non suivie ».
  - Le payload est `{outcome, sessionId}`, avec un libellé générique.
  - **[ACCEPTÉ]** Il n'y a ni outbox durable ni rattrapage : un plantage d'Hermes en plein tour perd la notification. Un seul nouvel essai FCM est tenté.
  - Aucune livraison exactement une fois n'est promise.
- **Schéma :** retirer le nœud « Observateur » et le registre. Ajouter « Hermes → plugin → FCM ».
- **Arborescence :** remplacer `server/notifier/` par `server/hermes-plugin/`.
- **G3 :** comme dans `epics.md` l. 90.
- **Différé :** supprimer « Après G3 : runtime… de l'observateur » et la ligne « Observateur serveur distinct… ».
- **Pipeline :** « suivi notification (non bloquant) » devient « jeton au plugin (non bloquant) ».

### 4.3 Artefacts d'implémentation

- **`epic-5-context.md` :** le supprimer, pour qu'il soit recompilé depuis les documents mis à jour.
- **`spec-5-5-valider-notifications-telephone.md` :** passer en `draft` avec une note « critères réécrits le 2026-10-29 ; reprendre avec bmad-build après 5.8 ».
- **`deferred-work.md` :** clore à la story 5.8 les entrées des lignes 49-63 (montage du compte de service, abonnements multiples, extra natif `subscriptionId`, CI du notifier).

## 5. Passage à l'implémentation

**Portée :** modérée. Il faut réorganiser l'epic 5, sans re-planifier le produit.

- **Agent développeur** (`bmad-build`, une story à la fois) : 5.6, puis 5.7, puis 5.8, puis la 5.5 rejouée.
- **Alanc :**
  - installer le plugin sur chaque profil voulu (5.6) ;
  - faire le retrait Home Assistant et Tailscale (section 6) ;
  - jouer les scénarios de la 5.5.

**Critères de réussite :**
- plus aucune référence à `server/notifier`, `subscriptionId` ni « observateur » dans `lib/`, `contracts/` et la CI ;
- tests verts ;
- la 5.5 jouée sur le téléphone ;
- G3 déclarée franchie.

## 6. Retrait côté Home Assistant et Tailscale (à faire par Alanc)

Peut être fait dès maintenant, puisque les notifications du profil `.hermes` passent déjà par le plugin.

1. **Add-on Hermes Notifier** (`d8bc4f44_hermes_notifier`) : l'arrêter, puis le désinstaller (Paramètres → Modules complémentaires). Ensuite, dans la boutique, menu ⋮ → Dépôts, retirer `https://github.com/alanmlcrt/hermes-mobile`.
2. **Dossier `/share/hermes-notifier/`** : le supprimer par Samba (`\\homeassistant.local\share\hermes-notifier`). La clé du compte de service a déjà sa copie dans `.hermes\hermes-mobile\`.
3. **Add-on Tailscale, onglet Configuration, option `services`** : supprimer l'entrée `svc:hermes-notifier` (protocole `https`, port 443, cible `http://127.0.0.1:8787`), puis redémarrer l'add-on Tailscale.
4. **Console d'administration Tailscale :**
   - dans **Services**, supprimer `svc:hermes-notifier` ;
   - dans **Access controls**, retirer les règles qui citent `svc:hermes-notifier`, s'il y en a.
5. **À conserver :**
   - `tag:hermes` sur le nœud Home Assistant : le retirer changerait l'identité du nœud et pourrait couper l'accès ;
   - l'accès à `homeassistant.tail0ec6c6.ts.net:9119`, utilisé par l'app pour parler à Hermes ;
   - les options Serve et Funnel, qui sont déjà désactivées.
