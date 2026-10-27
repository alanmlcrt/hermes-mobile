---
title: 'Story 5.3 - Recevoir une notification à la fin de mon travail'
type: 'feature'
created: '2026-10-27'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '0438bb431302ebf12babb00654cdf3b1234ca4d0'
context:
  - '{project-root}/contracts/notification-tracking.json'
  - '{project-root}/contracts/notification-deployment.json'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** L’observateur 5.2 détecte les fins mais son transport reste simulé ; le mobile ne prépare aucun suivi. Alanc doit pouvoir être averti sans surveiller l’application.

**Approche :** Relier le pipeline mobile au registre durable, intégrer Firebase Messaging Android et le transport FCM HTTP v1 personnel. Expliquer permission, prérequis et santé dans les réglages existants.

## Boundaries & Constraints

**Toujours :** Respecter les contrats canoniques et les trois terminaux serveur. Persister une clé opaque par opération avant register, enregistrer avant soumission, attacher uniquement à l’exécution confirmée (`session_id:user_row_id` encodé base64url). Le suivi est borné et ne bloque jamais l’envoi ; son échec apparaît sur le tour. Conserver les associations pour la future 5.4. Bearer observateur distinct dans le stockage sécurisé, configuration par connexion. Rotation par réenregistrement des abonnements actifs ; révocation distante avec reprise locale si indisponible. Payload générique strict, sans contenu ni secret ; erreurs et logs bornés. Intégration verrouillée en dry-run.

**Jamais :** Créer un projet Firebase, déployer ou envoyer un push réel pendant cette implémentation. Projet, compte de service, configuration client réelle et essais téléphone restent en 5.5 selon le contrat. Implémenter le routage au toucher (5.4), annoncer G3 franchie ou garantir exactement une livraison. Une absence de Firebase ne doit pas empêcher l’application de démarrer.

## I/O & Edge-Case Matrix

| Cas | Entrée | Résultat | Échec |
|---|---|---|---|
| Permission | Acceptation explicite | Token disponible pour register | Refus ou Google absent expliqué |
| Envoi | Observateur configuré | Register puis submit puis attach confirmé | Soumission maintenue, « notification non suivie » |
| Reprise | Réponse submit perdue | Attache après rapprochement certain | Aucun ancien terminal associé |
| Rotation/révocation | Nouveau token ou désactivation | Mise à jour ou suppression distante | Reprise bornée après réouverture |
| Terminal | Réussite, erreur, arrêt confirmé | Libellé Android générique distinct | Retries contractuels ; token invalide révoqué |
| Sans Firebase | Configuration client absente | Application utilisable, état explicite | Aucun faux token ni faux succès |

</frozen-after-approval>

## Code Map

- `lib/data/outbox_repository.dart` — `send`, marqueur `notificationTracking`, `_accept` et rapprochement ; unique auteur du suivi.
- `lib/data/storage/migrations.dart`, `database.dart` — migrations additives SQLite et associations durables.
- `lib/data/storage/secret_store.dart` — modèle du stockage sécurisé ; credential observateur séparé.
- `lib/app/bootstrap.dart`, `lib/main.dart` — injection et cycle de vie ; Firebase facultatif sans configuration réelle.
- `lib/features/profiles/profile_settings_view.dart`, `profiles_view.dart`, `lib/app/routes.dart` — réglages, santé et injection existants.
- `server/notifier/hermes_notifier/{outbox,payload,service,config,health}.py` — réutiliser dispatcher, payload et compteurs ; remplacer le refus FCM personnel.
- `contracts/notification-tracking.json`, `notification-deployment.json` — endpoints, retries, secrets, canal Android et création Firebase différée ; ne pas modifier leurs décisions.

## Tasks & Acceptance

