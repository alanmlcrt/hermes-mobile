# Design évolutif — contrainte pour l’architecture et le développement

Décision d’Alanc du 20 octobre 2026 : la base visuelle actuelle convient pour un premier MVP. Le développement doit permettre des ajustements fréquents et une refonte ultérieure du design.

## Références acceptées pour le MVP

- [Catalogue et conversation](mockups/simple-conversation.html).
- [Échange animé complet](mockups/exchange-conversation.html).

Acceptation de la direction visuelle, pas de nouvelles capacités serveur. Les données et les appels des scènes restent fictifs. Les tokens et surfaces encore ouverts dans les deux spines restent à préciser pour l’implémentation.

## Règles à reprendre dans l’architecture

| Point | Contrat d’implémentation |
| --- | --- |
| Styles centralisés | Couleurs par rôle, typographie, espacements, rayons, élévations, tailles des icônes et paramètres de mouvement ont une source commune. Les composants consomment ces valeurs ; pas de valeurs visuelles dispersées dans chaque écran. |
| Thème séparé | Clair/sombre et palette Android alimentent les mêmes rôles de couleur. Les choix de style ne changent ni les données ni les actions d’Hermes. Les valeurs de secours appartiennent au thème. |
| Composants réutilisables | Choix du profil, message de conversation, saisie, pièce jointe et suivi d’activité ont des composants identifiés. Chaque composant possède sa présentation et reçoit ses données et actions par une interface explicite. |
| État indépendant du rendu | Connexion, historique, envoi, état réel des outils, arrêt et résultats sont gérés hors des composants purement visuels. Remplacer la présentation ne doit pas modifier le protocole ou relancer une action. |
| Illustrations interchangeables | Un catalogue associe les activités reconnues à un rendu, à des paramètres de mouvement et à une variante immobile. Une icône ou animation peut être remplacée sans modifier le traitement de l’événement d’outil. Prévoir le cas inconnu. |
| Événements réels | Une animation illustre l’état fourni par Hermes. Sa fin de boucle, sa durée ou son remplacement ne décident jamais qu’un outil a terminé. Les minutages de la scène de démonstration ne sont pas une logique de production. |
| Contenu indépendant | Libellés et messages d’interface sont séparés des dessins et des styles. Une nouvelle apparence conserve les noms, les rôles accessibles et les actions utiles. |
| Accessibilité conservée | Une refonte doit préserver texte agrandi, lecteur d’écran, cibles tactiles et réduction des mouvements, dans les deux thèmes. |
| Référence de comparaison | Conserver une petite galerie des composants et états représentatifs, avec données fictives, pour comparer les changements de thème ou de composants avant de les généraliser. La forme et l’outillage seront choisis avec la stack. |

## Critères de vérification à l’implémentation

1. Modifier une couleur de rôle ou un espacement commun à un seul endroit se répercute sur les composants concernés.
2. Remplacer l’indicateur d’une activité se fait dans son catalogue de présentation, sans modifier le décodage des événements ni les appels à Hermes.
3. Changer la composition du fil conserve conversations, brouillons, fichiers et état du travail ; aucun appel n’est rejoué à cause d’un nouveau rendu.
4. Les mêmes états représentatifs peuvent être examinés en clair, sombre, texte agrandi et mouvement réduit après une modification visuelle.

Ces règles n’imposent pas de framework, de moteur de skins, de système de plugins ni de sélection de thèmes supplémentaire dans le MVP. La séparation doit rester simple et adaptée à la stack choisie. Une refonte de mise en page demandera du travail de présentation ; elle doit pouvoir conserver la communication et le fonctionnement déjà fiables.
