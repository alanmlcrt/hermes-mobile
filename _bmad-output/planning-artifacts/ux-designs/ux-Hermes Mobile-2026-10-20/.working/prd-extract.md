# Extraction UX du PRD — Hermes Mobile

Source confirmée par Alanc : [PRD final, mis à jour le 2026-10-20](../../../prds/prd-Hermes-Mobile-2026-10-20/prd.md), et son [addendum](../../../prds/prd-Hermes-Mobile-2026-10-20/addendum.md). Cette extraction conserve la distinction entre obligations et propositions `[ASSUMPTION]` ; elle ne tranche aucun choix UX.

## Utilisateur, contexte et surfaces

- **Alanc** est le seul protagoniste nommé. Usage personnel, à distance, sur **Android** ; iPhone anticipé sans simultanéité promise. Aucun récit de session avec étapes et climax n'est fourni : les critères d'essai ne sont pas un parcours utilisateur validé. Source : PRD, « But et utilisateur », « Périmètre et exclusions », « Réussite proposée et limites ».
- Hermes s'exécute sur le serveur Home Assistant ; le téléphone est un client de communication. Tailscale existe déjà. Les modalités d'association et d'authentification restent à concevoir. Source : PRD FR-1 ; addendum « Intégration à vérifier ».
- Finalité : confier librement des demandes à Hermes, y compris code, environnement, configuration de profils et compétences, depuis une messagerie soignée. Aucun environnement de développement ou moteur d'agent mobile dédié. Source : PRD « But et utilisateur », « Périmètre et exclusions ».

## Vocabulaire source à conserver

Le PRD définit exactement **Profil**, **Agent**, **Conversation**, **Action**, **Pièce jointe**. Un profil persistant peut contenir plusieurs conversations ; une action est une opération d'outil. Leur définition métier ne préjuge pas de la formulation destinée à l'utilisateur. Source : PRD « Vocabulaire ».

## Besoins obligatoires et surfaces à couvrir

Ces regroupements expriment des besoins de surface, pas une architecture d'écrans décidée.

| Référence | Besoin qui doit trouver une surface |
| --- | --- |
| FR-1 | Connexion distante au serveur par Tailscale ; distinguer serveur inaccessible et authentification refusée. QR/lien et secours manuel restent proposés. |
| FR-2 | À l'ouverture normale, préparer une nouvelle conversation avec le profil par défaut. Non-enregistrement du fil vide, conservation au retour temporaire et ouverture ciblée depuis une notification sont proposés. |
| FR-3, FR-10 | Choisir les profils existants, identifier le profil actif, retrouver ses conversations et en créer une. Aucun mélange de messages/fichiers entre conversations. Chargement/actualisation des profils sans recréation ni saisie de configuration. |
| FR-4 | Saisie/collage de longs textes ; réponses lisibles avec emojis, mise en forme et code ; actions courantes sans commandes `/`. Streaming et traitement des limites sans perdre le brouillon restent proposés. |
| FR-5, FR-6 | Joindre images, captures, PDF, documents bureautiques et autres formats effectivement acceptés ; transmettre à la bonne conversation et identifier les fichiers dans l'historique. Prévisualisation, retrait et indication préalable des limites sont proposés. |
| FR-7 | Synthèse de l'activité et détails dépliables fournis par Hermes. Outils, commandes, sorties et erreurs sont proposés selon les données disponibles. |
| FR-8 | Le travail accepté continue lorsqu'Alanc quitte l'app. Récupération de l'historique/état et absence de renvoi automatique d'une demande incertaine sont proposées ; NFR-2 interdit la duplication silencieuse. |
| FR-9 | Notification de fin hors de l'app permettant de retrouver la conversation. Couverture des issues réussite/erreur/arrêt confirmé proposée, transport et Android app fermée à vérifier. |
| FR-12 | Arrêter depuis la conversation sans commande `/` ; distinguer demande envoyée et confirmation réelle du serveur. Les effets déjà exécutés ne sont pas annulés. |

