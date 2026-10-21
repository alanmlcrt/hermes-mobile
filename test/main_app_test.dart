import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/main.dart';
import 'package:hermes_mobile/ui/content.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('MainApp suit le thème du téléphone ($brightness)',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const MainApp());
      await tester.pumpAndSettle();

      final label = find.text(Content.homePlaceholder);
      expect(label, findsOneWidget);
      expect(Theme.of(tester.element(label)).brightness, brightness);
    });
  }
}
