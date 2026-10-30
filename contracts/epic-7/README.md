# Investigation 7.1 : rangement et recherche

Statut : **installation non vérifiée, story non validée**. Cette livraison prépare
des essais reproductibles. Aucun échange Hermes authentifié ni effet interclient
n'a été observé. Les tests synthétiques prouvent uniquement les protections de
la sonde ; ils ne constituent pas des preuves du contrat installé.

## Provenance et dépendances

`methods.json` contient les candidats extraits de la copie documentaire OpenRPC
dans `architecture-Hermes Mobile-2026-10-20/.working/`, révision amont déclarée
`5eee5d02e85eaad32dfade3030d27fcfad204e72`. Cette révision ne désigne pas le build
installé. `capabilities.json` distingue les constats non vérifiés des candidats.
Les scripts Python copiés dans ce dossier d'architecture documentent `/api/ws`
avec `?token=` ou `?ticket=`, et GET `/api/profiles`. Aucun endpoint de login ou
de création de ticket n'est supposé. `gateway.capabilities` n'est pas un
inventaire des méthodes ; son seul champ documentaire ne prouve aucun rangement.

Le titre, le masquage, l'archivage et la suppression sont des opérations partagées
sur Hermes. Épingle et non-lu restent locaux, avec une identité
connexion/profil/session. L'intégration attend les repositories de l'epic 6.
Cette investigation ne modifie ni l'autre checkout ni les briefs, l'application,
le profil global ou les bases privées.

## Préparer un corpus dédié

Depuis un client Hermes autorisé, préparer un profil de test et des conversations
jetables avec titres et messages synthétiques distincts. Relever séparément les
IDs runtime, stockés, clés et racines de lignée. Ne jamais utiliser un titre
comme autorisation d'ID. Pour masquage/archivage, la déclaration autorise **toute
la lignée du target**, après vérification manuelle qu'elle appartient au corpus.
La sonde ne peut pas certifier cette propriété à partir du schéma documentaire.

Relever par une surface officielle le build exact et sa provenance (release,
commit, mode de lancement), puis enregistrer uniquement ces métadonnées publiques
dans `verification.md` et les manifestes après revue. La sonde laisse le build
non vérifié ; aucun numéro provenant d'une réponse arbitraire n'est publié brut.

## Exécuter

Après `rtk proxy fvm flutter pub get`, utiliser Dart du SDK épinglé (Flutter
3.47.7/Dart 3.13.5). Si FVM manque au PATH, le SDK local se trouve dans
`C:/Users/alanc/fvm/versions/3.47.7/bin`. Aucune dépendance supplémentaire.

Fournir les variables d'environnement dans le terminal de travail, sans les
copier dans des fichiers, journaux, commandes partagées ou sorties :

| Variable | Contenu |
| --- | --- |
| `HERMES_ORIGIN` | Origine HTTP(S), sans chemin, requête, fragment ou credentials |
| `HERMES_PROFILE` | Nom exact du profil dédié ; aucun changement de profil global |
| `HERMES_SESSIONS` | IDs dédiés, séparés par virgules, sensibles à la casse |
| `HERMES_TOKEN` | Token existant, Bearer REST et `?token=` WebSocket |
| `HERMES_TICKET` | Ticket existant optionnel ; prioritaire pour WebSocket ; REST peut nécessiter aussi le token |
| `HERMES_CAPTURE` | Nouveau fichier JSON local dans un dossier existant |

Un ticket seul ne suffit pas nécessairement à authentifier REST. Un refus
d'authentification est enregistré et arrête le protocole. La sonde ne crée pas
de ticket et ne renouvelle pas un ticket consommé. Les redirections REST et
WebSocket sont refusées. Aucun rejet ne doit être contourné par une route inventée.

Lecture par défaut :

```powershell
rtk proxy fvm dart run tool/sonde_rangement.dart
```

Séquence : profils, connexion, capacités, listes sans/avec masquées, titre et
historique de chaque ID déclaré. Les listes sont bornées à 100 : une absence
dans ces fenêtres ne prouve pas une disparition globale. Le délai de chaque
étape est de 10 secondes et les réponses sont bornées à 1 Mio. Les sockets sont
fermées à la fin, y compris après erreur.

