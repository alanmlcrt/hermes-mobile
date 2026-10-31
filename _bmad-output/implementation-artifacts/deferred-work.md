- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-init-app-telephone.md`
  summary: Choisir l'identifiant de bundle iOS (actuellement `fr.hermesMobile`, généré par `flutter create`), puisque `fr.hermes_mobile` est invalide sur iOS.
  evidence: `ios/Runner.xcodeproj/project.pbxproj` l.386 diffère de l'identifiant Android ; les `_` sont interdits dans un bundle id iOS. À trancher avant le travail iPhone.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-1-nouvelle-conversation-brouillon.md`
  summary: Après un changement de profil depuis « Mes profils », ouvrir le brouillon du nouveau profil au lieu de revenir à celui de l'ancien.
  evidence: `/profiles` est poussé depuis `/draft/<clé>` et `selectProfile` ne relance pas `resolveLaunchTarget` ; relève de la story 2.5.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-1-nouvelle-conversation-brouillon.md`
  summary: Tester que `MainApp.dispose` vide l'outbox avant de fermer la base via le gateway.
  evidence: `MemoryOutbox.dispose` est vide ; l'ordre `outbox.dispose().whenComplete(gateway.dispose)` de `lib/main.dart` n'est observé par aucun test.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-envoi-sans-double-execution.md`
  summary: Rapprocher une opération `unknown` quand une réponse tardive ou l'historique prouve son acceptation.
  evidence: `call()` retire l'id au timeout, une réponse tardive est ignorée ; relève de la story 2.4.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-envoi-sans-double-execution.md`
  summary: L'accueil rouvre un brouillon de conversation existante quand il contient du texte, au lieu d'une nouvelle conversation.
  evidence: `openNewDraft` préfère `body <> ''` ; à remplacer par la restauration de 2.4/2.6 une fois l'historique disponible.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-3-reponse-en-direct.md`
  summary: Appariement des bulles utilisateur aux tours robuste aux tours lancés par un autre client sur la même session.
  evidence: `accepted()` apparie par position (`userTurns + 1`) ; un tour démarré ailleurs décale les liaisons.

- source_spec: spec-compagnon-lapin-lot-1.md
  summary: Réconcilier les descriptions historiques de teinte et la maquette de contexte avec la planche v5.
  evidence: Sources UX préexistantes suivies à la demande utilisateur ; table taupe et ancien SVG à oreille pliée malgré la priorité v5 explicitement blanche sans pli. Aucun changement métier causé par ce lot.

- source_spec: `spec-3-5-arret-travail.md`
  summary: Distinguer chargement, erreur et liste vide sur l’accueil, empêcher l’ouverture prématurée d’un brouillon et permettre l’actualisation.
  evidence: Blind 3/4/5 et Edge 2 : FutureBuilder ignore hasError, onTap reste actif et _latest est final ; comportement antérieur à 3.5.
- source_spec: `spec-3-5-arret-travail.md`
  summary: Rendre les pastilles de couleur activables au lecteur d’écran.
  evidence: Blind 6 et Edge 3 : Semantics excludeSemantics masque InkResponse sans exposer onTap ; réglages préexistants.
- source_spec: `spec-3-5-arret-travail.md`
  summary: Protéger les sélections de couleur concurrentes contre le rollback d’une ancienne écriture échouée.
  evidence: Blind 7 : ProfileAccents.choose restaure previous sans vérifier la sélection actuelle ; module préexistant inchangé.
- source_spec: `spec-3-5-arret-travail.md`
  summary: Faire tenir les identifiants de profil longs avec texte agrandi dans les réglages.
  evidence: Blind 8 : Text(profile.value) non contraint dans ListTile.trailing ; surface préexistante.
- source_spec: `spec-3-5-arret-travail.md`
  summary: Regrouper l’historique par date calendaire, y compris lors du passage à l’heure d’été.
  evidence: Edge 4 : durée entre deux minuits locaux de 23 h ramenée à zéro jour par inDays ; fonction antérieure à 3.5.
- source_spec: `spec-3-5-arret-travail.md`
  summary: Vérifier la sélection et la persistance des accents via leurs consommateurs.
  evidence: Verification 1 : aucune assertion sur choose/store.save, réouverture SQLite et isolement ; le test de migration écrit directement le SQL. Surface préexistante.
