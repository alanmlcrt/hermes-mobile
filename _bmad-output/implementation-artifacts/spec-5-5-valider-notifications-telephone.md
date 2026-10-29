---
title: 'Story 5.5 - Valider les notifications sur mon téléphone'
type: 'chore'
created: '2026-10-27'
status: 'in-progress'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '43285140f163e0dbf9aa08bb0cece033320a2483'
context:
  - '{project-root}/contracts/notification-deployment.json'
  - '{project-root}/server/notifier/DOCS.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Les stories 5.1–5.4 sont prouvées par tests et dry-run seulement. Aucun projet Firebase, compte de service, observateur déployé ni push réel n’existe ; la porte G3 reste ouverte (`contracts/notification-deployment.json`, `gate.status: open`).

**Approche :** Créer la configuration Firebase personnelle, déployer l’observateur en `personal` sur Home Assistant derrière Tailscale Serve, installer l’APK configuré sur le téléphone d’Alanc, jouer les scénarios G3 réels avec un profil de test, consigner les preuves, corriger les écarts bloquants et déclarer G3 franchie ou remonter les écarts.

## Boundaries & Constraints

**Toujours :** Essais réels uniquement (téléphone, HA, Hermes, FCM) ; aucune simulation ne compte comme preuve. Profil Hermes de test. Clé du compte de service et `google-services.json` hors dépôt ; seul l’identifiant de projet (non secret) est consigné. Aucun contenu conversationnel, token, bearer ni chemin privé dans les preuves. Chaque action externe (création cloud, déploiement HA, installation APK) est annoncée avant exécution. Un défaut trouvé est corrigé dans le code avec un test, ou consigné comme écart.

**Jamais :** Déclarer G3 franchie avec un scénario manquant ou échoué. Publier le port 8787 sur l’hôte ou le LAN. Promettre exactement une livraison. Modifier les décisions contractuelles hors statut de porte, identifiants non secrets et valeurs `proposed` confirmées.

## I/O & Edge-Case Matrix

| Scénario | Situation | Attendu | Preuve |
|---|---|---|---|
| App fermée | Envoi puis app tuée (balayage) | ≥1 notification, toucher ouvre la conversation | Capture + journal observateur `domaine.code` |
| Coupure réseau | Mode avion pendant le travail, retour après la fin | ≥1 notification après reconnexion | Idem |
| Redémarrage observateur | Redémarrage add-on pendant le travail | Rattrapage, ≥1 notification, aucun ancien terminal | Idem + compteurs santé |
| Observateur absent | Add-on arrêté pendant l’envoi | Envoi accepté, tour « Notification non suivie » | Capture |
| Toucher froid / chaud / récents | App tuée, arrière-plan, relance depuis les récents | Bonne conversation, consommation unique | Capture |
| Arrêt forcé | Réglages Android → Forcer l’arrêt | Aucune réception jusqu’à réouverture, puis reprise ; explication dans l’app | Capture |
| Permission refusée | Refus de la permission | Aucune notification, explication dans l’app | Capture |

**Décisions (Alanc, 2026-10-27) :**
- Firebase : Alanc crée projet, app Android `fr.hermes_mobile` et compte de service dans la console, puis dépose `android/app/google-services.json` et la clé hors dépôt ; l’agent vérifie (fichiers ignorés, id de projet, rôle).
- Add-on : la branche `epic/5-notifications` est poussée sur GitHub et HA installe depuis le dépôt `https://github.com/alanmlcrt/hermes-mobile#epic/5-notifications`.
- Téléphone : branché en ADB (USB ou sans fil) ; l’agent installe l’APK, lit `logcat`, capture l’écran ; Alanc fait les gestes physiques.
- APK debug avec `google-services.json` ; profil Hermes de test désigné par Alanc au début des essais.

</frozen-after-approval>

## Code Map

- `contracts/notification-deployment.json` — `gate`, `validation.pending/proposed`, `firebase.projects/serviceAccounts/clientConfig` à mettre à jour (statut, `identifier` = id de projet seulement) ; recopier via `python server/notifier/sync_contracts.py` puis `--check`.
- `server/notifier/config.yaml` — options `environment: personal`, `fcm_enabled`, `fcm_service_account: /share/hermes-notifier/service-account.json`, `bearer_hash/salt` (§3.2 de `DOCS.md`).
- `server/notifier/DOCS.md` §3, §10, §15 — procédures d’installation, Tailscale Serve, FCM ; §10/§14 à passer de « cible 5.5 » à « validé » avec les valeurs réelles.
- `android/app/build.gradle.kts` — plugin Google Services appliqué seulement si `android/app/google-services.json` existe (ignoré par Git).
- `lib/features/profiles/profile_settings_view.dart` — configuration observateur (origine HTTPS + bearer), activation, explications permission/arrêt forcé à constater.
- `android/app/src/main/kotlin/fr/hermes_mobile/MainActivity.kt` — chemin natif du toucher non testé (report 5.4 dans `deferred-work.md`).
- Flutter via FVM (`fvm flutter …`), `adb` dans le PATH ; aucun appareil branché actuellement.

