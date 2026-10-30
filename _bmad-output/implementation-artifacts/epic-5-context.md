# Epic 5 Context: Être averti quand Hermes a fini

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

App quittée, Alanc reçoit une notification de fin de travail (réussite, erreur ou arrêt confirmé) qui, au toucher, ouvre directement la bonne conversation. Depuis la décision du 2026-10-29, c'est un plugin Hermes (`hermes-mobile-notify`, hook `on_session_end`) installé par profil qui envoie la notification via FCM, à la place de l'observateur serveur (add-on Home Assistant, service Tailscale, URL et bearer par profil) livré par les stories 5.1 à 5.4, jugé trop lourd à installer. L'epic se termine par la validation sur le téléphone réel, qui franchit la porte G3.

## Stories

- Story 5.1 : Fixer le contrat de suivi et le déploiement de l'observateur (remplacée, historique)
- Story 5.2 : Faire tourner l'observateur de fins de travail (remplacée, historique)
- Story 5.3 : Recevoir une notification à la fin de mon travail (remplacée, historique)
- Story 5.4 : Ouvrir la bonne conversation depuis une notification (routage conservé, clé passée à `sessionId`)
- Story 5.6 : Recevoir mes notifications par le plugin Hermes
- Story 5.7 : Basculer l'app sur le plugin
- Story 5.8 : Retirer l'observateur
- Story 5.5 : Valider les notifications sur mon téléphone (jouée en dernier)

Ordre d'exécution : 5.6 → 5.7 → 5.8 → 5.5.

## Requirements & Constraints

- Une fin de travail hors de l'app est notifiée ; réussite, erreur et arrêt confirmé déclenchent tous une notification, avec une issue générique qui les distingue. Le toucher ouvre la conversation concernée.
- Le payload push ne contient que `{outcome, sessionId}` et un libellé générique : aucun texte de conversation, chemin ni secret.
- Seuls les tours lancés depuis l'app (`platform: tui`) notifient ; sous-agents, cron et autres plateformes jamais.
- Le suivi ne bloque jamais l'envoi d'un message. Plugin absent sur le profil → le tour affiche « notification non suivie ».
- La notification est un indice, jamais l'autorité : la conversation ouverte se réauthentifie si besoin et recharge son état depuis Hermes.
- Session ou connexion inconnue localement → l'app l'explique et ouvre l'accueil, sans réaffecter le résultat au fil affiché.
- Permission refusée, prérequis Google absents et arrêt forcé Android sont expliqués dans l'app (la « santé de l'observateur » disparaît).
- Installation du plugin sur un profil : copier le plugin, copier la clé, activer, redémarrer. Rien à configurer côté app par profil.
- Pertes acceptées : pas de file durable ni de rattrapage (un plantage de Hermes en plein tour perd la notification), un seul nouvel essai FCM en mémoire, pas de déduplication par exécution, aucune livraison exactement une fois promise.
- Critère de réussite du retrait : plus aucune référence à `server/notifier`, `subscriptionId` ni « observateur » dans `lib/`, `contracts/` et la CI ; tests verts.
- Les essais G3 se jouent sur téléphone réel ; aucune simulation ne les remplace.

## Technical Decisions

