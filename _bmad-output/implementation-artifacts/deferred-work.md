- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-init-app-telephone.md`
  summary: Choisir l'identifiant de bundle iOS (actuellement `fr.hermesMobile`, généré par `flutter create`), puisque `fr.hermes_mobile` est invalide sur iOS.
  evidence: `ios/Runner.xcodeproj/project.pbxproj` l.386 diffère de l'identifiant Android ; les `_` sont interdits dans un bundle id iOS. À trancher avant le travail iPhone.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-1-nouvelle-conversation-brouillon.md`
  summary: Après un changement de profil depuis « Mes profils », ouvrir le brouillon du nouveau profil au lieu de revenir à celui de l'ancien.
  evidence: `/profiles` est poussé depuis `/draft/<clé>` et `selectProfile` ne relance pas `resolveLaunchTarget` ; relève de la story 2.5.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-1-nouvelle-conversation-brouillon.md`
  summary: Tester que `MainApp.dispose` vide l'outbox avant de fermer la base via le gateway.
  evidence: `MemoryOutbox.dispose` est vide ; l'ordre `outbox.dispose().whenComplete(gateway.dispose)` de `lib/main.dart` n'est observé par aucun test.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-envoi-sans-double-execution.md`
  summary: Rapprocher une opération `unknown` quand une réponse tardive ou l'historique prouve son acceptation.
  evidence: `call()` retire l'id au timeout, une réponse tardive est ignorée ; relève de la story 2.4.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-envoi-sans-double-execution.md`
  summary: L'accueil rouvre un brouillon de conversation existante quand il contient du texte, au lieu d'une nouvelle conversation.
  evidence: `openNewDraft` préfère `body <> ''` ; à remplacer par la restauration de 2.4/2.6 une fois l'historique disponible.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-3-reponse-en-direct.md`
  summary: Appariement des bulles utilisateur aux tours robuste aux tours lancés par un autre client sur la même session.
  evidence: `accepted()` apparie par position (`userTurns + 1`) ; un tour démarré ailleurs décale les liaisons.