**Exécution :**
- [x] `lib/models/notifications.dart`, `lib/data/notification_repository.dart`, `lib/data/storage/migrations.dart` — client authentifié, configuration, suivi persistant, reprise, rotation/révocation et santé.
- [x] `lib/data/outbox_repository.dart` — register avant submit, attach après confirmation/reconstitution, échec indépendant de l’envoi et état durable du tour.
- [x] `lib/data/firebase_notification_client.dart`, `lib/app/bootstrap.dart`, `lib/main.dart`, `pubspec.yaml`, `pubspec.lock`, `android/` — Firebase, permission, canal, réception Android et cycle de vie ; versions proposées à confirmer par résolution/build, repli contractuel si nécessaire.
- [x] `lib/features/profiles/`, `lib/app/routes.dart`, `lib/ui/content.dart`, `lib/ui/components/` — configuration observateur, activation explicite, santé, prérequis, arrêt forcé et mention du tour ; tokens visuels existants et texte agrandi.
- [x] `server/notifier/hermes_notifier/fcm.py`, `service.py`, `config.py`, `requirements*.txt`, `config.yaml` — transport HTTP v1, OAuth renouvelable, délais bornés, classification des erreurs ; injection sûre du compte de service hors dépôt dans l’add-on.
- [x] `test/notification_*test.dart`, `test/send_flow_test.dart`, `server/notifier/tests/test_fcm.py` — matrice, redémarrage, panne/timeout, rotation, révocation, absence de configuration et non-divulgation, réseau Firebase simulé.
- [x] `server/notifier/DOCS.md`, `README.md`, `.gitignore`, `.github/workflows/ci.yml` — préparation Firebase/compte de service pour 5.5, configuration facultative et vérifications reproductibles.

**Critères d’acceptation :**
- Étant donné un envoi et un observateur indisponible, quand le suivi échoue, alors Hermes reçoit toujours la demande et le tour affiche « notification non suivie », même après restauration.
- Étant donné une confirmation retrouvée après coupure, quand le suivi reprend, alors seule l’exécution confirmée est attachée et aucune soumission supplémentaire n’est créée.
- Étant donné les trois terminaux, quand le transport traite l’outbox, alors les requêtes simulées respectent le payload contractuel et les erreurs permanentes/transitoires suivent sa politique.
- Étant donné une installation sans Firebase ou une permission refusée, quand l’app démarre, alors elle reste utilisable et explique l’état ; la santé observateur est visible et distincte.
- Étant donné les réglages, quand le texte est agrandi ou les contrôles lus par accessibilité, alors libellés, erreurs et actions restent utilisables sans dépendre de la couleur.

## Implementation Notes

Implémentation mobile et serveur terminée. Migrations additives, préparation et
attache bornées à quatre secondes, Firebase facultatif, canal Android, réglages
et marqueur du tour intégrés. Les contrats canoniques restent inchangés.
Rapport : [preuves et limites](story-5-3-verification/implementation-report.md).

## Spec Change Log

## Review Triage Log

