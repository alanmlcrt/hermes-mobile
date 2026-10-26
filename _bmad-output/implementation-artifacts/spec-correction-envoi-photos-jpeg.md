---
title: 'Corriger l’envoi désactivé avec une photo JPEG jointe'
type: 'bugfix'
created: '2026-10-26'
status: 'in-progress'
baseline_commit: '4d9ecf1eaeedee5106602b9c03f4a3b15b19cd7a'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problème :** Alanc peut sélectionner une photo, puis ne peut plus envoyer son message. Le code désactive explicitement l’envoi des JPEG/JPG, pourtant proposés par le sélecteur natif. Le contrat actuel ne prouve que les PNG.

**Approche :** Vérifier JPEG sur Hermes dans le profil de test dédié, puis activer son envoi par `image.attach_bytes` avec son extension exacte si la réception distante est prouvée. Conserver les contrôles de taille et les garanties de réception, sans afficher les plafonds en Mo. Mettre la correction sur le téléphone après validation.

## Boundaries & Constraints

**Toujours :** Mesurer avant activation. Utiliser des images de test synthétiques identifiées comme telles, sans prélever ni envoyer de photo personnelle. Éprouver un petit JPEG et la borne de taille actuellement appliquée aux images, sur trois répétitions ; vérifier la réception dans la session exacte. Préserver les mesures PNG et documentaires existantes, avec provenance et date de la campagne complémentaire. Une borne non vérifiée pour JPEG ne doit pas être présentée comme prouvée. Les copies et le brouillon restent conservés sur refus ou doute.

**Jamais :** Lever les verrous sur la seule présence de la méthode, extrapoler PNG vers JPEG, substituer un PNG aux octets JPEG sans l’indiquer, modifier les pièces personnelles de la conversation, promettre une analyse par le modèle ou renvoyer automatiquement une demande. Aucun effet dans le profil personnel lors de la campagne.

## I/O & Edge-Case Matrix

| Scénario | Entrée / état | Résultat | Erreur |
| --- | --- | --- | --- |
| JPEG vérifié | JPEG/JPG sous borne mesurée, connexion disponible | Bouton actif, octets et extension JPEG dans le bon scope, prompt après upload confirmé | Réception distinguée de l’analyse |
| Brouillon existant | JPEG sélectionné avant mise à jour | Envoi possible sans nouvelle sélection après activation vérifiée | Texte et pièce conservés |
| Contrôle négatif | Refus, timeout ou preuve absente | Aucun faux reçu, aucun prompt si upload incertain | Pas de répétition automatique |
| Taille excessive | JPEG au-delà de la borne vérifiée | Refus simple sans seuil affiché | Aucun appel externe |
| PNG et documents | Pièces auparavant prises en charge | Parcours inchangé | Aucune régression des mesures |
| Campagne échouée | Hermes ne confirme pas JPEG à la borne visée | Activation interrompue, résultat exact communiqué | Aucune mesure inventée |

</frozen-after-approval>

## Code Map

- `lib/features/conversation/draft_view_model.dart`, `blockedReason` : verrou JPEG avant le bouton. Les contrôles connexion, travail en cours, brouillon vide et tentatives incertaines restent nécessaires.
- `lib/data/outbox_repository.dart`, `send` : second verrou JPEG avant création de session. Préserver instantanés, scope, références et prévention des doubles envois.
- `lib/data/attachment_transport.dart`, `upload` : troisième refus JPEG ; seule l’image PNG utilise actuellement `image.attach_bytes` avec `ext: png`. Utiliser la méthode image pour JPEG vérifié, avec `ext: jpg`, sans envoyer le chemin local.
- `lib/data/file_limits.dart` : JPEG actuellement accepté localement comme exception. Faire correspondre prise en charge et formats réellement vérifiés, sans inventer de borne.
- `contracts/file-limits.json`, `contracts/README.md` : preuves d’octobre limitées à PNG pour les images ; conserver leur provenance lors du complément JPEG.
- `tool/mesure_pieces_jointes.dart` : supporte déjà JPG/JPEG et `--surface image.attach_bytes`, contrôle du profil de test, lecture des reçus et sortie anonymisée. Son résultat partiel ne doit pas remplacer les autres catégories du contrat.
- `_bmad-output/implementation-artifacts/.hermes-mesure.env` : configuration locale ; jamais afficher ni commiter ses valeurs.
- `lib/ui/content.dart` : textes « JPEG bloqué » et formats à adapter après preuve.

## Tasks & Acceptance

**Exécution :**
- [ ] `_bmad-output/implementation-artifacts/verification-jpeg/` : préparer les JPEG de test valides, documenter taille/dimensions/orientation, exécuter la sonde dédiée et conserver la sortie anonymisée. Arrêter l’activation si preuve insuffisante.
- [ ] `contracts/file-limits.json`, `contracts/README.md` : intégrer les seules preuves JPEG mesurées sans écraser les autres limites ; distinguer la campagne complémentaire du corpus initial.
- [ ] `lib/data/file_limits.dart`, `lib/features/conversation/draft_view_model.dart`, `lib/data/outbox_repository.dart`, `lib/data/attachment_transport.dart` : retirer les blocages absolus après preuve, contrôler les types et bornes vérifiés et utiliser le transport image avec extension correcte.
- [ ] `lib/ui/content.dart` : retirer l’annonce de JPEG bloqué et conserver les refus simples sans chiffres de limites.
- [ ] `test/attachment_send_test.dart`, `test/attachment_flow_test.dart`, `test/attachment_store_test.dart`, `test/contracts_test.dart` : JPEG depuis un brouillon durable, bouton actif, paramètres exacts, octets, bornes et échecs ; préserver PNG et documents.
- [ ] `build/app/outputs/flutter-apk/app-release.apk` : compiler avec un numéro supérieur au build installé et mettre à jour le Pixel en conservant ses données.

**Critères d’acceptation :**
- Étant donné une photo JPEG vérifiée jointe au brouillon et une connexion disponible, quand Alanc saisit son message, alors il peut l’envoyer et la référence image appartient à la conversation d’origine.
- Étant donné une preuve manquante ou un échec, quand l’envoi s’arrête, alors texte et copie restent récupérables sans faux reçu ni répétition automatique.
- Étant donné le brouillon JPEG existant sur le téléphone, quand la version corrigée est installée, alors la sélection conservée permet l’envoi sans afficher de plafond en Mo.

## Implementation Notes

Diagnostic : arbre propre, bouton désactivé confirmé par Alanc. Test `JPEG is blocked before any upload` réussi, trois gardes identifiées. Aucun envoi distant effectué. Effets externes prévus : sessions et copies de test, puis mise à jour du téléphone sans suppression de données personnelles.

## Spec Change Log

## Review Triage Log

## Verification

- Sonde JPEG avec réception distante dans le profil dédié, trois répétitions par taille.
- `flutter test test/attachment_send_test.dart test/attachment_flow_test.dart test/attachment_store_test.dart test/contracts_test.dart` : cas corrigé et garanties conservées.
- `flutter test` : aucune régression.
- `flutter analyze` : aucune anomalie.
- `flutter build apk --release --build-number <numéro supérieur au téléphone>` : compilation et installation réussies.
