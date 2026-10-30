# Epic 4 Context: Joindre photos et documents à mes demandes

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Permettre à Alanc de joindre photos, captures, PDF et documents bureautiques à une demande, de les vérifier ou retirer avant l'envoi, puis de savoir fichier par fichier si Hermes les a reçus dans la bonne conversation. L'épic remplace les promesses génériques par des limites mesurées sur l'installation réelle et sépare trois certitudes : fichier choisi, reçu par Hermes, analysé par le modèle.

## Stories

- Story 4.1: Fixer les limites de fichiers sur mon installation
- Story 4.2: Joindre des fichiers à une demande
- Story 4.3: Envoyer mes fichiers et savoir s'ils sont reçus
- Story 4.4: Retrouver mes fichiers dans l'historique

## Requirements & Constraints

- **Limites mesurées, jamais inventées.** Mesurer type, nombre et taille avec le corpus d'Alanc (long texte, photo ou capture, PDF, document bureautique), sur un profil de test dédié, et retenir la limite la plus restrictive vérifiée parmi l'app, le proxy, Hermes et le modèle ; une limite non vérifiée reste notée comme telle et une capacité absente est signalée à Alanc, pas contournée.
- **Réception prouvée.** Un fichier n'est « reçu » qu'après vérification dans la session Hermes visée, au-delà d'un aperçu client. Les limites s'affichent avant l'envoi ; un fichier hors limite est refusé avec sa raison, et « autres fichiers » ne promet aucun format non vérifié.
- **Brouillon privé, doute bloquant.** Les octets sont copiés dans l'espace privé et listés dans le brouillon ; retirer une pièce supprime sa copie et les pièces survivent à une fermeture forcée. Chaque pièce affiche son état (envoi, reçu, échec) par libellé ; un échec ou un doute bloque le prompt, conserve brouillon et pièces, et n'est jamais présenté comme reçu.
- **Portée et analyse.** Chaque téléversement vise le scope connexion/profil/session d'origine et renvoie une référence serveur ; aucun chemin du téléphone n'est transmis, et un profil ne voit jamais les fichiers d'un autre. Un upload réussi ne prouve pas que le modèle a lu le fichier : si son modèle n'analyse pas les images, l'app le dit.
- **Historique et accès.** Les pièces restent identifiables après redémarrage ; les copies locales ne sont nettoyées qu'après rapprochement avec l'historique distant ; aucun fichier n'est exécuté. Noms accessibles, cibles suffisantes, texte à 200 %, lecteur d'écran, pas d'état par la seule couleur, permission refusée expliquée.

## Technical Decisions

- **Pièces reçues avant utilisation.** Octets dans `attachments/<DraftKey>/`. Validation contre la limite la plus restrictive ; prompt seulement après confirmation de toutes les pièces retenues, avec leurs références serveur dans le scope d'origine ; upload échoué ou incertain = pas de prompt. Pièces rattachées à `ConnectionKey`/`ProfileKey`/`SessionKey` ; `DraftKey` local, associé à la session avant soumission.
- **Pipeline sans répétition.** Opération persistée avant envoi (cible, contenu exact, références), puis `ensureSession` → pièces → suivi de notification (non bloquant) → soumission. Résultat incertain = `unknown`, brouillon conservé, aucun renvoi ; répétition seulement si l'idempotence est démontrée.
- **Contrat de transport.** Le transport (upload REST ou `file.attach` avec chemin serveur ou `data_url`) et les limites par type sont figés dans `contracts/` ; `file.attach` est une capacité optionnelle détectée à la connexion. Une route d'upload ne prouve ni la référence dans le message ni les droits de l'add-on ; l'API compatible OpenAI ne peut porter seule les documents génériques.

## UX & Interaction Patterns

- **Entrée encore fermée.** L'interface du 23 octobre a retiré le « + » et le micro, le service n'étant pas établi côté Hermes ; ils reviennent avec la fonction. Ne pas exposer « Joindre » avant que G2 ait établi transport et limites ; le parcours de permission reste à arbitrer.
- **Liste et accessibilité.** Aperçu des images, nom/type/taille des autres, retrait individuel, limites avant envoi, pièce identifiable dans l'historique. Reprendre tokens, Inter et composants du 23 octobre ; libellés distinguant « reçu par Hermes » de « analysé par le modèle », annonces lecteur d'écran, cibles ≥ 44 px, texte à 200 %.

## Cross-Story Dependencies

- **Porte G2 (bloquante).** « Fichiers : limites et réception dans le bon fil, corpus d'Alanc. » Sans contrat vérifié, les stories de fichiers ne démarrent pas ; elle bloque aussi l'acceptation du texte long et des fichiers. Le corpus vient d'Alanc.
- **4.1 → 4.2/4.3/4.4.** Les limites et le transport de 4.1 alimentent la validation de 4.2 puis l'upload de 4.3 ; aucune limite codée en dur avant cette mesure. 4.4 attend le rapprochement avant de nettoyer les copies.
- **Epics 1 et 2.** Connexion, identités, profils, capacités et contrat viennent de l'Epic 1 ; brouillons, `ensureSession`, reprise sans renvoi et historique par profil viennent de l'Epic 2. G1 précède toute intégration réelle.
- **Epics 5 et 6.** Le pipeline réserve l'étape « suivi de notification », non bloquante : son échec ne bloque ni pièces ni soumission. Les fichiers résultats ont un emplacement séparé et un accès authentifié, sans réutiliser `attachments/<DraftKey>/`.
