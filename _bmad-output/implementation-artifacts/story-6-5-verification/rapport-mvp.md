# Story 6.5 — rapport d'essai MVP

**Clôture de la story 6.5 sur décision d'Alanc, le 2026-10-30 (consignée à 16:46:50Z).** Alanc demande : « marque comme terminé, je voudrais ensuite passer au dev de l'epic 7 ». Les contrôles restants sont reportés pour permettre la poursuite. Le premier parcours et la lecture des quatre formats ont été confirmés par constat humain ; les autres contrôles, le rejeu ergonomique +24 et les corrélations serveur restent non démontrés. G3 demeure ouverte ; `realAcceptance: open` conserve le statut technique de l'acceptation réelle. La clôture demandée ne transforme aucun essai non joué en réussite.

Référence : [protocole](protocole.md), [spec](../spec-6-5-valider-mvp-essai-reel.md). Toutes les dates de ce rapport sont UTC. Les constats visuels sont à recueillir auprès d'Alanc ; aucun test automatisé ne les remplace.

## Identification et prérequis

| Élément | Relevé |
|---|---|
| Révision source | `ecbedeeac543f8cf874e1e204ddc3b1a948022ac` ; arbre initial propre hors spec 6.5 non suivie |
| Date du relevé initial | 2026-10-30T16:15:37Z |
| Téléphone | Pixel 8 Pro, ADB `device` autorisé ; identifiant omis |
| Version avant installation | `fr.hermes_mobile`, versionName 0.1.0, versionCode 22 |
| Release candidate | 0.1.0+24 installée après correctif ergonomique ; version relue à 2026-10-30T16:42:07Z ; [preuve et SHA-256](ergonomie-pieces-jointes.md). Les premiers constats M01/M02 et la notification partielle concernent +23, [preuve initiale](preuves-techniques.md). |
| Flutter | 3.47.7 stable / Dart 3.13.5 effectifs via FVM, conforme à `.fvmrc` |
| Signature / Firebase | Fichiers locaux présents ; aucun secret copié dans les preuves |
| Plugin requis | ≥ 1.0.2 ; fichiers default identiques au dépôt à 16:19:20Z, absents de mesure-pieces-jointes ; chargement et redémarrage à confirmer avec Alanc |
| Build Hermes effectif | GET /api/health à 16:19:20Z : 0.22.2+1690, SHA 9e01b44dd23978f9ff40b7837467f3a9f1582130 ; [preuve](preuves-techniques.md) |
| Profils | `default` et `mesure-pieces-jointes`, conversations dédiées à créer par les gestes |
| Pièces sur téléphone | Quatre pièces synthétiques transférées après annonce vers Download/Hermes-MVP-6-5 ; SHA-256 téléphone/source identiques, [manifeste](preuves-techniques.md) ; aucune campagne de sonde relancée |

## Contrôles techniques

Analyse Flutter sans problème, 616 tests réussis / 17 ignorés, build release +23 et vérification de signature réussis. Installation annoncée puis mise à jour ADB réussie, sans commande d'effacement. [Preuves techniques](preuves-techniques.md). Ils ne ferment aucune porte d'acceptation réelle. Aucune modification serveur exécutée.

## Matrice des nouveaux constats

| Contrôle | Essais | Statut | Date / preuve / indisponibilité |
|---|---|---|---|
| Démarrage et profils | M01 | Réussi — constat humain ; corrélation serveur à faire | Retour d'Alanc consigné le 2026-10-30 à 16:24:50Z : « c'est good » en réponse aux quatre étapes (ouverture, C1/default, C2/mesure-pieces-jointes, historiques). Aucun problème signalé ; identités et compteurs serveur non rapprochés. |
| Corpus 4.1 | M02 | Lecture réussie — constat humain ; défaut ergonomique | Alanc confirme la lecture de tous les types (texte, image, PDF, Word). Fichiers exacts, volumes et corrélation serveur à préciser ; le retour ne distingue pas corpus synthétique et fichiers personnels. Présentation après sélection jugée trop volumineuse et chargée d'informations ; correctif en cours, sélecteur natif satisfaisant. |
| Travail | M03 | Non joué | Détail et terminal d'arrêt Hermes non observés. |
| Interventions | M04, M05a/b | Non joué | Clarify et décisions autoriser/refuser à constater ; mode conservé. |
| Résultat | M06a/b | Non joué | Téléchargement, ouverture et échec réseau réessayable à constater. |
| Notification | M07 | Partiel | Alanc indique avoir reçu une notification uniquement sur default. Fermeture de l'app, toucher et bon fil non confirmés ; M07 complet reste à jouer. |
| Résilience | M08a/b | Non joué | Brouillon/pièce et compteurs de tours à rapprocher ; absence de duplication/perte non démontrée. |
| Accessibilité | M09 | Non joué | TalkBack, texte 200 % et clavier à contrôler sur les parcours essentiels. |

## Rapprochement des portes et reports

| Porte / report | Situation historique | Nouveau constat / décision |
|---|---|---|
| G1 installation | Contrat et build historique ne remplacent pas les parcours téléphone | Reste à rapprocher des M01/M03/M08 ; compatibilité globale non déclarée. |
| G2 fichiers | Campagne 4.1 mesurée côté serveur | M02 mobile non joué ; aucune clôture à partir du seul upload historique. |
| G3 notifications | [Rapport G3 du 2026-10-30](../story-5-5-verification/rapport-g3.md), ouverte | Aucun écart clos ; M07 non joué. |
| G4 produit/UX | Fermée par décisions d'Alanc du 2026-10-30, FR13/14 retenus | Décision conservée ; ne prouve pas l'exécution mobile M04–M06. |
| Profil sans plugin | Échoué : commande globale, mention absente | Absence de notification sur mesure-pieces-jointes rapportée par Alanc le 2026-10-30 (constat consigné à 16:24:50Z), cohérente avec le plugin absent. Présence ou absence de la mention « Notification non suivie » non vérifiée ; blocage historique conservé. |
| `/new` | Non jouable, message ordinaire | Décision explicite d'Alanc attendue ; aucun retrait automatique. |
| Arrêt forcé / permission refusée | Explications dans l'app non constatées | Non rejoué ; « pas grave » historique ne précise pas une dérogation 6.5. |
| Délégation asynchrone | Deux notifications pour deux vrais tours ; matrice attendait une | Aucune décision nouvelle ; report conservé. |
| Redémarrage brutal Hermes | Seul SIGTERM propre testé | Non joué ; perte annoncée non constatée. |
| Premier plan | Aucun essai explicite payload réel | Non joué. |
| Garde plugin 1.0.2 | Auto-vérification seulement ; 1.0.1 observé en réel | Fichiers default identiques au dépôt 1.0.2 ; garde non rejouée et chargement à confirmer. |

## Preuves, limites et suite

Les [relevés techniques expurgés](preuves-techniques.md) sont joints ; aucune simulation n'est comptée comme essai réel. Premier constat humain recueilli dans cette conversation et résumé dans M01/M07 ; l'heure consignée est celle du relevé de l'agent, pas celle des gestes. Aucune capture ni corrélation de tours serveur nouvelle n'est disponible à ce stade. Aucun constat d'absence de duplication ou de perte ne peut être établi sans M08. Les journaux historiques restent dans leur rapport d'origine.

Suite décidée par Alanc : commencer l'epic 7. Les contrôles non joués de la matrice et les écarts G3 sont reportés dans [deferred-work.md](../deferred-work.md), sans clôture technique. Le présent rapport conserve les limites et les preuves pour un futur rejeu ; la story 6.5 est terminée sur décision humaine.
