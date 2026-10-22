---
title: 'Compagnon lapin — arrière-plan mémorisé par profil'
type: 'feature'
created: '2026-10-22'
status: 'done'
baseline_commit: '24edb11b713606b7b9c2681ada75b0017a3d10ed'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Le fond d’Otc est identique pour tous les profils et ne peut être personnalisé.

**Approche :** Depuis son panneau, ouvrir « Arrière-plan » : aperçu local, palettes pastel fixes avec verre dépoli, puis Appliquer ou Annuler.

## Boundaries & Constraints

**Toujours :** Conserver RabbitCompanion, Otc, l’anatomie v5, chatouilles, pause, suspension et mouvement réduit. Fond immobile, visage net : le voile dépoli est derrière le lapin. Texte et commandes sur surfaces sémantiques du thème ; cibles 48 px, focus visible, sélection nommée et annoncée. Éditeur défilant, SafeArea, clair/sombre et texte 200 %.

**Persistance décidée :** SQLite local existant, disponible hors ligne et après redémarrage ; aucune synchronisation entre appareils. Nouvelle table additive `companion_backgrounds`, clé primaire composée de l’origine normalisée par `parseOrigin(...).toString()`, `ConnectionKey.value` et `ProfileKey.value`, sensibles à la casse pour les clés opaques. Colonne locale `palette_id` : identifiant stable parmi trois palettes « Lavande et pêche » (défaut actuel), « Menthe et ciel », « Rose et lilas ». Une écriture atomique seulement sur Appliquer, succès après confirmation SQLite. La clé de connexion seule est insuffisante : `confirmOrigin` la réutilise entre serveurs. Réauthentification de la même connexion conserve le choix ; effacement des données de l’application le supprime. Aucun compte utilisateur distinct n’est exposé par le contrat actuel.

**Jamais :** Inventer un champ de Profile ou un endpoint Hermes ; modifier l’identité globale des connexions ; importer une image ; toucher génération, trois points, thème global ou anatomie.

## I/O & Edge-Case Matrix

| Cas | Entrée / action | Résultat attendu | Traitement |
| --- | --- | --- | --- |
| Lecture | Préférence absente / inconnue | Fond par défaut | Aucune écriture automatique |
| Lecture échouée | SQLite indisponible | Repli visuel, erreur et Réessayer | Édition bloquée jusqu’à lecture réussie |
| Prévisualisation | Choisir une palette | Seul l’aperçu change | Panneau enregistré inchangé |
| Abandon | Annuler / Retour avant Appliquer | Fermer, retrouver le fond enregistré | Zéro écriture |
| Application | Appliquer | Écriture atomique puis fermeture et panneau actualisé | Doubles soumissions et sortie bloquées pendant l’écriture |
| Échec | Écriture rejetée | Même édition et palette conservées | Erreur annoncée, Réessayer ou Annuler |
| Identité changée | Serveur / profil changé ou sélection perdue | Abandonner l’édition obsolète, charger la nouvelle identité | Résultats asynchrones anciens ignorés ; une écriture déjà engagée reste attachée à sa cible initiale |
| Redémarrage | Base rouverte | Retrouver le choix de la même identité | Autre profil/serveur indépendant |

</frozen-after-approval>

## Code Map

- `lib/data/storage/database.dart`, `migrations.dart` : SQLite versionné, registre en ajout seul ; aucune préférence de fond existante.
- `lib/data/connection_repository.dart:160`, `lib/models/connection.dart` : origine validée et clé réutilisée ; ne pas refondre cette identité.
- `contracts/methods.json`, `fixtures/profiles.json`, `lib/models/profile.dart` : profils en lecture, aucun contrat de personnalisation.
- `lib/features/profiles/profiles_view_model.dart`, `profiles_view.dart` : snapshot, sélection vérifiée et panneau indexé par identité ; ajouter origine à cette identité.
- `lib/ui/components/profile_companion_panel.dart` : nom, fond et pause existants ; réutiliser `rabbit_companion.dart` sans modifier son dessin.
- `lib/app/bootstrap.dart`, `routes.dart`, `lib/main.dart` : injecter le stockage via une interface de models ; features sans import data.
- `lib/ui/gallery.dart`, `content.dart`, `tokens.dart` : variantes existantes, textes et styles centralisés.
- Specs lots 1/2 et dossier UX du 22 octobre : continuité ; planche v5 inspectée, prioritaire.

## Tasks & Acceptance

**Exécution :**
- [x] `lib/models/companion_background.dart`, `lib/data/storage/companion_background_store.dart`, `migrations.dart` — contrat typé et stockage atomique isolé.
- [x] `bootstrap.dart`, `routes.dart`, `main.dart` sous leurs chemins ci-dessus — injection et cycle de vie compatibles avec les appelants/tests existants.
- [x] `profiles_view_model.dart`, `profiles_view.dart` — chargement, sauvegarde, protection contre résultats obsolètes et changement d’identité.
- [x] `lib/ui/components/companion_background_editor.dart`, `companion_backdrop.dart`, `profile_companion_panel.dart`, `tokens.dart`, `content.dart` — éditeur partagé, trois palettes, voile fixe, état sélectionné, erreur et commandes accessibles.
- [x] `lib/ui/gallery.dart` — ajouter l’éditeur dans les variantes existantes avec succès/échec réessayable simulés, sans stockage de production.
- [x] `test/companion_background_store_test.dart`, `test/companion_background_editor_test.dart`, `test/profiles_test.dart`, `test/gallery_test.dart` — couvrir toute la matrice, retours et courses asynchrones ; rouvrir une base fichier réelle pour le redémarrage, tester la migration depuis la version précédente.

