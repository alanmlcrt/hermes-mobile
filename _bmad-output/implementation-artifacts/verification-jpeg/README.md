# Vérification complémentaire JPEG — 26 octobre 2026

Corpus exclusivement synthétique, sans photo personnelle. `generer.py` produit
deux JPEG valides puis les décode intégralement avec Pillow. `corpus.json`
conserve les dimensions, tailles, orientations EXIF et empreintes SHA-256.

| Fichier local | Taille en octets | Dimensions | Orientation EXIF |
| --- | ---: | --- | ---: |
| synthetique-petit.jpg | 3 383 | 320 × 240 | 1 (normale) |
| synthetique-borne.jpeg | 20 965 448 | 4096 × 4096 | 1 (normale) |

La grande image contient du bruit déterministe et des segments COM JPEG
valides avant EOI pour atteindre exactement la borne appliquée aux images.
Elle reste un JPEG ; aucune conversion PNG ni substitution d'octets.
Ces deux images n'éprouvent pas les autres orientations EXIF.
Les fichiers binaires restent locaux et sont ignorés par Git.

## Reproduction

Depuis la racine du projet, avec Pillow et le SDK Flutter 3.47.7 installés :

```powershell
python _bmad-output/implementation-artifacts/verification-jpeg/generer.py
python _bmad-output/implementation-artifacts/verification-jpeg/mesurer.py
```

`mesurer.py` charge la configuration locale ignorée par Git, sans en afficher
les valeurs. Il appelle la sonde existante dans le profil de test dédié,
avec uniquement `image.attach_bytes`, trois répétitions par taille et sortie
anonymisée `mesure-jpeg.json`. Aucun profil personnel n'est ciblé.
La sonde contrôle que le profil n'est pas celui par défaut. Elle conserve
les sessions et copies de test et exige une relecture de `session.history`
dans la session exacte pour déclarer la réception. Aucun marqueur de vision
n'est demandé : cette campagne porte sur la réception, pas sur l'analyse.

Cette sortie partielle ne doit jamais remplacer intégralement le contrat
initial PNG, texte, PDF et documents du 24 octobre.

## État

Campagne lancée ; activation conditionnée à la réception des six copies et
à la preuve de la borne. Aucun déblocage JPEG avant cette vérification.
