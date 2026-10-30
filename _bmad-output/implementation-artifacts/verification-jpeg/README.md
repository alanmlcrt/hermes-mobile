# Vérification complémentaire JPEG — 26 octobre 2026

Corpus exclusivement synthétique, sans photo personnelle. `generer.py` produit
deux JPEG valides puis les décode intégralement avec Pillow. `corpus.json`
conserve les dimensions, tailles, orientations EXIF et empreintes SHA-256.

| Fichier local | Taille en octets | Dimensions | Orientation EXIF |
| --- | ---: | --- | ---: |
| synthetique-petit.jpg | 3 383 | 320 × 240 | 1 (normale) |
| synthetique-borne.jpeg | 20 965 448 | 4096 × 4096 | 1 (normale) |

Le grand fichier est une image de transport synthétique, rembourrée par des
segments JPEG valides ; sa taille ne représente pas une photo courante. Son
empreinte SHA-256, comme celle du petit fichier, est recopiée dans la preuve
supplémentaire de `contracts/file-limits.json` pour identifier les octets
mesurés.

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

Campagne terminée le 26 octobre 2026, de 20:03:52 à 20:04:46 UTC, sur le
build Hermes `0.22.2+1690` du profil de test dédié. Les six téléversements ont
été acceptés et les six reçus exacts ont été retrouvés dans les sessions
correspondantes, avec des références distinctes et aucun refus ni résultat
incertain. Chaque taille a été répétée trois fois. La preuve anonymisée est
dans `mesure-jpeg.json` ; les octets des images restent locaux et ignorés par
Git.

La réception JPEG est vérifiée jusqu’à 20 965 448 octets. C’est le plafond
local appliqué par l’application, fondé sur la plus grande taille testée avec
succès ; la taille maximale acceptée par Hermes reste inconnue. Une pièce qui
dépasse ce plafond local est refusée avant l’ouverture d’une session distante.
Cette campagne ne mesure ni le nombre maximal de pièces ni l’analyse par le
modèle. Les fichiers testés ont l’orientation EXIF normale (1) ; les autres
orientations ne sont pas couvertes. Son résultat partiel ne remplace pas le
contrat initial PNG, texte, PDF et documents du 24 octobre.

Le code de sortie 2 du journal indique que `file.attach`, nécessaire à la
complétude du contrat de mesure toutes catégories, n’a pas été vérifié par
cette campagne limitée aux images. Il ne contredit pas les six reçus JPEG
ci-dessus ; le JSON anonymisé conserve le statut distinct de chaque transport.