**Critères :**
- Étant donné deux profils et deux serveurs avec la même clé de connexion, quand chacun applique une palette, alors leurs choix restent indépendants après réouverture de la base.
- Étant donné clair/sombre, portrait 375 px, paysage et texte 200 %, quand on parcourt les commandes au clavier et via sémantique, alors elles restent atteignables, nommées et sans débordement ; la sélection ne dépend pas uniquement de la couleur.
- Étant donné le compagnon des lots précédents, quand on utilise l’éditeur avec mouvement réduit, alors anatomie, netteté, interactions et suspension sont préservées.

## Implementation Notes

Préparation : aucun arbitrage utilisateur restant ; aucune opération irréversible exécutée. Empreinte : stockage, injection, profils, éditeur et galerie ; migration additive sans suppression. Branche historique cohérente avec les deux derniers commits compagnon, arbre initial propre.

Implémentation : migration SQLite v8 additive, interface injectée de bootstrap à MainApp et ProfilesViewModel, éditeur partagé avec la galerie. Identité complète et génération protègent les retours asynchrones ; aucun modèle Hermes modifié. Anatomie et code RabbitCompanion inchangés. Preuves dans `lot3-verification/` et `lot3-visuals/` ; captures des trois palettes inspectées en clair/sombre et à 200 %. TalkBack et appareil réel non vérifiés.

## Spec Change Log


## Review Triage Log

| Constat | Verdict | Preuve et traitement |
| --- | --- | --- |
| B1 — écriture A→B→A | medium, patch | La réussite compare seulement l’identité ; une génération de sélection capturée empêchera la notification de l’ancienne édition après un aller-retour. Tester cette course. |
| B2 — pause partagée | false | La pause existante appartient à la surface du panneau et reste conservée après retour ; l’éditeur possède sa propre commande. Aucun réglage global partagé n’existe dans les lots précédents et le mouvement réduit système reste prioritaire. |
| B3 — ouverture réentrante | medium, patch | `_editBackground` n’a pas de garde avant push ; deux appels synchrones empilent deux routes. Une garde privée pendant la durée de la route suffit. |
| B4 — lecture sans indication | low, patch | Action désactivée sans expliquer la lecture en cours ; ajouter une indication annoncée pendant backgroundLoading. |
| B5 — parcours clavier incomplet | medium, patch | Le test vérifie seulement qu’un focus existe après Tab. Ajouter activation et parcours des commandes réelles. |
| B6 — application nominale non testée | medium, patch | Les écritures des tests profils se terminent après changement d’identité ; ajouter le parcours courant avec panneau mis à jour uniquement après confirmation. |
| B7 — fermeture non testée | medium, patch | Aucun test ne retire MainApp pendant une écriture ; couvrir succès et échec avant fermeture du gateway. |
| B8 — capture dépendante de Windows | low, rejeté | Harness manuel de cette session Windows, dépendances explicitement documentées ; portabilité multi-environnement non requise, correction nécessitant configuration ou nouvel asset de police. |
| B9 — défaut visuel non capturé | low, patch | Les captures ne montrent pas Lavande/pêche avec le nouveau voile ; ajouter une preuve des trois palettes, défaut compris. |
| E1 — pop après retrait | medium, patch | removeRoute précède le démontage du sous-arbre ; mounted seul ne prouve pas que l’éditeur est courant. Vérifier aussi la route courante avant pop et tester la fenêtre de course. |
| E2 — double ouverture | medium, patch | Même cause que B3 ; garder un seul éditeur actif et couvrir l’activation répétée. |
| V1 — sauvegarde via production | medium, patch | Lacune pré-vérifiée : supprimer palette=value ne fait échouer aucun test courant. Ajouter le parcours MainApp avec stockage injecté. Groupe B6/V1. |
| V2 — attente avant fermeture | medium, patch | Lacune pré-vérifiée : l’attente backgroundWrites peut être retirée sans échec actuel. Ajouter test MainApp pour écriture réussie et rejetée. Groupe B7/V2. |
| P1 — mouvement réduit figé en galerie | medium, patch | La MediaQuery capturée avant push conservait l’ancienne valeur système ; reconstruire depuis celle de la route tout en respectant la variante forcée. Régression système pendant édition ajoutée. |

Résolution : corrections B1/B3/B4/E1/P1 appliquées ; tests B5/B6/B7/B9/V1/V2 ajoutés. Les 27 tests ciblés puis la suite complète de 250 tests passent. Analyse finale propre après correction d’accolades ; aucun défaut fonctionnel retenu ne reste ouvert.

## Verification

- SDK `.fvmrc`, via `rtk proxy` : `flutter analyze`, `flutter test` ; analyse et suite complète réussies.
- Construire les APK debug application et galerie ; inspecter captures clair/sombre/200 %, focus et comparaison v5.
- Consigner séparément les limites de vérification TalkBack/appareil réel si aucun appareil disponible.