- **Plugin** (`server/hermes-plugin/`) : tourne dans Hermes, dans le `HERMES_HOME` de chaque profil ; ne soumet ni ne contrôle aucun travail et ne lit que les paramètres du hook `on_session_end` (borné à 30 s par Hermes). Envoi FCM HTTP v1 dans un fil en arrière-plan pour ne pas retarder le tour. Compte de service et jeton dans `HERMES_HOME/hermes-mobile/`, hors dépôt.
- **Jeton app → plugin** : l'app transmet son jeton FCM par `command.dispatch hermes-mobile-token` à chaque envoi, via la connexion Hermes déjà authentifiée (plus de credential propre au mobile), sans bloquer. Une réponse 4018 (commande absente = plugin absent) produit « notification non suivie » ; ce signal doit être vérifié en réel plugin désactivé. Un seul jeton par profil : le dernier client qui l'envoie reçoit les notifications du profil.
- **Erreurs FCM** : `UNREGISTERED` → le plugin oublie le jeton jusqu'au prochain envoi de l'app ; erreur réseau → un seul nouvel essai.
- **Contrat** : `contracts/notification-tracking.json` ne décrit plus que le payload (titres, canal, `outcome`, `sessionId`) ; `contracts/notification-deployment.json` est supprimé. La CI exécute l'auto-vérification du plugin.
- **Pipeline d'envoi** (`OutboxRepository`, seul auteur) : `ensureSession` → pièces → jeton au plugin (non bloquant) → soumission. Le pas d'enregistrement/rattachement d'un `subscriptionId` disparaît.
- **Routage** : `sessionId` est l'identifiant stocké de la conversation. `resolveLaunchTarget()` donne priorité à la notification, puis à la restauration, puis à l'accueil, et ouvre `/c/<ConnectionKey>/<ProfileKey>/<SessionKey>`. Le passage de `subscriptionId` à `sessionId` touche `MainActivity.kt`, `firebase_notification_client.dart` et `routes.dart`. Ouverture à froid, à chaud et depuis les récents ; notification reçue app ouverte traitée avec `{outcome, sessionId}` ; rotation du jeton gérée.
- **Bloquant actuel** : l'app n'accepte que `{subscriptionId, outcome}` ; les notifications du plugin s'affichent app fermée mais sont ignorées en premier plan et le toucher n'ouvre pas la conversation.
- **Stockage** : migrations SQLite en ajout seul. Une nouvelle migration supprime `notification_subscriptions`, `notification_settings` et le secret `observerBearer` ; aucune migration existante n'est modifiée. Secrets jamais dans les notifications ni les journaux.
- **Paquets** : firebase_messaging 17.0.0 + firebase_core ^5.0.0 (ou 16.x si 17 n'est pas stable), minSdk 24.
- **Retrait (5.8)** : suppression de `server/notifier/`, `repository.yaml`, des étapes CI du notifier, de la section 5.1 de `contracts/README.md` et des mentions dans `README.md` ; clôture des reports propres à l'observateur dans `deferred-work.md`. Côté Home Assistant et Tailscale (fait par Alanc) : désinstaller l'add-on et retirer son dépôt, supprimer `/share/hermes-notifier/` et le service `svc:hermes-notifier` ; conserver `tag:hermes` et l'accès au port 9119.

## UX & Interaction Patterns

- Notification de fin : conversation identifiable et issue (réussite, erreur, arrêt confirmé) exprimée par un libellé générique.
- Marque visible « notification non suivie » sur le tour concerné, sans bloquer ni retarder l'envoi.
- Réglages du profil : plus d'URL ni de bearer d'observateur ; les explications sur la permission refusée et l'arrêt forcé restent.
- Refus de permission et prérequis manquants expliqués en vocabulaire quotidien, sans état exprimé par la seule couleur.

## Cross-Story Dependencies

- 5.6 (plugin et canal du jeton) précède 5.7 (bascule de l'app sur `sessionId` et 4018), qui précède 5.8 (retrait de l'observateur). 5.5 rejoue la validation G3 après 5.8.
- 5.4 reste la base du routage ; 5.7 en change seulement la clé.
- Touche le pipeline d'envoi des epics 2 à 4 (`outbox_repository.dart`) et réutilise l'authentification, les routes et la base locale de l'epic 1/2. L'epic 6 n'est pas concerné.
- Scénarios G3 de 5.5 : app fermée, coupure réseau pendant le travail, arrêt, délégation à un sous-agent, conversation reprise, `/new`, profil sans plugin, redémarrage de Hermes pendant un travail, arrêt forcé et permission refusée.