FR-1 à FR-10 et FR-12 forment le socle ; **FR-11 est retiré**. **FR-13** (question/autorisation et réponse), **FR-14** (ouvrir/télécharger un résultat accessible) sont proposés et doivent être tranchés avec Alanc et l'architecture avant leurs stories. Les notifications d'intervention ne sont pas confirmées. Source : PRD « Fonctionnalités du MVP », addendum « Grok Bot : inspiration pour le client ».

## États, continuité et garde-fous

- États du fil proposés : **envoi**, **travail en cours**, **attente d'une réponse ou d'une autorisation**, **demande d'arrêt**, **arrêt confirmé**, **fin**, **erreur**, **inconnu/non synchronisé**. Source : PRD « Expérience et qualité attendues ».
- Connexion : inaccessible ≠ authentification refusée. Profils : liste réellement vide ≠ échec de chargement (distinction proposée). Fichiers : transmission échouée ≠ fichier reçu ; résultat accessible sur téléphone ≠ simple chemin serveur (FR-14 proposé).
- NFR-2 : aucune coupure ne doit perdre un brouillon existant, masquer un échec ou provoquer silencieusement une nouvelle exécution. FR-12 : perte réseau ≠ confirmation d'arrêt.
- FR-13 proposé : une saisie pendant le travail ne signifie pas forcément interruption immédiate ; préciser sa prise en compte immédiate ou différée selon le serveur. Ne pas inventer de politique d'approbation.
- NFR-3 : ne pas afficher les secrets dans les erreurs/diagnostics ; Tailscale ne remplace pas l'authentification Hermes.
- NFR-4 : indiquer clairement une fonction absente ; cela ne suffit pas à accepter un MVP privé d'une fonction obligatoire. Disponibilité et limites à vérifier sur l'installation réelle.
- L'envoi hors ligne n'est pas spécifié. Aucun mode offline complet, cache consultable ou file d'attente n'est approuvé.

## Accessibilité et présentation explicitement demandées

- NFR-1 : parcours essentiels au toucher, clavier affiché, texte agrandi et lecteur d'écran ; libellés accessibles des icônes ; état jamais uniquement communiqué par couleur.
- Conversation prioritaire, suivi synthétique, détails techniques à la demande. Aucune palette, police, disposition précise, thème clair/sombre ou bibliothèque UI validés. Source : PRD « Expérience et qualité attendues ».
- Grok Bot : messagerie avec agent persistant, retours vers l'utilisateur quand son intervention est requise. Orca Mobile : association Tailscale. L'addendum dit Muse non identifié ; **cette information est dépassée par le lien fourni dans la conversation : https://ai.meta.com/muse/**. Les deux liens utilisateur sont des références à examiner, pas une validation de tous leurs choix visuels.
- Dernière instruction d'Alanc : « Je veux une interface simple à comprendre, je ne veux pas de trucs trop technique. » Elle doit guider la présentation et le vocabulaire, sans supprimer l'accès aux détails requis par FR-7.

## Exclusions et points à clarifier

- Confirmé : aucun écran de consultation ou d'administration des profils au MVP ; configuration demandée en conversation au profil par défaut. Consultation des outils/MCP/skills après MVP.
- Reports encore proposés : voix, routines, groupes d'agents, import Discord, diffusion publique.
- À décider en UX avec Alanc : accueil/reprise, streaming, brouillons, préparation et états des fichiers, états du fil, actualisation des profils, direction visuelle.
- À ne pas inventer : navigation et découpage des écrans, hiérarchie visuelle, ton précis, thème, densité, animations, gestes, formats d'approbation, états vides, comportement clavier, paramètres, suppression/recherche/renommage des conversations.
- Parcours à faire raconter par Alanc : une vraie session, puis reprise après fermeture et retour par notification ; choix d'un autre profil ; pièces jointes et arrêt. Ce sont des axes tirés des besoins, pas des parcours déjà validés.
- Compatibilité, FR-13/FR-14, messages pendant le travail, issues notifiées, limites et corpus d'acceptation : résolution avec architecture. L'addendum signale que l'API compatible OpenAI ne garantit pas l'upload de documents génériques ; ne pas promettre leur traitement à partir d'un simple aperçu local.
