# Contrat documentaire Hermes

Référence officielle : **v0.22.2**, commit `d923a5eb487a17c0a68801bba9ef0f56c81040a8` de NousResearch/hermes-agent. `openrpc.json` est un extrait du fichier généré officiel : six méthodes utilisées ou documentées pour cet epic, `gateway.ready` et les schémas atteints par leurs références. `tool/extract_openrpc.py` le reconstruit depuis le fichier officiel complet. `x-provenance` conserve release, SHA, source et nature documentaire de l’extrait ; `methods.json` décrit la surface appelée, avec les liens épinglés.

Les fixtures sont **synthétiques**, avec des marqueurs de secrets fictifs. Le backend personnel n’a pas été contacté. Aucune équivalence avec le build de l’add-on n’est établie ; la capture 1.3/G1 et les vérifications sur téléphone restent ouvertes.

`capabilities.json` sépare présence documentaire et état réel non vérifié. Seules les réponses effectives (GET profils, `gateway.ready`, `gateway.capabilities`) changent les états en mémoire. Les capacités futures mutantes restent non vérifiées ; aucun envoi ni création de conversation n’est utilisé comme sonde. `event-mapping.json` décrit les événements utilisés ici, avec un type inconnu explicite ; les états de travail hors périmètre restent nuls.

Login JSON, cookies de session explicitement extraits, REST bearer, refresh puis relogin via coffre. Le ticket WS est un sous-protocole, sans secret dans l’URL ; les redirections sont refusées. Aucun POST de sélection globale.

Après activation autorisée : comparer build et contrat, capturer les réponses expurgées, vérifier auth, profils, ticket, reprise, deux profils, texte 200 % et TalkBack. La présence documentaire ne vaut jamais validation réelle.