## Tasks & Acceptance

**Exécution :**
- [ ] Firebase (Alanc, console) — projet personnel unique (Spark), app Android `fr.hermes_mobile`, compte de service `roles/firebasecloudmessaging.admin` ; l’agent vérifie `google-services.json` ignoré et la clé hors dépôt.
- [ ] GitHub — `git push -u origin epic/5-notifications` (annoncé avant exécution).
- [ ] Home Assistant — dépôt `…#epic/5-notifications`, clé dans `/share/hermes-notifier/`, add-on installé en `personal` avec bearer, Tailscale Serve 443→8787, santé vérifiée depuis le tailnet.
- [ ] Téléphone — `fvm flutter build apk` avec `google-services.json`, installation, configuration observateur, activation.
- [ ] Scénarios — jouer chaque ligne de la matrice ; corriger tout défaut bloquant (code + test) puis rejouer.
- [ ] `_bmad-output/implementation-artifacts/story-5-5-verification/rapport-g3.md` — protocole, résultats par scénario, preuves expurgées, écarts.
- [ ] `contracts/notification-deployment.json`, copie serveur, `server/notifier/DOCS.md`, `deferred-work.md` — porte G3 `crossed` ou écarts listés ; report 5.4 clôturé.

**Critères d’acceptation :**
- Étant donné le rapport, quand il est relu, alors chaque scénario a un résultat constaté et une preuve, sans secret ni contenu.
- Étant donné tous les scénarios réussis, quand le contrat est mis à jour, alors `gate.status` vaut `crossed` et les tests contractuels passent ; sinon la porte reste `open` et les écarts sont remontés à Alanc.

## Implementation Notes

**En pause (2026-10-29), à la demande d'Alanc :** priorité donnée à l'étude d'un plugin Hermes remplaçant l'observateur (voir ci-dessous). G3 reste ouverte.

État du déploiement : Firebase `hermes-mobile-f22ed` créé par CLI (gcloud), dépôt public, add-on 0.1.4 en `personal`, exposé par Tailscale Services (`host_network`, écoute 127.0.0.1:8787, sans watchdog TCP), APK **release** signé (et non debug : signature de l'app déjà installée), profil `.hermes` (affiché « default »).

Défauts corrigés pendant les essais (commits 88f0723…6bac332) : jeton FCM via `getToken` (le FID de `register()` ne se résolvait jamais) et permission sans délai de 3 s ; attache avec `stored_session_id` (Hermes renvoie 4007 sur l'id runtime) ; `last_seen` omis au premier rattrapage (-32602 sur `null`) ; `rpc_code` journalisé. Faiblesse : le test 4007 ne distingue pas l'ancien comportement.

Scénarios joués :
- App fermée — réussi (`04-app-fermee-observateur.log`, `delivered: 1`).
- Toucher froid, chaud — réussis, constatés par Alanc (captures noires : écran éteint).
- Relance depuis les récents après `am kill` — réussi, accueil, toucher non rejoué (`06-relance-recents-accueil.png`).
- Permission refusée — explication capturée (`01-…png`), absence de notification non encore constatée.
- Restent : coupure réseau, redémarrage observateur, observateur absent, arrêt forcé.

Restent ensuite : `rapport-g3.md`, contrat (`hermes-mobile-f22ed`, écoute loopback/Tailscale Services 443), `DOCS.md` §3/§10/§14/§15, `deferred-work.md` (clore 5.4, 4007), vérifications finales, revue (step-04).

**Écart remonté par Alanc :** installation trop lourde (add-on, Firebase, URL + bearer par profil). Piste : plugin Hermes (`~/.hermes/plugins/`) avec hook `on_session_end` (par tour : `session_id`, `completed`, `interrupted`, `failed`, `platform`) envoyant FCM, jeton enregistré par commande slash (`ctx.register_command`). À prouver : déclenchement pour les tours de l'app, nature de `session_id`, appel de commande depuis l'app, bibliothèque de signature OAuth dans l'add-on Hermes, persistance du plugin aux mises à jour.

## Spec Change Log

## Review Triage Log

## Verification

**Commandes :**
- `fvm flutter analyze --no-pub` et `fvm flutter test --no-pub` — aucune régression.
- `python -m unittest discover -s server/notifier/tests -t server/notifier` et `python server/notifier/sync_contracts.py --check` — réussis, contrats identiques.
- `git status --ignored` — `google-services.json` et clé ignorés, jamais suivis.

**Vérification manuelle :** les scénarios de la matrice sur le téléphone réel, constatés par Alanc.
