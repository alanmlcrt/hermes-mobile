- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-init-app-telephone.md`
  summary: Choisir l'identifiant de bundle iOS (actuellement `fr.hermesMobile`, généré par `flutter create`), puisque `fr.hermes_mobile` est invalide sur iOS.
  evidence: `ios/Runner.xcodeproj/project.pbxproj` l.386 diffère de l'identifiant Android ; les `_` sont interdits dans un bundle id iOS. À trancher avant le travail iPhone.
