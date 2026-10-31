# Interface des salons — release 32

Retour Alan : création/envoi fonctionnels en release 31 ; aide permanente gênante,
mentions agent1/agent2 et champ de saisie trop haut.

Corrigé : composer existant en disposition compacte, ancré au bas de la zone
visible ; quatre lignes maximum en portrait, deux dans une petite fenêtre.
Suggestions horizontales limitées à la mention au curseur, libellées avec les
noms des agents. Aide accessible par le bouton @ de l'en-tête. Anciens salons
compatibles sans modification serveur : destinataire exact converti à l'envoi,
charge utile persistée avant la trame, journal brut conservé.

`test/room_interface_test.dart` couvre le ciblage ancien/nouveau, la persistance
avant transmission, les URL/code/e-mails préservés, le remplacement au curseur,
le placement en bas, l'aide à la demande et le texte 200 % avec clavier simulé.
`flutter analyze` sans alerte ; suite complète : 732 réussis, 17 ignorés.

Captures du vrai rendu Flutter, données de test synthétiques, police Inter,
clavier simulé par l'inset ; ce ne sont pas des captures du téléphone :

- [Portrait, saisie vide](compact.png)
- [Suggestions et clavier](mentions-clavier.png)
- [Portrait, texte 200 %](texte-200-clavier.png)
- [Paysage, texte 200 %](paysage-200-clavier.png)

Captures inspectées visuellement. Le ressenti sur le téléphone reste à confirmer.
