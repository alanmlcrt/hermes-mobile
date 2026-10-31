import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:hermes_mobile/ui/dynamic_color_bridge.dart';
import 'package:hermes_mobile/ui/theme.dart';
import 'package:hermes_mobile/ui/tokens.dart';

void main() {
  for (final brightness in Brightness.values) {
    group('buildTheme ($brightness)', () {
      test('sans Dynamic Color : palette de secours', () {
        final theme = buildTheme(null, brightness);
        expect(theme.colorScheme, fallbackColorScheme(brightness));
        expect(theme.colorScheme.brightness, brightness);
      });

      test('avec Dynamic Color : schéma fourni', () {
        final dynamicScheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF3366CC),
          brightness: brightness,
        );
        final theme = buildTheme(dynamicScheme, brightness);
        expect(theme.colorScheme, dynamicScheme);
        expect(theme.colorScheme, isNot(fallbackColorScheme(brightness)));
      });
    });
  }

  group('fromDynamicScheme', () {
    test('null reste null (palette de secours)', () {
      expect(fromDynamicScheme(null), isNull);
    });

    for (final brightness in Brightness.values) {
      test('recopie chaque rôle du schéma dynamique ($brightness)', () {
        final src = mui.ColorScheme.fromSeed(
          seedColor: const Color(0xFF3366CC),
          brightness: brightness,
        );
        final s = fromDynamicScheme(src)!;
        // Rôles non dépréciés (background, onBackground, surfaceVariant
        // ne sont pas recopiés).
        final pairs = <(String, Color, Color)>[
          ('primary', s.primary, src.primary),
          ('onPrimary', s.onPrimary, src.onPrimary),
          ('primaryContainer', s.primaryContainer, src.primaryContainer),
          ('onPrimaryContainer', s.onPrimaryContainer, src.onPrimaryContainer),
          ('primaryFixed', s.primaryFixed, src.primaryFixed),
          ('primaryFixedDim', s.primaryFixedDim, src.primaryFixedDim),
          ('onPrimaryFixed', s.onPrimaryFixed, src.onPrimaryFixed),
          (
            'onPrimaryFixedVariant',
            s.onPrimaryFixedVariant,
            src.onPrimaryFixedVariant,
          ),
          ('secondary', s.secondary, src.secondary),
          ('onSecondary', s.onSecondary, src.onSecondary),
          ('secondaryContainer', s.secondaryContainer, src.secondaryContainer),
          (
            'onSecondaryContainer',
            s.onSecondaryContainer,
            src.onSecondaryContainer,
          ),
          ('secondaryFixed', s.secondaryFixed, src.secondaryFixed),
          ('secondaryFixedDim', s.secondaryFixedDim, src.secondaryFixedDim),
          ('onSecondaryFixed', s.onSecondaryFixed, src.onSecondaryFixed),
          (
            'onSecondaryFixedVariant',
            s.onSecondaryFixedVariant,
            src.onSecondaryFixedVariant,
          ),
          ('tertiary', s.tertiary, src.tertiary),
          ('onTertiary', s.onTertiary, src.onTertiary),
          ('tertiaryContainer', s.tertiaryContainer, src.tertiaryContainer),
          (
            'onTertiaryContainer',
            s.onTertiaryContainer,
            src.onTertiaryContainer,
          ),
          ('tertiaryFixed', s.tertiaryFixed, src.tertiaryFixed),
          ('tertiaryFixedDim', s.tertiaryFixedDim, src.tertiaryFixedDim),
          ('onTertiaryFixed', s.onTertiaryFixed, src.onTertiaryFixed),
          (
            'onTertiaryFixedVariant',
            s.onTertiaryFixedVariant,
            src.onTertiaryFixedVariant,
          ),
          ('error', s.error, src.error),
          ('onError', s.onError, src.onError),
          ('errorContainer', s.errorContainer, src.errorContainer),
          ('onErrorContainer', s.onErrorContainer, src.onErrorContainer),
          ('surface', s.surface, src.surface),
          ('onSurface', s.onSurface, src.onSurface),
          ('surfaceDim', s.surfaceDim, src.surfaceDim),
          ('surfaceBright', s.surfaceBright, src.surfaceBright),
          (
            'surfaceContainerLowest',
            s.surfaceContainerLowest,
            src.surfaceContainerLowest,
          ),
          (
            'surfaceContainerLow',
            s.surfaceContainerLow,
            src.surfaceContainerLow,
          ),
          ('surfaceContainer', s.surfaceContainer, src.surfaceContainer),
          (
            'surfaceContainerHigh',
            s.surfaceContainerHigh,
            src.surfaceContainerHigh,
          ),
          (
            'surfaceContainerHighest',
            s.surfaceContainerHighest,
            src.surfaceContainerHighest,
          ),
          ('onSurfaceVariant', s.onSurfaceVariant, src.onSurfaceVariant),
          ('outline', s.outline, src.outline),
          ('outlineVariant', s.outlineVariant, src.outlineVariant),
          ('shadow', s.shadow, src.shadow),
          ('scrim', s.scrim, src.scrim),
          ('inverseSurface', s.inverseSurface, src.inverseSurface),
          ('onInverseSurface', s.onInverseSurface, src.onInverseSurface),
          ('inversePrimary', s.inversePrimary, src.inversePrimary),
          ('surfaceTint', s.surfaceTint, src.surfaceTint),
        ];
        for (final (name, actual, expected) in pairs) {
          expect(actual, expected, reason: name);
        }
        expect(s.brightness, src.brightness);
        expect(buildTheme(s, brightness).colorScheme.emphasis, src.primary);
      });
    }
  });

  test('rôles mappés sur le schéma', () {
    final s = fallbackColorScheme(Brightness.light);
    expect(s.canvas, s.surface);
    expect(s.content, s.onSurface);
    expect(s.emphasis, s.primary);
    expect(s.emphasisContent, s.onPrimary);
  });

  testWidgets('motionDuration respecte le mouvement réduit', (tester) async {
    late Duration normal;
    late Duration reduced;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (c) {
            normal = motionDuration(c, Motion.medium);
            return MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (c2) {
                  reduced = motionDuration(c2, Motion.medium);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(normal, Motion.medium);
    expect(reduced, Duration.zero);
  });
}
