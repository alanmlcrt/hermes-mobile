# Réconciliation des sources initiales — 2026-10-20

Sources comparées : `../../briefs/brief-Hermes-Mobile-2026-10-20/brief.md`, son `addendum.md` et sa `.memlog.md`, contre le PRD, son addendum et son journal actuels. Les décisions utilisateur ultérieures priment sur le brief encore en brouillon.

| Idée de la source | Destination et traitement |
| --- | --- |
| Client personnel d'une installation Hermes existante, Android prioritaire et iPhone anticipé | PRD, but, NFR-1 et limites ; sans engagement de livraison simultanée. |
| Réduire les frictions Discord : longs textes, commandes slash, emojis, code et exécutions CLI | PRD, contexte et FR-4/FR-7/FR-12 ; actions accessibles dans la conversation. |
| Profils existants identifiables, plusieurs conversations séparées, nouveau fil avec profil par défaut à l'ouverture | PRD, FR-2/FR-3/FR-10. Conservation du fil au retour temporaire et absence de fils vides restent des hypothèses explicites. |
| Configuration des profils initialement demandée au MVP | Remplacée par la décision ultérieure : aucun écran de consultation ou d'administration au MVP ; configuration par conversation avec le profil par défaut selon les capacités de Hermes. Consultation outils/MCP/skills après MVP ; FR-11 réservé. L'addendum signale explicitement que le brief est dépassé sur ce point. |
| Images et pièces jointes pour des usages variés | PRD, FR-5/FR-6 ; usages non restreints. Formats, tailles et transport effectifs restent à vérifier sans prétendre accepter tous les fichiers. |
| Présentation soignée, suivi synthétique avec détails dépliables ; références Grok Bot, Orca et Muse | PRD, positionnement, FR-7 et expérience. La simplicité de messagerie et la lisibilité sont préservées. Grok est identifié ; Orca concerne l'association ; Muse est facultatif et non identifié. Aucun thème visuel n'est inventé. |
| Exécution serveur après fermeture, notification de fin, reprise après coupure | PRD, FR-8/FR-9 et NFR-2 ; distinction entre continuité serveur et livraison Android conservée dans l'addendum. |
| Tailscale et association inspirée d'Orca : QR/lien, mémorisation, saisie manuelle, erreurs réseau/authentification | PRD, FR-1/NFR-3 ; mécanisme proposé, compatibilité non acquise. L'addendum sépare accès au tailnet et authentification Hermes. |
| Bot Mode, backend Desktop, API, profils/gateway et limites des sessions | Addendum, intégration et références Hermes ; protocole non figé. FR-2/FR-3 préservent les conversations distinctes sans assimiler le chat canonique et ses commandes à ce besoin. |
| Commandes, événements et résultats dépendant du backend ; absence de preuve sur le serveur installé | PRD, FR-7 et NFR-4 ; addendum technique. Les détails affichés sont ceux réellement exposés par Hermes. |
| Vocabulaire proposé « assistants » ; distinction profil, agent, bot et conversation | PRD, vocabulaire : « profil », « agent » et « conversation » retenus pour la précision. Le libellé d'interface « assistants » reste un choix UX, sans création d'un nouveau concept produit. |
| Réussite par un usage réel à distance et séparation des historiques | PRD, réussite et contre-mesure ; tailles et fichiers de référence restent à fixer avant les essais. |
| Voix, routines, groupes, import Discord, multi-utilisateur et diffusion | Hors MVP à titre de proposition explicitement signalée ; usage personnel confirmé. Aucune parité fonctionnelle avec Grok n'est promise. |
| Extension progressive après validation du parcours personnel | PRD, après MVP ; consultation des profils désormais précisée par les derniers échanges. |
| Installation locale de `ui-ux-pro-max` | Addendum, design et outillage ; détail de méthode, sans l'ajouter aux exigences produit. |

## Résultat

Aucune lacune substantielle constatée par rapport aux sources initiales. Le besoin qualitatif de belle interface reste explicite et est transmis au travail UX ; une palette ou une disposition non choisie ne constitue pas une perte d'information.

Les hypothèses d'expérience, exclusions proposées et inconnues techniques du PRD doivent être triées lors de sa finalisation. Elles ne sont pas des décisions récupérables dans le brief : ne pas les valider artificiellement par la seule réconciliation.
