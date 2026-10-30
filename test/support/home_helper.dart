import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/features/home/home_view.dart';

/// L'accueil liste les profils : entrer dans la conversation de [profile]
/// (nouveau brouillon sans historique). Sans accueil affiché, ne fait rien.
Future<void> enterHome(
  WidgetTester tester, [
  String profile = 'Principal (default)',
]) async {
  if (find.byType(HomeView).evaluate().isEmpty) return;
  await tester.tap(find.text(profile));
  await tester.pumpAndSettle();
}
