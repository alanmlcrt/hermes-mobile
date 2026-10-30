# Story 3.2 — décisions approuvées le 22 octobre 2026

Source : spec-3-2-details-action.md, approbation « fait tout ce que tu recommandes ».

- Toute la ligne d’une action ayant des détails reçus devient une commande native
  d’au moins 48 px, avec chevron et état replié/déplié annoncé. Sans contenu,
  la ligne reste statique.
- Le corps affiche directement les données reçues en texte/JSON sélectionnable.
  Les textes de secours ne remplacent pas des données structurées présentes.
  Aucun second dépliage d’aperçu, aucune exécution et aucun chargement distant.
- Le choix de chaque action appartient à la page et survit aux mises à jour
  et au repli du groupe. Le corps défilant ne commande pas le repli.
- Validation complémentaire « je valide » : consulter volontairement un détail
  maintient son groupe ouvert au premier fragment. Le repli manuel reste
  prioritaire ; les groupes jamais consultés se replient automatiquement.
- Une erreur reçue dans result.error reste un détail d’action. Le statut du
  travail, les quatre lots Otc et les identités de 3.1 sont conservés.

Preuves synthétiques et limites : implementation-artifacts/story-3-2-verification/.
