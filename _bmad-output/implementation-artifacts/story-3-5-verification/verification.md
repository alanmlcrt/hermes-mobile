# Vérification de la story 3.5

## Contribution

Le dépôt contenait déjà la refonte du 24 octobre, les accents persistés, les
cartes en relief, les modifications Otc et de nombreux tests adaptés. Le parent
a enregistré cet état dans
`C:/Users/alanc/AppData/Local/Temp/hermes-3-5-baseline-wvrdbc5i`
(manifest SHA256 et `existing.patch`). Le diff Git depuis HEAD n'est donc pas
le diff de cette story seule.

Cette story ajoute :

- `StopGateway`, `StopStatus` et un repère local `StopTarget`, sans identité de
  tour serveur inventée ni état local dans `TimelineProjection`.
- Une migration additive v10, après `profile_accents`, et `outbox_stops`.
  L'outbox conserve connexion, profil, session durable, runtime, génération et
  tour observé avant l'unique appel `session.interrupt`.
- Une exclusion par session et par cible, une revérification après les attentes
  SQLite, et aucune reprise de session dans le chemin d'arrêt. Une intention
  restaurée reste inconnue et bloque la répétition sur le même tour.
- Le format RPC, sa validation, la traçabilité documentaire et la capacité
  `session.interrupt` laissée `unverified`. Cette fonction ne bloque pas les
  prérequis de connexion ; son absence/refus est affiché après l'action explicite.
- Le carré d'arrêt dans le bouton de saisie, sa cible de 48 dp, son nom accessible
  unique « Arrêter », le maintien du texte et le rappel des effets déjà produits.
  `WorkStateLabel` présente l'intention séparée ; son annonce reste unique.
- Les démonstrations fictives dans la galerie, les tests de l'arrêt et
  l'actualisation des attentes de version SQLite et du nombre d'aperçus.

## Matrice des preuves

| Situation | Preuve automatisée | Résultat |
|---|---|---|
| Persistance avant RPC, contexte complet | `stop_flow_test` : ligne SQLite lue pendant RPC en attente | Un seul appel, cible complète, brouillon intact |
| Double pression/deux vues | `stop_flow_test` : deux demandes concurrentes, même brouillon de session | Un seul appel ; autre session sans intention |
| Stockage indisponible | Trigger SQLite refusant l'insertion | Aucun RPC, erreur lisible |
| Terminal pendant attente SQLite | Transaction maintenue puis événement terminal | Demande périmée, aucun RPC tardif |
| Profil modifié/coupure pendant attente | Harness réel de connexion + transaction SQLite | Demande périmée, aucun RPC |
| RPC accepté, expiré, refusé ou réponse invalide | RPC synthétiques, expiration bornée et `RpcFail(-32601)` | Aucune confirmation implicite ; erreur ou issue inconnue |
| Coupure après transmission/reconnexion | `RpcDrop`, puis nouvelle socket via harness | Un seul arrêt ; aucun renvoi |
| Redémarrage client | Fermeture et réouverture réelles SQLite, nouvel outbox | Intention inconnue, aucun appel/reprise |
| Nouveau tour | Terminal puis `message.start` | Intention ancienne invisible et sans effet sur le nouveau tour |
| Terminal interrompu/réussi | Événements `message.complete` courant | Projection `stopped`/`succeeded` ; RPC seul ne la termine pas |
| Migration additive | Ouverture d'une vraie base v9 avec accent puis migration | Accent conservé, table des arrêts ajoutée |
| Commande clavier et cible | Composer, Tab puis Entrée, mesure du bouton | 48 × 48 dp, même action que le toucher |
| Parcours réel de conversation | `DraftView` + `DraftViewModel` + repositories et transport synthétique | Demande → libellé demandé → terminal confirmé ; brouillon intact |
| Petit écran/sombre/clavier/200 % | Captures `conversation-*.png`, absence d'exception de layout | Statut, saisie, arrêt et rappel accessibles ; fil conserve 96 dp minimum |

## Captures

