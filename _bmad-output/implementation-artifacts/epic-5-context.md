# Epic 5 Context: Être averti quand Hermes a fini

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Alanc peut quitter l'application sans surveiller Hermes : quand un travail suivi se termine réellement (réussite, erreur, arrêt confirmé), il reçoit une notification même app fermée et un toucher ouvre la conversation concernée. L'épic couvre l'observateur serveur indépendant du mobile, FCM et `resolveLaunchTarget()`. Le travail continue côté serveur et la confiance dans le résultat exige une notification fiable, sans fausse fin ni fuite de contenu. Requiert G3.

## Stories

- Story 5.1: Fixer le contrat de suivi et le déploiement de l'observateur
- Story 5.2: Faire tourner l'observateur de fins de travail
- Story 5.3: Recevoir une notification à la fin de mon travail
- Story 5.4: Ouvrir la bonne conversation depuis une notification
- Story 5.5: Valider les notifications sur mon téléphone

## Requirements & Constraints

- **Trois fins notifiables.** Seuls réussite, erreur et arrêt confirmé notifient. Un terminal vient du serveur ; socket coupée, silence, animation ou fin indémontrable ne valent jamais réussite.
- **Indépendance du mobile.** Détection et envoi ne dépendent d'aucune socket du téléphone ; l'observateur reprend après redémarrage et rattrape la source persistante de Hermes.
- **Suivi non bloquant.** Demandé avant la soumission, rattaché à l'exécution confirmée, il ne bloque jamais l'envoi ; en cas d'échec, le tour affiche « notification non suivie ».
- **Indice, pas autorité.** Un toucher ouvre la bonne conversation ; l'app se réauthentifie et recharge l'état depuis Hermes. Cible absente : explication puis accueil, sans réaffecter le résultat au fil affiché.
- **Minimalité et secrets.** Le bloc data ne porte que le `subscriptionId` et l'issue ; la notification ne porte qu'un libellé générique. Aucun texte, chemin ni secret dans le push, les erreurs, journaux ou diagnostics.
- **Livraison vérifiable.** Pas d'« exactement une fois » : les essais exigent au moins une notification par fin, jamais pour un ancien terminal ; retries bornés, rotation du token, ouverture à froid et à chaud.
- **Permission et prérequis Android.** Refus, services Google absents, optimisation batterie et arrêt forcé sont expliqués ; après un arrêt forcé, la réception reprend à la réouverture. Santé de l'observateur visible.
- **Accessibilité et essai réel.** Noms accessibles, cibles suffisantes, texte agrandi, lecteur d'écran, états jamais par la seule couleur. App fermée, coupure, redémarrage ou absence de l'observateur sont éprouvés sur le téléphone et l'installation réels.

## Technical Decisions

- **Observateur séparé.** `server/notifier/`, après G3, est supervisé à part (volume persistant, santé). Il lit Hermes via le contrat et le mapping partagé, sans soumettre ni contrôler de travail ni toucher aux bases privées. Le mobile s'y authentifie avec un credential propre, exigé pour la santé.
- **Registre et outbox durables.** Registre indexé par `subscriptionId`, clé opaque du mobile et seule clé partagée avec l'observateur et le push. Suivi créé avant la soumission, rattaché à l'exécution confirmée, dédupliqué par cible/exécution/terminal.
- **Mapping unique.** Mobile et observateur partagent la table déclarative de `contracts/` et ses fixtures ; seul le serveur fournit un terminal.
- **Pipeline.** Opération persistée avant envoi, puis `ensureSession` → pièces → suivi (non bloquant) → soumission. `OutboxRepository` seul auteur du suivi ; `ConversationRepository` ne crée jamais de session.
- **Identités et routage.** `ConnectionKey` + `ProfileKey` + `SessionKey`, opaques et sensibles à la casse ; `ConnectionKey` stable si l'URL change. Route `/c/<ConnectionKey>/<ProfileKey>/<SessionKey>` ; `resolveLaunchTarget()` : notification, restauration, accueil.
- **Push.** FCM HTTP v1, gratuit, sans quota, plan Spark ; `firebase_messaging` 17.0.1 + `firebase_core ^5.1.0` proposés sous réserve du build 5.3 (16.x sinon), minSdk 24. Un seul projet Firebase personnel et un seul compte de service hors dépôt ; l'intégration reste en dry-run. Message `notification + data` : libellé générique côté serveur, data strict `{subscriptionId, outcome}`. L'app enregistre le token auprès de l'observateur, gère rotation/révocation, froid/chaud et retries bornés.
- **Exploitation.** Logs `domaine.code` corrélés localement, sans contenu conversationnel ni credentials. Environnements isolés (clés, bases, push) ; APK privé signé, secrets FCM hors dépôt. Capacité obligatoire absente signalée, jamais contournée.

## UX & Interaction Patterns

- **Retour de fin.** La notification rattache l'issue (réussite, erreur, arrêt confirmé) à la conversation concernée, sans exposer le contenu ; libellé visible générique.
- **États lisibles.** `connecté`, `resynchronisation`, `hors ligne` distincts des états du travail ; santé de l'observateur et écart de capacités visibles. « Notification non suivie » marque le tour.
- **Permission refusée.** L'app explique pourquoi les notifications n'arrivent pas, plutôt que de laisser croire que le silence signifie « pas encore fini ».

## Cross-Story Dependencies

- **G3 (bloquante).** Déploiement et runtime de l'observateur, contrat du registre, auth mobile→observateur, rattrapage et prérequis Android sont tranchés avant le transport push. 5.1 fixe contrat et déploiement ; 5.5 valide la porte.
- **5.1 → 5.2 → 5.3 → 5.4 → 5.5.** Contrat et déploiement précèdent l'observateur, puis la réception push et l'ouverture ciblée ; 5.5 valide le tout sur téléphone réel.
- **Epics 1 et 2.** Le contrat figé et le mapping partagé viennent de l'Epic 1. L'Epic 2 fournit « suivi de notification », `OutboxRepository`, `resolveLaunchTarget` et le rechargement après resynchronisation.
- **Epic 3.** « Arrêt confirmé » réutilise sa sémantique : seul un terminal serveur `stopped` confirme l'arrêt.
- **Dépendances externes.** Projet Firebase et compte de service hors dépôt, runtime supervisé avec volume persistant sur Home Assistant, téléphone Android d'Alanc.
