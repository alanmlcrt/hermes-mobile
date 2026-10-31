# Essais téléphone — Epic 8 (8.1 à 8.7)

Prérequis : activer Bot Mode sur deux profils de test selon [README](README.md).
Renvoyer **OK** ou le point concerné et ce qui s'est affiché. Les notifications
app fermée dépendent encore d'un relais Hermes non qualifié.

1. **Salons / création** : ouvrir Salons, puis Nouveau salon. Les profils éligibles
   sont distingués ; nom vide ou un seul membre empêche de créer. Avec un nom et
   deux membres, le salon s'ouvre après confirmation.
2. **Messages** : taper `@`, choisir un membre, essayer aussi `@all`, `@hermes` et
   un message sans mention. Les réponses portent le bon nom ; Markdown et activité
   sont lisibles. Grossir le texte à 200 % : tous les contrôles restent accessibles.
3. **Brouillon / absence** : écrire sans envoyer, quitter puis rouvrir l'app.
   Le brouillon reste. Lancer ensuite un travail, quitter et revenir : les réponses
   produites entre-temps apparaissent une seule fois, dans l'ordre.
4. **Coupure** : couper le réseau pendant un envoi. Sans confirmation, l'app dit
   « à vérifier » ; rouvrir l'app ne renvoie rien automatiquement. Rétablir le réseau
   et actualiser ; relever tout envoi qui reste à vérifier.
5. **Arrêt / échec** : arrêter un salon occupé. « Arrêt demandé » précède
   « Arrêt confirmé ». Une coupure ne confirme pas l'arrêt. Si une tâche échoue,
   sa raison est attribuée à l'agent ; un résultat inconnu n'offre pas Réessayer.
6. **Appel @user** : faire appeler `@user` par un agent. Le salon porte « A besoin
   de toi » ; l'ouvrir montre le message et retire le badge. Refaire app quittée :
   relever si une notification générique arrive, sans contenu, et ouvre ce salon.
   Plusieurs appels du même salon doivent se regrouper.
7. **Autorisation** : provoquer une vraie demande dans un salon. Vérifier l'agent
   et la commande affichés ; essayer Autoriser une fois, puis Refuser sur une autre
   demande. Après arrêt ou nouveau tour, une ancienne demande doit être bloquée.
8. **Isolation** : changer de profil/connexion puis revenir ; salons, brouillons,
   badges et décisions ne doivent jamais apparaître dans une autre cible.
