- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-init-app-telephone.md`
  summary: Choisir l'identifiant de bundle iOS (actuellement `fr.hermesMobile`, généré par `flutter create`), puisque `fr.hermes_mobile` est invalide sur iOS.
  evidence: `ios/Runner.xcodeproj/project.pbxproj` l.386 diffère de l'identifiant Android ; les `_` sont interdits dans un bundle id iOS. À trancher avant le travail iPhone.
- source_spec: `_bmad-output/implementation-artifacts/spec-7-1-verifier-rangement-recherche.md`
  summary: Préciser le traitement de session.title pending dans la story 7.2.
  evidence: Le plan 7.2 préexistant demande confirmation avant affichage, mais le contrat documentaire autorise pending ; qualifier la persistance et la réconciliation avant cette story.

- source_spec: `_bmad-output/implementation-artifacts/spec-7-1-verifier-rangement-recherche.md`
  summary: Vérifier la coordination des mutations de masquage par lignée dans 7.4 (risque moyen non vérifié).
  evidence: Le plan préexistant sérialise par session alors que le candidat touche une lignée ; vérifier deux IDs partageant la même lignée et la concurrence sur installation pour trancher.

- source_spec: `_bmad-output/implementation-artifacts/spec-7-1-verifier-rangement-recherche.md`
  summary: Mesurer la réactivité de la recherche 7.6 sur un corpus local représentatif (risque moyen non vérifié).
  evidence: Le plan préexistant ne borne pas le travail à la saisie ; aucune implémentation ne démontre de blocage. Mesures de latence et volume réel nécessaires pendant 7.6.