- source_spec: `spec-3-5-arret-travail.md`
  summary: Vérifier la classification d’un outil reconnu depuis les événements du repository jusqu’à la projection persistée.
  evidence: Verification 2 : forTool est testé seul ; le branchement repository préexistait à 3.5 et aucun scénario reçu reconnu ne le couvre.

- source_spec: `_bmad-output/implementation-artifacts/spec-etude-2-plugin-hermes-fcm.md`
  summary: Plugin de notifications : plusieurs téléphones par profil, sans qu'un client écrase le jeton d'un autre.
  evidence: `HERMES_HOME/hermes-mobile/fcm-token` est unique ; le dernier client qui appelle `command.dispatch` reçoit tout.

- source_spec: `_bmad-output/implementation-artifacts/spec-5-5-valider-notifications-telephone.md`
  summary: Détecter un profil sans plugin de notifications (« Notification non suivie ») alors que Hermes sert tous les profils dans un seul processus.
  evidence: G3 2026-10-30 : `/hermes-mobile-token` accepté sur `mesure-pieces-jointes` (aucun plugin), pas de 4018, mention absente ; bloque G3.
- source_spec: `_bmad-output/implementation-artifacts/spec-5-5-valider-notifications-telephone.md`
  summary: Trancher le scénario G3 `/new` : non applicable (aucune commande `/` dans l'app) ou story dédiée.
  evidence: « /new … » envoyé comme message ordinaire (`kind=user`) ; bloque G3 tant que non tranché.
- source_spec: `_bmad-output/implementation-artifacts/spec-5-5-valider-notifications-telephone.md`
  summary: Constater dans l'app les explications de l'arrêt forcé et de la permission refusée.
  evidence: Absence de notification constatée en G3, explications non regardées.
- source_spec: `_bmad-output/implementation-artifacts/spec-5-7-basculer-app-plugin.md`
  summary: Vérifier sur téléphone la notification reçue app ouverte (`show` en premier plan) avec le vrai payload du plugin.
  evidence: G3 2026-10-30 a joué froid, chaud et récents (report Kotlin `sessionId` et récents clos) ; aucun essai explicite app au premier plan.
- source_spec: `_bmad-output/implementation-artifacts/spec-5-5-valider-notifications-telephone.md`
  summary: Décider du comportement des notifications pour une délégation asynchrone (annonce puis résultat : deux notifications).
  evidence: G3 2026-10-30 : 09:33:02 et 09:33:11 (tour `kind=async_delegation_complete`) notifiés ; la matrice en attendait une.
- source_spec: `_bmad-output/implementation-artifacts/spec-5-5-valider-notifications-telephone.md`
  summary: Jouer un arrêt brutal de Hermes (plantage, kill) pendant un tour et constater la perte annoncée.
  evidence: Seul l'arrêt propre (SIGTERM) a été joué : il interrompt le tour et notifie « arrêté ».
- source_spec: `_bmad-output/implementation-artifacts/spec-5-5-valider-notifications-telephone.md`
  summary: Rejouer en réel la garde `session_close` restreinte du plugin 1.0.2 (seuls les arrêts sans `turn_id` sont ignorés).
  evidence: 1.0.1 prouvé en réel (09:30:26) ; 1.0.2, restreinte après revue, couverte par l'auto-vérification seulement.

- source_spec: `_bmad-output/implementation-artifacts/spec-6-2-repondre-question-hermes.md`
  summary: Notifier « Hermes attend ta réponse » sur le téléphone quand une question (clarify) est posée app fermée, via le plugin Hermes de notifications.
  evidence: Le plugin de l'Epic 5 ne notifie que les fins de travail ; une question non vue expire après 300 s. Reporté par Alanc le 2026-10-30 pour garder la 6.2 côté app.
- source_spec: `_bmad-output/implementation-artifacts/spec-6-2-repondre-question-hermes.md`
  summary: Permettre d'envoyer un message pendant un travail en cours (`prompt.submit` répond `redirected`, injecté dans le tour), aujourd'hui bloqué par `send.turn_active`.
  evidence: Mesuré en 6.1 (fixture `prompt-submit-redirected.json`) ; écarté de la 6.2 par Alanc le 2026-10-30, car cela touche le flux d'envoi de l'Epic 2.

- source_spec: `_bmad-output/implementation-artifacts/spec-6-5-valider-mvp-essai-reel.md`
  summary: Contrôles restants de l'essai global reportés à la demande d'Alanc pour commencer l'epic 7 ; story 6.5 clôturée, G3 et acceptation technique réelle ouvertes.
  evidence: Décision du 2026-10-30 consignée à 16:46:50Z (« marque comme terminé, je voudrais ensuite passer au dev de l'epic 7 »). `story-6-5-verification/rapport-mvp.md` conserve M03–M09, corrélations serveur et rejeu ergonomique +24 non démontrés ; aucun report historique G3 clos par cette décision.

- source_spec: `_bmad-output/implementation-artifacts/spec-7-1-verifier-rangement-recherche.md`
  summary: Préciser le traitement de session.title pending dans la story 7.2.
  evidence: Le plan 7.2 préexistant demande confirmation avant affichage, mais le contrat documentaire autorise pending ; qualifier la persistance et la réconciliation avant cette story.

- source_spec: `_bmad-output/implementation-artifacts/spec-7-1-verifier-rangement-recherche.md`
  summary: Vérifier la coordination des mutations de masquage par lignée dans 7.4 (risque moyen non vérifié).
  evidence: Le plan préexistant sérialise par session alors que le candidat touche une lignée ; vérifier deux IDs partageant la même lignée et la concurrence sur installation pour trancher.

- source_spec: `_bmad-output/implementation-artifacts/spec-7-1-verifier-rangement-recherche.md`
  summary: Mesurer la réactivité de la recherche 7.6 sur un corpus local représentatif (risque moyen non vérifié).
  evidence: Le plan préexistant ne borne pas le travail à la saisie ; aucune implémentation ne démontre de blocage. Mesures de latence et volume réel nécessaires pendant 7.6.

- source_spec: `_bmad-output/implementation-artifacts/spec-7-2-renommer-conversation.md`
  summary: Exploiter ou contrôler `session_key` rendu par `session.title` (risque moyen non vérifié).
  evidence: `HermesRpc.titled` valide puis ignore `session_key` ; si Hermes re-clé la session, la ligne garde un identifiant périmé. La qualification réelle de `session.title` tranchera.

- source_spec: `_bmad-output/implementation-artifacts/spec-7-2-renommer-conversation.md`
  summary: Sérialiser les `session.resume` concurrents d'une même session (risque moyen non vérifié).
  evidence: `OutboxRepository.resume` n'a pas de verrou par clé ; un renommage et une ouverture peuvent reprendre la même session en parallèle. Effet serveur à observer sur installation.

- source_spec: `_bmad-output/specs/spec-7-3-epingler-marquer-non-lu/SPEC.md`
  summary: Purger les marqueurs d'un fil disparu côté serveur (AC-7/8 non implémentés).
  evidence: Aucune preuve distante de disparition n'est qualifiée (7.1) ; les marqueurs d'un fil supprimé depuis un autre client restent en base. Seule la suppression depuis le téléphone (7.5) les efface.

- source_spec: `_bmad-output/specs/spec-7-3-epingler-marquer-non-lu/SPEC.md`
  summary: Tenir compte du cycle de vie de l'app pour le non-lu.
  evidence: Un fil laissé ouvert avec l'app en arrière-plan compte comme consulté ; une fin de tour reçue alors ne le rend pas non lu. Une fin connue seulement par resynchronisation ne marque pas non plus le fil.

- source_spec: `_bmad-output/specs/spec-7-4-masquer-retrouver-conversations/SPEC.md`
  summary: Portée de `session.set_hidden` sur la lignée et choix hidden/archive à qualifier.
  evidence: Implémentation sur `session.set_hidden` (ID stocké) d'après le contrat documentaire ; `session.archive` non utilisé. La sonde 7.1 doit confirmer réversibilité, `include_hidden` et effet sur la lignée.

- source_spec: `_bmad-output/specs/spec-7-5-supprimer-conversation/SPEC.md`
  summary: Trancher une suppression « à vérifier » par une preuve distante.
  evidence: Après un résultat inconnu, l'état `pending` persiste et tout est conservé ; seule une nouvelle tentative explicite est possible. Une réponse d'erreur à cette tentative (fil déjà supprimé) rétablit le fil localement sans preuve. À revoir après qualification de `session.delete` et de ses erreurs.

- source_spec: `_bmad-output/specs/spec-7-6-rechercher-conversation/SPEC.md`
  summary: Normalisation Unicode complète et recherche serveur.
  evidence: Le repliement couvre les lettres latines accentuées et les marques combinantes U+0300–036F ; une décomposition NFD complète demanderait une dépendance. Aucune recherche serveur n'est qualifiée : seule la couverture locale est proposée.

- source_spec: `_bmad-output/specs/epic-8-index.md`
  summary: Qualifier Bot Mode et G5 sur les deux profils de test, sans sonde authentifiée dans cette livraison.
  evidence: Contrat OpenRPC extrait dans contracts/epic-8/methods.json (documentary). Procédure Samba réversible fournie ; valeur agent.bot_mode_protocol et activation réelle à confirmer par Alan. Aucun fichier Hermes ni profil n'a été modifié.

- source_spec: `_bmad-output/specs/epic-8-index.md`
  summary: Identifier le blocage réel des salons après activation manuelle du marqueur Bot Mode.
  evidence: Alan signale le même message après modification de profile.yaml et redémarrage. Les releases 27-29 confondaient driver false et seatable_profiles absent ou vide ; ce diagnostic est corrigé en release 30. Les valeurs de capacités sont affichées sans noms de profils, contenu ou secrets. Aucun appel authentifié direct ni changement serveur effectué ; statut réel du pilote encore à relever dans l'app.

- source_spec: `_bmad-output/specs/epic-8-index.md`
  summary: Vérifier les payloads ouverts de messages, activités, tâches et autorisations sur Hermes réel.
  evidence: OpenRPC décrit RoomEvent.payload et pending_actions comme objets ouverts ; les conventions payload.text, tool.start/complete et champs directs des actions sont préparées mais non observées. Contexte incomplet = décision indisponible. État blocked utilisé pour l'attente ; seuils 10 messages / 3 tours et attribution de l'agent actif sans événement d'outil non qualifiés.

- source_spec: `_bmad-output/specs/epic-8-index.md`
  summary: Activer et vérifier le relais de notifications de salon app fermée.
  evidence: Aucun hook de salon documenté dans le contrat fourni ; aucun déploiement Hermes effectué. L'app accepte le payload minimal roomId/outcome (needs_user ou approval), ouvre une cible locale non ambiguë et groupe les notifications Android reçues au premier plan. La livraison app fermée dépend d'un relais externe non qualifié ; elle n'est pas démontrée ni simulée comme disponible.

- source_spec: `_bmad-output/specs/epic-8-index.md`
  summary: Qualifier l'idempotence réelle de groups.send avant toute nouvelle tentative d'un envoi incertain.
  evidence: event_id persisté avant la trame, aucun rejeu automatique, même après redémarrage. Tant que l'idempotence n'est pas constatée sur installation, les envois inconnus bloquent un nouvel envoi dans ce salon et ne sont réconciliés que par un event_id identique dans le journal. Si Hermes emploie un autre identifiant serveur, un adaptateur de preuve sera nécessaire ; aucune correspondance par texte.

- source_spec: `_bmad-output/specs/epic-8-index.md`
  summary: Mesurer les grands journaux et confirmer les traces historiques des autorisations.
  evidence: Relecture complète paginée, contrôle de continuité et cache conservé en cas d'échec ; actualisation au premier plan. Fil construit intégralement pour ouvrir le message d'escalade exact. Aucune mesure sur grand salon. Les cartes d'autorisation résolues restent pendant l'ouverture ; leur conservation après redémarrage dépend des événements effectivement exposés.

- source_spec: `_bmad-output/specs/epic-8-index.md`
  summary: Gérer les salons et partager les fichiers dans les stories 8.8 et 8.9, hors périmètre demandé.
  evidence: Méthodes rename/disband/attachment documentées, aucune route ou pipeline de pièces jointes parallèle ajouté. Aucune méthode de changement des membres documentée. Tests téléphone, validation réelle, fusion master et CI master restent conditionnés au retour d'Alan.