| Réf. | Verdict | Preuve et traitement |
|---|---|---|
| B1 | high | `configure` exige des DELETE avec l’ancien bearer avant remplacement : un 401 empêche toute récupération. Correction locale : permettre le remplacement du bearer de la même origine et reprendre les révocations avec celui-ci. |
| B2 | medium | Aucun auteur de `notified` côté mobile ; `Store.register` réinitialise cet état. Préserver le terminal lors d’une rotation dans le registre serveur, sans recréer le suivi. |
| B3 | medium | Le filtre `created_at` ignore la date d’attache ; une attache tardive perd des jours de rotation. Stocker la première attache réussie et appliquer sa borne. |
| B4 | medium | La projection classe `expired` comme un échec, même après une attache réussie. Conserver le résultat historique de l’attache dans ce calcul. |
| B5 | medium | `_resume` parcourt toute la table et appelle un token sans timeout dans une branche ; les réglages attendent sa fin. Borner le lot et toutes les acquisitions de token. |
| B6 | medium | `_resuming ??=` perd une rotation survenant après le traitement d’une ligne. Mémoriser une passe supplémentaire, testée pendant une reprise. |
| B7 | medium | `_accept` attend l’attache avant `conversation.accepted` : la confirmation visible attend le réseau. Publier l’acceptation avant cet appel et actualiser le suivi ensuite. |
| B8 | low | `_load` laisse toujours la santé à `unconfigured`. Utiliser un état non vérifié pour une configuration existante. |
| B9 | medium | Sans abonnement, la reprise ne relit pas la permission ; le widget ne se rafraîchit pas au retour Android. Relire l’état sur reprise et rafraîchir ce widget via son cycle de vie. |
| B10 | low | Sous API 24/25, le builder de premier plan n’a ni priorité ni son ; ajouter les valeurs équivalentes au canal. Essai physique réservé à 5.5. |
| E1 | medium | Même défaut que B6 : rotation perdue pendant `_resuming`. Correction et test communs. |
| E2 | medium | Même défaut que B3 : expiration calculée depuis la préparation. Correction et test communs. |
| E3 | medium | Le timeout requests est un délai d’inactivité ; `raw.read(16385)` peut recevoir indéfiniment des octets espacés. Lire progressivement avec contrôle monotone de la durée, test de réponse lente. |
| V1 | medium | Le test nommé « register précède submit » ne vérifie pas l’ordre dans le handler Hermes. Ajouter l’assertion au point de soumission. |
| V2 | medium | Le test de rotation appelle explicitement resume, sans émettre le stream. Ajouter une rotation réelle du faux device, sans appel manuel. |
| V3 | medium | Le vrai client Firebase n’est testé que sans configuration ; la réussite utilise un fake Device. Simuler la plateforme Firebase pour exercer permission, token et erreur dans le client réel. |

Les correctifs relèvent de `patch` : corrections privées des méthodes et tests
existants, sans nouvelle surface publique ni modification de l’intention approuvée.
Les états à protéger sont démontrés ci-dessus ; aucun report ni changement de spec.

**Résolution :** les seize constats sont corrigés et vérifiés. B1 par le test de
récupération du bearer ; B2 par `test_rotation_notifie_conserve_terminal_date_ttl_et_dedup`
du stockage serveur ; B3/B4/E2 par le test d’attache tardive et historique ;
B5 par le test de lot/acquisition muette ; B6/E1/V2 par la rotation stream pendant
une reprise ; B7 par la publication avant la réponse attach ; B8/B9 par le test
widget de santé non vérifiée et retour Android ; B10 par inspection du builder
API 24/25 et compilation APK ; E3 par le test FCM de réponse lente ; V1 par
l’assertion dans le handler `prompt.submit` ; V3 par les trois tests de plateforme
Firebase configurée. Les tests correspondants ont tous tourné dans les suites finales.

**Audit de matrice :** permission et absence Firebase couvertes par le vrai client
simulé et les widgets ; envoi et panne par les tests repository ; reprise par la
réponse perdue et la fenêtre de crash ; rotation/révocation par les tests stream et
réouverture SQLite ; terminaux par les tests FCM et dispatcher existants.

## Verification

- `flutter analyze --no-pub`, `flutter test --no-pub` — aucune régression.
- `flutter build apk --debug` — plugins résolus et compilation Android sans configuration Firebase réelle.
- `python -m unittest discover -s server/notifier/tests -t server/notifier`, `python server/notifier/sync_contracts.py --check` — tests réussis et contrats identiques.
- `story-5-3-verification/implementation-report.md` — consigner preuves et limites.

Résultats finaux après revue : analyse sans anomalie ; 486 tests Flutter réussis,
17 ignorés ; 128 tests Python réussis ; APK debug compilé sans configuration
Firebase ; contrats identiques ; `git diff --check` sans erreur. Journaux `final-*`
dans le dossier de vérification. Aucun push ni déploiement réel ; G3 reste ouverte.