Les quatre PNG proviennent de la vraie `DraftView` à 320 × 740 pixels logiques :
`conversation-light.png`, `conversation-dark-requested.png`,
`conversation-dark-keyboard-200.png`, `conversation-confirmed.png`.
La capture clavier utilise un inset simulé de 260 px ; elle ne photographie pas
un clavier système. Les données et les événements sont synthétiques.

## Limites

Aucun contact avec l'installation personnelle de Hermes, aucun arrêt externe
et aucun essai physique TalkBack n'ont été réalisés. La présence dans OpenRPC
et les fixtures ne valident pas l'installation. Sans identité serveur fiable de
tour, les gardes locales et l'absence de rejeu ne suppriment pas une course
entre clients distants. Les 17 tests ignorés préexistants de la suite ne sont
pas des validations de cette story.

## Commandes et résultats

Les logs finaux sont copiés dans ce dossier après exécution : analyse Flutter,
tests ciblés, suite complète et builds APK application/galerie. Les premières
passes ont corrigé des attentes de version et de compte de galerie, ainsi
qu'un footer qui pouvait réduire le fil à zéro dans une matrice extrême.

## Clôture après revue

Les trois revues sont terminées. Corrections vérifiées : conversation sur un
profil différent de la préférence globale, frontières dupliquées, récupération
après lecture SQLite échouée, résolution portable de MaterialIcons et
stabilisation des captures de thèmes. Les trois nouveaux scénarios passent
dans `stop_flow_test.dart`. Les quatre captures finales ont été inspectées ;
le rappel est lisible en clair et sombre. Les défauts préexistants distincts
sont consignés dans `../deferred-work.md` (sept groupes).

Vérification finale exécutée par le parent sur l’état partagé après corrections :

- `final-analyze.log` : aucune anomalie, code de sortie 0.
- `final-tests.log` : **346 tests réussis, 17 ignorés, aucun échec**, code 0.
- `final-app-apk.log` : APK application construit, 26,9 s, code 0.
- `final-gallery-apk.log` : APK galerie construit, 22,0 s, code 0.

APK conservés séparément sous `build/story-3-5-app-debug.apk` et
`build/story-3-5-gallery-debug.apk`. Les 17 tests ignorés ne couvrent aucun
scénario de l’arrêt ajouté par cette story. Les limites d’intégration Hermes et
TalkBack ci-dessus restent applicables.

- Analyse finale : aucune anomalie.
- Ciblés de la matrice et migrations : 112 réussis, 9 ignorés.
- Parcours détails + arrêt après correction du footer : 19 réussis.
- Suite Flutter complète finale : **343 réussis, 17 ignorés, aucun échec**.
- APK debug application : construit ; conservé dans `build/story-3-5-app-debug.apk`.
- APK debug galerie : construit ; conservé dans `build/story-3-5-gallery-debug.apk`.

À 200 % avec clavier, le pied de page peut défiler pour préserver un fil
consultable de 96 dp. Le carré d'arrêt et le rappel sont montrés dans la capture ;
le statut reste monté dans la région live et peut être révélé en remontant ce
pied de page. Cette preuve ne vaut pas un essai de lecteur d'écran réel.

## Corrections issues de la revue

L'arrêt cible le profil de la conversation, indépendamment de la préférence
globale sélectionnée. Un changement de cette préférence invalide les cibles déjà
capturées, mais n'empêche pas de demander ensuite l'arrêt d'une autre conversation.
Les frontières déjà connues selon `seq`/`replay_epoch` sont rejetées avant
l'invalidation du repère d'arrêt. La restauration de l'outbox n'est marquée lue
qu'après une requête SQLite réussie et peut donc être réessayée après une panne.

Trois régressions dédiées couvrent ces cas dans `stop_flow_test.dart`. Les
captures sont régénérées après stabilisation complète du thème, avec assertion
de la couleur héritée finale du rappel pour chaque thème. MaterialIcons provient
des ressources du SDK qui exécute le test, sans chemin propre à un utilisateur.
La vérification de cette correction se limite aux tests arrêt, conversation,
outbox et resynchronisation ; la vérification globale finale appartient au parent.
