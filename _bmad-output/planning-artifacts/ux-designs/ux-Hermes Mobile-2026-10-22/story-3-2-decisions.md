# Story 3.2 — décisions approuvées

Le 22 octobre 2026, après explication de la spec, Alanc a approuvé les
recommandations : « fait tout ce que tu recommandes ».

La ligne entière devient une commande native de 48 px minimum lorsqu’un détail
est reçu, avec chevron et état annoncé. Le corps affiche directement le texte/JSON
sélectionnable ; les textes de secours ne servent qu’en l’absence de donnée
structurée. Aucun second dépliage d’aperçu, aucun RPC au dépliage.

Le choix individuel reste dans la page, indépendamment du repli du groupe. Les
groupes consultés restent ouverts au premier fragment, selon la validation
complémentaire « je valide ». Leur repli manuel reste prioritaire ; les groupes
jamais consultés gardent leur repli automatique. Les
sections absentes sont omises ; seule une chaîne result.error non vide est une
section Erreur. Ce détail ne modifie jamais WorkStateLabel. Les données longues
défilent, sans coupe locale silencieuse ni promesse de sortie serveur complète.

La mise en œuvre conserve la projection, les groupes, les identités et les lots
Otc de 3.1. Preuves synthétiques : story-3-2-verification ; téléphone physique,
lecteur d’écran réel et disponibilité de l’installation ne sont pas validés.
