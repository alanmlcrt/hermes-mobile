# Références UX — recherche du 20 octobre 2026

## Mandat utilisateur

Interface simple à comprendre, sans éléments trop techniques. Références confirmées : Muse et Grok Bot. Les observations ci-dessous ne sont pas des décisions de conception validées.

## Grok Bot

Source officielle consultée : https://x.ai/bot

- Présente la délégation de travail par message à un coéquipier.
- Décrit un retour vers la personne lorsqu’une approbation est nécessaire.
- Montre un exemple de connexion à un service et un état de travail compréhensible.
- Présente plusieurs bots et leurs rôles ; cette organisation appartient au produit de référence et ne constitue pas une exigence pour Hermes.

## Muse

Sources officielles consultées via index de recherche :
- https://ai.meta.com/muse/?trk=public_profile__posts-text
- https://ai.meta.com/muse/download/
- https://ai.meta.com/muse/productivity/

- Présente une interaction familière par conversation : exprimer ce que l’on veut accomplir.
- Décrit la continuité d’une demande entre appareils.
- Présente un travail en arrière-plan et des possibilités d’approbation et de reprise de contrôle.

## Interprétation à discuter

Le point commun pertinent pour la simplicité demandée est une délégation formulée en langage courant, avec un suivi lisible et un contrôle compréhensible. Ne pas transférer leurs fonctionnalités dans le périmètre Hermes sans support du PRD.

## Limites

Analyse du contenu public, pas audit des applications connectées. Aucun écran de produit inspecté visuellement : agent-browser indisponible sur PATH et inventaire CUA sans navigateur. Les couleurs, polices, espacements et structures exactes ne sont donc pas établis. Ne pas les déduire des textes promotionnels.

## Couleurs du téléphone Android — choix ultérieur confirmé

Alanc demande une apparence sobre, sans couleur de marque particulière, et un thème reprenant les couleurs de son téléphone Android, en plus du mode clair/sombre automatique. Il cite le comportement de son application Grok ; ce comportement Grok est une observation utilisateur, non vérifiée ici.

La documentation Android décrit ce mécanisme comme Dynamic Color, disponible depuis Android 12 : la palette provient du fond écran ou de la couleur choisie dans le sélecteur système. Cette correspondance technique ne prescrit pas une pile de développement ou la totalité des composants Material.

Source officielle : https://developer.android.com/develop/ui/views/theming/dynamic-colors
