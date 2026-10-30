# Lot 4 — événements et contraintes observés

Investigation du 22 octobre 2026 ; lots 1–3 terminés, arbre initial propre. Branche historique `story/2-1-nouvelle-conversation-brouillon`, contenant les trois commits compagnon successifs. Aucun appel à un serveur personnel. Planche v5 inspectée : oreilles asymétriques, silhouette entière, regard latéral, chatouilles et lisibilité compacte confirmés comme références graphiques ; la planche ne valide pas une chorégraphie de génération.

## Sources réelles

| Signal | Source | Ce qu'il permet |
| --- | --- | --- |
| Envoi local / accepté | `DraftViewModel.sendStatus`, `ConversationRepository.accepted()` | Distinguer soumission et acceptation ; la projection devient `sending`, sans prouver le démarrage. |
| Démarrage | `message.start`, `EventEffect.turnStart` | `running` via `_startTurn`. |
| Texte | `message.delta`, `message.interim` non déjà diffusé | Ajouter du contenu, sans progression mesurable. `_ensureTurn` peut établir `running` si le démarrage manque : `running` ne prouve donc pas à lui seul la réception de `message.start`. |
| Activité | `tool.start`, `tool.complete`, type inconnu | Ligne d'activité ; aucune preuve de réussite du tour. |
| Terminal | `message.complete`, `error` ; `EventMapping.map`, `_finish` | `complete` → succès ; `error` ou erreur portée par le terminal → échec ; `interrupted` → arrêté ; statut absent/inconnu → inconnu. |
| Coupure | `ConversationRepository._unsynced` | Travail actif → inconnu ; texte conservé, aucun terminal inventé. |
| Reconnexion | `session.resume`, `session.events.since`, `session.history` | Restaurer l'état courant ; rejouer les données n'autorise pas à rejouer une animation. |

**Piège important :** `_fromHistory` peut produire `succeeded` lorsque la dernière ligne est une réponse assistant. `TimelineProjection` expose état, tours, contenu et curseur, mais aucune provenance « terminal reçu en direct ». Une réaction dédiée à la réussite exige donc un signal de présentation fiable, non persistant, distinguant événement direct et restauration. L'option sans réaction de réussite n'en a pas besoin. Ne pas modifier la signification métier de `WorkStateLabel` pour contourner cette limite.

Le code ne propose actuellement aucune commande d'arrêt de génération. Tester l'arrêt consiste ici à recevoir le terminal `interrupted`, sans créer de bouton ni de RPC. Les chatouilles ne doivent accéder à aucune commande de génération.

## Présentation existante

- `DraftView._timeline` rend séparément les `ResponseItem`, activités et `WorkStateLabel`. Un tour peut contenir plusieurs blocs de réponse séparés par des activités : ne pas créer un lapin par fragment.
- Les trois points tournants sont validés dans DESIGN/EXPERIENCE du 20 octobre, mais aucun composant correspondant n'existe sous `lib/`. `ActivityLine` affiche actuellement icône et texte. Choisir la coexistence implique donc une implémentation nouvelle, et non la conservation d'un widget existant.
- `RabbitCompanion` possède `name`, `size`, `active`, `paused`, mais aucune pose métier. Il gère chatouilles, regards de repos toutes les six secondes, mouvement réduit, route, viewport, `TickerMode` et cycle de vie. `active:false` reste nécessaire pour une surface conservée explicitement masquée.
- Les pauses des lots précédents sont locales à chaque surface ; aucune préférence globale n'existe. Proposition : pause locale de la conversation conservée pendant la vie de la page.
- Le lot 3 stocke le fond par origine/connexion/profil. Sa réutilisation en conversation demanderait l'injection et la lecture correspondantes ; aucune autorisation d'étendre cette préférence à cette surface n'est acquise.
- Les dimensions 64/48 et les compensations optiques sont déjà dans `RabbitTokens`. Le lapin et sa cible doivent rester dans leur enveloppe, hors du texte et de ses actions.

## Proposition à arbitrer

1. Chorégraphie : envoi neutre ; démarrage confirmé → concentration calme ; réception réelle de texte → regard maintenu vers le contenu, sans pulsation par fragment ; terminal → face puis repos. Soit retour neutre pour toutes les fins (recommandé), soit regard bref vers le lecteur réservé à un succès reçu en direct, avec provenance explicite. Aucun regard de repos autonome pendant le travail. Les changements de travail mettent immédiatement à jour le statut ; après chatouilles, reprendre la pose courante, sans réaction de fin différée.
2. Trois points : lapin comme seule présence animée, remplaçant cette intention de l'ancienne UX (recommandé), ou implémentation des points près du libellé pendant `running`, avec lapin plus calme. Aucune cadence ne représente l'avancement.
3. Fond : surface neutre du thème (recommandée pour la lecture), ou palette fixe enregistrée du profil dans le seul carré du lapin. Aucun pastel derrière le texte.
4. Placement : un slot 64 px par dernier tour, présent dès l'acceptation et conservé au terminal. Marge latérale si la largeur utile atteint 360 px et l'échelle effective reste sous 150 % ; sinon bande avant le texte, même lapin 64 px. Autre choix : bande avant le texte sur tous les écrans, pour une largeur de lecture constante. Le clavier seul ne change pas le placement ; la liste défile dans l'espace disponible. Une nouvelle demande conserve la réservation des tours précédents sans dupliquer les interactions ; un historique chargé reste neutre.

## Vérification prévue, pas encore exécutée

Galerie pilotable et tests pour envoi/démarrage/texte/terminal, succès/erreur/arrêt/inconnu, coupure/reconnexion avec rejeu et snapshot, changement pendant chatouilles, nouveau tour, suspension et retour sans rattrapage. Contrôles 320/375 px, paysage, clavier ouvert, clair/sombre et texte 200 %, ainsi que focus, action sémantique et unicité des annonces d'état. Test réel TalkBack/VoiceOver distinct des assertions sémantiques Flutter ; toute indisponibilité d'appareil sera signalée.
