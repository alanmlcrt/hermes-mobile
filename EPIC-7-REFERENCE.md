## Epic 7 : Ranger et retrouver mes conversations

Alanc épingle, renomme, marque non lu, masque ou supprime une conversation et retrouve un fil par titre ou contenu. Pose la liste que les salons réutiliseront. Post-MVP, après l'Epic 6.

### Story 7.1 : Vérifier le rangement et la recherche sur mon installation

En tant qu'Alanc,
Je veux savoir ce que mon Hermes permet pour renommer, masquer, archiver, supprimer et rechercher des conversations,
Afin que l'app range côté serveur ce qui peut l'être et localement le reste, sans rien inventer.

**Critères d'acceptation :**

**Étant donné** les méthodes repérées dans le source (`session.title`, `session.set_hidden`, `session.archive`, `session.delete`)
**Quand** elles sont essayées sur un profil de test de l'installation réelle
**Alors** `contracts/` consigne pour chacune paramètres, réponses, erreurs et fixtures anonymisées, avec la capacité détectée (NFR7)
**Et** l'effet de chacune sur `session.list` et sur l'historique vu depuis un autre client (dashboard, Desktop) est documenté

**Étant donné** qu'aucune recherche serveur n'est repérée
**Quand** l'installation est inspectée
**Alors** la présence ou l'absence d'une recherche exposée est consignée, et le repli local est retenu en cas d'absence

**Étant donné** ces constats
**Quand** Alanc les relit
**Alors** il est décidé et consigné ce qui est partagé avec Hermes (titre, masquage, suppression) et ce qui reste propre au téléphone (épingle, non lu)
**Et** une méthode absente désactive la fonction correspondante avec un message clair (NFR4), jamais contournée

### Story 7.2 : Renommer une conversation

En tant qu'Alanc,
Je veux donner un titre parlant à une conversation,
Afin de la reconnaître d'un coup d'œil dans mon historique.

**Critères d'acceptation :**

**Étant donné** une conversation de l'historique d'un profil
**Quand** Alanc choisit « Renommer » dans son menu, saisit un titre et valide
**Alors** le titre est envoyé à Hermes par la méthode vérifiée en 7.1 et affiché seulement après confirmation du serveur
**Et** un titre vide ou identique n'envoie rien

**Étant donné** un échec réseau ou un refus du serveur
**Quand** le renommage échoue
**Alors** l'ancien titre reste affiché, l'erreur est expliquée et la saisie est conservée pour réessayer (NFR2)

**Étant donné** une conversation renommée depuis un autre client
**Quand** Alanc actualise l'historique
**Alors** le nouveau titre apparaît

### Story 7.3 : Épingler et marquer non lu

En tant qu'Alanc,
Je veux garder mes conversations importantes en haut et repérer celles où Hermes a répondu sans que je l'aie lu,
Afin de ne rien laisser passer.

**Critères d'acceptation :**

**Étant donné** l'historique d'un profil
**Quand** Alanc épingle ou désépingle une conversation
**Alors** les conversations épinglées apparaissent en tête, dans l'ordre d'épinglage, avec un repère non exprimé par la seule couleur (NFR1)
**Et** l'épingle est enregistrée sur le téléphone par connexion, profil et session, et survit au redémarrage de l'app

**Étant donné** un tour terminé (réussite, erreur, arrêt confirmé) dans une conversation qu'Alanc n'a pas ouverte depuis
**Quand** il revient à l'historique
**Alors** la conversation est marquée non lue
**Et** l'ouvrir la marque lue ; « Marquer non lu » dans son menu la remet non lue

**Étant donné** une conversation supprimée ou disparue côté Hermes
**Quand** l'historique est actualisé
**Alors** son épingle et son marqueur locaux sont retirés

**Étant donné** le lecteur d'écran actif
**Quand** il parcourt une conversation épinglée ou non lue
**Alors** ces états sont annoncés

### Story 7.4 : Masquer et retrouver des conversations

En tant qu'Alanc,
Je veux sortir de ma liste les conversations dont je n'ai plus besoin sans les détruire,
Afin de garder un historique lisible.

**Critères d'acceptation :**

**Étant donné** une conversation de l'historique
**Quand** Alanc choisit « Masquer »
**Alors** elle est masquée par la méthode retenue en 7.1 (masquage ou archivage) et disparaît de la liste principale
**Et** un message éphémère propose « Annuler », qui la rétablit

**Étant donné** des conversations masquées
**Quand** Alanc ouvre la section « Masquées » de l'historique
**Alors** il les retrouve, peut les ouvrir et les rétablir

**Étant donné** un échec du serveur
**Quand** le masquage échoue
**Alors** la conversation reste visible et l'erreur est expliquée

### Story 7.5 : Supprimer une conversation

En tant qu'Alanc,
Je veux supprimer définitivement une conversation,
Afin de faire le ménage dans mon Hermes depuis le téléphone.

**Critères d'acceptation :**

**Étant donné** une conversation sans travail en cours
**Quand** Alanc choisit « Supprimer »
**Alors** une confirmation explicite indique que la suppression est définitive et touche aussi Hermes
**Et** après confirmation, `session.delete` est appelé et la conversation n'est retirée de la liste qu'après réponse positive du serveur

**Étant donné** une conversation avec un travail en cours ou un envoi non résolu
**Quand** Alanc veut la supprimer
**Alors** la suppression est refusée avec explication (arrêter d'abord)

**Étant donné** une suppression confirmée par le serveur
**Quand** elle aboutit
**Alors** brouillon, pièces jointes locales, épingle et marqueur de cette conversation sont effacés du téléphone
**Et** une notification de fin reçue ensuite pour cette session ouvre l'accueil avec un message « conversation supprimée », sans erreur

**Étant donné** un échec réseau pendant la suppression
**Quand** le résultat est incertain
**Alors** la conversation reste affichée, marquée à vérifier, et l'historique actualisé tranche ; rien n'est supprimé localement avant confirmation (NFR2)

### Story 7.6 : Rechercher une conversation

En tant qu'Alanc,
Je veux retrouver une conversation en tapant quelques mots,
Afin de ne pas faire défiler tout mon historique.

**Critères d'acceptation :**

**Étant donné** l'historique d'un profil
**Quand** Alanc saisit un texte dans la recherche
**Alors** les conversations dont le titre ou l'aperçu contient ce texte (sans tenir compte de la casse ni des accents) sont listées, avec le passage trouvé mis en évidence
**Et** la recherche porte aussi sur le contenu des conversations déjà présentes sur le téléphone

**Étant donné** une recherche exposée par Hermes (constat de 7.1)
**Quand** elle est disponible
**Alors** elle est utilisée et ses résultats sont fusionnés sans doublon ; sinon l'app indique que la recherche porte sur les titres et le contenu déjà chargé

**Étant donné** une recherche sans résultat
**Quand** la liste est vide
**Alors** un état vide le dit, distinct d'une erreur de chargement

**Étant donné** l'option « Tous les profils »
**Quand** Alanc l'active
**Alors** les résultats de chaque profil sont regroupés et identifiés par leur profil, sans mélanger les conversations (FR3)


