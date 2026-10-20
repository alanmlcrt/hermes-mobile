# PRD Quality Review — Hermes Mobile

## Overall verdict
Le PRD constitue une base solide pour concevoir l’UX et étudier l’intégration d’un client Android personnel : le rôle du client, les profils et les limites du MVP sont explicites. La mise en œuvre reste conditionnée à la preuve des capacités de l’installation Hermes ; il faut éviter qu’une indisponibilité technique permette de déclarer le MVP terminé sans l’une de ses fonctions indispensables.

## Decision-readiness — adequate
Le « client de communication avec Hermes » constitue une décision nette (§ But et utilisateur), et l’exclusion des écrans d’administration des profils préserve la simplicité demandée. Les choix de protocole et de stack peuvent légitimement attendre l’architecture. Les hypothèses et questions doivent encore recevoir leur propriétaire et leur échéance de réexamen pendant la finalisation, comme prévu.

## Substance over theater — strong
Le besoin est propre à Alanc et aux limites de Discord : longs textes, présentation des exécutions, profils distincts. Les exigences de fiabilité décrivent des conséquences observables, notamment l’absence de relance silencieuse après une coupure. Ni personas décoratifs, ni promesse de nouveauté, ni objectifs de croissance ne viennent alourdir ce projet personnel.

## Strategic coherence — strong
Les fonctionnalités servent une même proposition : communiquer avec le Hermes existant depuis une interface mobile lisible. Le report de la consultation des outils, MCP et skills découle directement du choix de simplicité. L’essai Android distant et sa contre-mesure « aucune duplication d’exécution ou perte de brouillon » vérifient l’expérience recherchée plutôt qu’une métrique d’activité.

## Done-ness clarity — adequate
Les FR possèdent généralement une conséquence vérifiable : distinguer arrêt demandé et confirmé, échec d’envoi et fichier reçu, chemin serveur et résultat téléchargeable. Les volumes de référence restent à fixer avant les essais ; cela peut être une tâche explicite d’architecture et de préparation des tests, sans imposer de valeurs arbitraires aujourd’hui.

### Findings
- **medium** Seuils d’essai encore sans point de décision (§ FR-4, FR-5, Réussite proposée et limites) — « La taille de texte de référence reste à fixer » et « Les formats et volumes de référence seront choisis avant les tests » laissent la validation des longs textes et pièces jointes dépendre du choix tardif de cas faciles. *Fix:* attribuer à Alanc la sélection d’un texte long, d’une image et d’un document représentatifs, et à l’architecture la vérification des limites effectives ; consigner ces valeurs avant le découpage des stories concernées ou avant leur acceptation.
- **medium** Fin d’un travail insuffisamment délimitée (§ FR-9, Expérience et qualité attendues) — FR-9 demande une « notification de fin », alors que le fil distingue « arrêt confirmé, fin et erreur ». *Fix:* préciser si réussite, erreur et arrêt confirmé déclenchent chacun une notification ; à défaut, conserver ce choix UX comme question explicitement attribuée avant les stories de notification.

## Scope honesty — adequate
Les non-objectifs évitent de transformer l’application en moteur d’agent ou en IDE. Les capacités proposées sont signalées et regroupées dans l’index d’hypothèses. Un point nécessite toutefois une règle de décision pour la suite.

### Findings
- **high** Une fonction MVP manquante pourrait être réduite à un message (§ NFR-4, Réussite proposée et limites) — « une fonction absente est signalée clairement » et « Un contrôle indisponible est expliqué » ne disent pas si le MVP reste bloqué lorsque l’arrêt, les documents, les profils ou les notifications sont indisponibles sur le backend choisi. *Fix:* préciser qu’une capacité MVP obligatoire non démontrée bloque la validation de l’intégration et la déclaration du MVP terminé ; sa suppression exige un changement de périmètre explicite avec Alanc. Distinguer les capacités proposées conditionnelles, telles que les approbations exposées par le backend, des exigences déjà confirmées. Aucun protocole n’est à choisir dans le PRD pour régler ce point.

## Downstream usability — adequate
Le glossaire définit profil, agent, conversation, action et pièce jointe. Les FR sont individuellement extractibles ; FR-11 est explicitement réservé après retrait, ce qui préserve les identifiants existants. L’addendum permet à l’architecture de retrouver les divergences entre gateway, API Server et Desktop sans les confondre avec des capacités prouvées sur l’installation réelle.

## Shape fit — strong
La forme par capacités convient à un utilisateur unique et à un MVP personnel. Des parcours inventés avec des protagonistes supplémentaires n’apporteraient rien ; les scénarios d’acceptation Android fournissent suffisamment de contexte pour l’UX. La longueur est légèrement supérieure à deux pages mais reste justifiée par les limites d’intégration et l’explicitation des hypothèses.

## Mechanical notes
- Les FR-1 à FR-14 sont uniques ; FR-11 est réservé, et l’ordre FR-12 à FR-14 avant FR-10 est un regroupement thématique compréhensible, sans renumérotation nécessaire.
- L’index des hypothèses couvre les FR marquées, les états du fil, les critères de réussite et les exclusions.
- Aucun parcours utilisateur nommé n’est nécessaire à cette portée solo ; aucun parcours fictif n’a été ajouté.
- Le statut draft et les formulations « avant finalisation » sont cohérents avec le moment de cette revue ; ils seront actualisés à la fermeture du workflow.

## Décompte
Critical : 0 ; high : 1 ; medium : 2 ; low : 0.

## Vérification des corrections — 2026-10-20

Vérification limitée aux trois constats ci-dessus, sans nouvel audit général.

- **High — résolu.** NFR-4 précise désormais qu’une capacité obligatoire non démontrée « bloque l’acceptation du MVP » et qu’un retrait ou report exige une décision explicite d’Alanc. La section Réussite distingue les FR-1 à FR-10 et FR-12 obligatoires des FR-13/FR-14 proposés. Le tableau des décisions conditionne la validation de l’architecture aux preuves d’intégration.
- **Medium, corpus d’essai — résolu pour le passage à l’UX et à l’architecture.** Alanc est responsable de fournir texte long, photo/capture, PDF et document bureautique représentatifs avant rédaction des tests ; l’architecture consigne formats, volumes et limites. Les valeurs elles-mêmes constituent un livrable reporté explicite, sans bloquer le présent cadrage.
- **Medium, issues notifiées — résolu pour le présent cadrage.** FR-9 propose explicitement réussite, erreur et arrêt confirmé comme issues notifiées ; l’hypothèse est indexée et confiée à Alanc avec l’architecture avant création des stories concernées. Cette proposition reste à décider, ce qui est honnêtement visible.

**Verdict après corrections :** aucun constat critique, high ou medium non traité dans le périmètre de cette vérification. Le PRD peut être finalisé pour alimenter l’UX et l’architecture ; la preuve de compatibilité et les décisions reportées restent soumises aux jalons explicités, sans constituer une acceptation anticipée du MVP.