Avant une mutation, les deux listes et les historiques doivent répondre sans
erreur ; un refus ou un résultat malformé bloque l'envoi. La lecture du titre
runtime est optionnelle : son refus ne bloque pas une suppression par ID stocké.
En lecture seule, les refus RPC restent enregistrés et les autres lectures
continuent. Un résultat RPC nul ou scalaire est un protocole invalide.

Pour **une seule mutation**, ajouter :

| Variable | Autorisation/valeur |
| --- | --- |
| `HERMES_AUTHORIZE_PROFILE` | Exactement le profil dédié |
| `HERMES_AUTHORIZE_SESSIONS` | IDs que cette exécution est autorisée à modifier |
| `HERMES_TARGET_SESSION` | Un ID inclus dans les deux ensembles déclarés |
| `HERMES_AUTHORIZE_LINEAGES` | Targets dont la lignée entière est dédiée et autorisée ; requis pour hidden/archive |
| `HERMES_NEW_TITLE` | Titre synthétique non vide, pour title |
| `HERMES_VALUE` | `true` ou `false` explicite, pour hidden/archive |

Choisir exactement un appel par lancement :

```powershell
rtk proxy fvm dart run tool/sonde_rangement.dart session.title
rtk proxy fvm dart run tool/sonde_rangement.dart session.set_hidden
rtk proxy fvm dart run tool/sonde_rangement.dart session.archive
rtk proxy fvm dart run tool/sonde_rangement.dart session.delete
```

Ces lignes sont des alternatives, pas un script à lancer en bloc. Le titre vise
un ID runtime ; delete vise un ID stocké. Les autres peuvent résoudre un ID
runtime/stocké/clé/titre selon le candidat documentaire : employer exclusivement
un ID dédié confirmé, sans ambiguïté. Archive utilise l'alternative `session_id`
et envoie toujours le booléen ; aucune omission du target ou valeur implicite.
La sonde compare des snapshots avant/après mais ne restaure rien automatiquement.
Une restauration est une nouvelle mutation autorisée après constat du résultat.

En cas de timeout, coupure ou réponse malformée après l'envoi, **résultat incertain,
aucun rejeu**. Arrêter les mutations et rapprocher listes/historique et autre
client par des lectures avant toute décision manuelle. Aucun retry, reconnect,
fallback de mutation ni nettoyage local n'est effectué. Les erreurs -32601
signifient méthode explicitement absente ; -32602 signifie paramètres refusés,
pas absence. Les autres erreurs RPC restent non interprétées.
Les fermetures WebSocket 4401/4403 sont classées respectivement refus
d'authentification/d'accès, sans publier leur motif brut. Une réponse ou un refus
de mutation reçu reste conclusif même si le contrôle après échoue : le rapport
indique alors `postcheck_failed` et `response_received`, sans transformer cette
réponse en résultat incertain.

## Captures et bilan

Le fichier n'est créé qu'à partir d'une projection autorisée. IDs/profils sont
pseudonymisés et textes remplacés par des marqueurs stables **dans une capture**
(égalité préservée, contenu perdu). Champs inconnus, messages d'erreur, données
d'erreur, tokens, URLs et notifications ne sortent pas de la sonde. Les alias
changent d'une exécution à l'autre. Les réponses en erreur ne publient qu'une
catégorie fixe et le code numérique. Les fichiers existants ne sont pas écrasés.
Dans les historiques, `text` et `row_id` conservent des alias stables ; seuls les
rôles fixes `user`, `assistant`, `system`, `tool` restent lisibles.

Un protocole incomplet conserve sa capture anonymisée, avec
`protocol_complete: false`, et termine avec un code non nul et une catégorie
d'échec fixe. Le message de succès est réservé au protocole terminé, sans jamais
valider l'installation. Le fichier est réservé avant tout appel réseau ; un
processus interrompu peut laisser une capture vide ou incomplète. La rapprocher
manuellement des lectures et de l'autre client, sans rejouer la mutation.

Relire toute capture avant de la placer dans `fixtures/`. Associer une preuve
aux observations manuelles avant/après et autre client dans `verification.md`,
puis compléter la portée par méthode et build dans `capabilities.json`. Ne jamais
classer une preuve de test comme une capture réelle, ni valider 7.1 tant que les
critères réels restent ouverts.
