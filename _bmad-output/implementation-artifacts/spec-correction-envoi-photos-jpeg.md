---
title: 'Corriger l’envoi désactivé avec une photo JPEG jointe'
type: 'bugfix'
created: '2026-10-26'
status: 'done'
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
- [x] `_bmad-output/implementation-artifacts/verification-jpeg/` : JPEG synthétiques valides, dimensions/orientation/empreintes et sortie anonymisée documentées.
- [x] `contracts/file-limits.json` et `verification-jpeg/README.md` : preuve JPEG complémentaire intégrée sans écraser les autres limites. `contracts/README.md` conserve les changements Epic 5 de l’autre travail en cours ; la preuve JPEG est documentée dans son propre README pour éviter un conflit d’édition.
- [x] `lib/data/file_limits.dart`, `lib/features/conversation/draft_view_model.dart`, `lib/data/outbox_repository.dart`, `lib/data/attachment_transport.dart` : garde JPEG levée sur la preuve, type/bornes mesurés contrôlés, et octets transmis par image avec `ext: jpg`.
- [x] `lib/ui/content.dart` : annonce de blocage JPEG retirée ; refus de taille reste sans chiffre.
- [x] `test/attachment_send_test.dart`, `test/attachment_flow_test.dart`, `test/attachment_store_test.dart`, `test/contracts_test.dart`, `test/file_limits_test.dart` : reçu exact, paramètres et octets JPEG, plafond local avant RPC, brouillon durable rouvert et bouton actif ; stockage JPEG, PNG et documents conservés.
- [x] `build/app/outputs/flutter-apk/app-release.apk` : build 16 installé sur le Pixel 8 Pro avec `adb install -r`, puis lancement et vérification du `versionCode=16`.

**Critères d’acceptation :**
- Étant donné une photo JPEG vérifiée jointe au brouillon et une connexion disponible, quand Alanc saisit son message, alors il peut l’envoyer et la référence image appartient à la conversation d’origine.
- Étant donné une preuve manquante ou un échec, quand l’envoi s’arrête, alors texte et copie restent récupérables sans faux reçu ni répétition automatique.
- Étant donné le brouillon JPEG existant sur le téléphone, quand la version corrigée est installée, alors la sélection conservée permet l’envoi sans afficher de plafond en Mo.

## Implementation Notes

Diagnostic : bouton désactivé confirmé par Alanc ; les gardes JPEG étaient le motif. La campagne synthétique du 26 octobre sur Hermes `0.22.2+1690` a accepté 6/6 téléversements et confirmé 6 reçus exacts distincts, trois essais par taille (3 383 et 20 965 448 octets). Aucun maximum serveur ni nombre maximal de pièces n’est établi. APK release 16 installé et lancé sur le Pixel 8 Pro avec mise à jour conservant les données.

## Spec Change Log

## Review Triage Log

- `defer` — La diff depuis le commit de base contient aussi les fichiers Epic 5 modifiés en parallèle ; ils ne font pas partie de cette correction et seront exclus du commit JPEG. La revue a reçu cette vue globale imposée par l’état partagé du dépôt.
- `medium / patch` — Le journal de campagne conclut à tort qu’aucun transport n’était exploitable malgré les six reçus JPEG exacts. La documentation distingue maintenant cette conclusion générique des observations JPEG enregistrées.
- `medium / patch` — Le code de sortie 2 de la mesure partielle n’était pas expliqué et paraissait invalider les reçus JPEG. Il signifie que `file.attach` n’a pas été vérifié et que le contrat toutes catégories reste incomplet ; le message de la sonde et le README le disent explicitement.
- `medium / patch` — Les 20 965 448 octets observés ne prouvent pas la limite distante maximale. La documentation et le contrat précisent qu’il s’agit du plafond local choisi à partir de la plus grande taille acceptée mesurée ; la capacité maximale du serveur reste inconnue.
- `medium / patch` — Le test de refus à 20 965 449 octets valide uniquement le plafond local configuré, pas un rejet Hermes à cette taille. Le contrat précise cette distinction et note que la limite distante n’a pas été mesurée.
- `medium / patch` — Le test direct `FileLimits.refusal` ne garantissait pas le refus d’une pièce trop grande avant toute session distante. Un test d’envoi vérifie désormais l’absence de RPC en cas de dépassement.
- `low / patch` — Le grand JPEG synthétique, rembourré par des segments valides, ne représente pas une photo usuelle. La documentation précise que ce fichier vérifie le transport à la borne, pas une distribution réelle de photos.
- `false` — Le diagnostic TLS se contente de `SecureSocket.connect`, mais cet appel valide le certificat avec les racines de confiance par défaut et échoue si le certificat est non vérifiable ; l’intitulé n’affirme pas une inspection détaillée du certificat.
- `defer` — Seule l’orientation EXIF normale est exercée. Cette correction ne transforme pas les images et ne promet pas de normaliser leur orientation ; le rendu des autres orientations est hors du comportement d’envoi constaté.
- `medium / patch` — Le manifeste local contenait les SHA-256, sans relier les empreintes au résultat de la campagne. Le contrat JPEG reprend maintenant ces empreintes et le test les compare au manifeste.
- `patch` — Le critère exige de mettre à jour le téléphone avec le brouillon conservé ; l’installation reste à démontrer avant de clore la story.
- `patch` — La revue de vérification a montré qu’un dépassement de taille pourrait autrement être refusé seulement après la création de session. Le nouveau test couvre le refus avant RPC.
- `patch` — La suite complète a révélé que `test/file_limits_test.dart` épinglait encore uniquement PNG. Son attente reflète maintenant les formats PNG et JPEG mesurés.

## Verification

- Sonde JPEG avec réception distante dans le profil dédié, trois répétitions par taille.
- `flutter test test/attachment_send_test.dart test/attachment_flow_test.dart test/attachment_store_test.dart test/contracts_test.dart` : cas corrigé et garanties conservées.
- `flutter test` : aucune régression.
- `flutter analyze` : aucune anomalie.
- `flutter build apk --release --build-number <numéro supérieur au téléphone>` : compilation et installation réussies.
- Vérification exécutée : `flutter test --no-pub --concurrency=1 --reporter json` passe ; tests ciblés JPEG, flux UI/SQLite, limites, stockage, contrat et mesure passent ; `flutter analyze --no-pub` ne signale aucune anomalie.
