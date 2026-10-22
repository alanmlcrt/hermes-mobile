import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/companion_background.dart';
import 'package:hermes_mobile/ui/components/companion_background_editor.dart';
import 'package:hermes_mobile/ui/components/companion_backdrop.dart';
import 'package:hermes_mobile/ui/content.dart';
import 'package:hermes_mobile/ui/theme.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    Future<void> Function(CompanionPalette) save, {
    Brightness brightness = Brightness.light,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(null, brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CompanionBackgroundEditor(
                    initialPalette: CompanionPalette.lavenderPeach,
                    onApply: save,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> focusCommand(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 100);
    await tester.pumpAndSettle();
    for (var i = 0; i < 16; i++) {
      if (Focus.of(tester.element(find.text(label))).hasPrimaryFocus) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(
      Focus.of(tester.element(find.text(label))).hasPrimaryFocus,
      isTrue,
      reason: label,
    );
    expect(find.bySemanticsLabel(RegExp(RegExp.escape(label))), findsOneWidget);
  }

  testWidgets(
    'suppression et fin de sauvegarde dans la même frame préservent la route dessous',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Base')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Dessous')),
        ),
      );
      await tester.pumpAndSettle();
      final editor = MaterialPageRoute<void>(
        builder: (_) => CompanionBackgroundEditor(
          initialPalette: CompanionPalette.lavenderPeach,
          onApply: (_) => pending.future,
        ),
      );
      navigator.currentState!.push(editor);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Content.backgroundApply));
      await tester.pump();
      navigator.currentState!.removeRoute(editor);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Dessous'), findsOneWidget);
      expect(find.text('Base'), findsNothing);
    },
  );

  testWidgets('preview, annuler et retour ne sauvegardent rien', (
    tester,
  ) async {
    var writes = 0;
    await open(tester, (_) async {
      writes++;
    });
    await tester.tap(find.text(Content.mintSky));
    await tester.pump();
    expect(
      tester.widget<CompanionBackdrop>(find.byType(CompanionBackdrop)).palette,
      CompanionPalette.mintSky,
    );
    await tester.tap(find.text(Content.backgroundCancel));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(writes, 0);
  });
  testWidgets(
    'échec garde sélection, retry unique et retour bloqué pendant écriture',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await open(tester, (palette) async {
        expect(palette, CompanionPalette.roseLilac);
        calls++;
        if (calls == 1) throw StateError('failed');
        await pending.future;
      });
      await tester.tap(find.text(Content.roseLilac));
      await tester.tap(find.text(Content.backgroundApply));
      await tester.pumpAndSettle();
      expect(find.text(Content.backgroundSaveError), findsOneWidget);
      expect(
        find.text('${Content.roseLilac} — ${Content.backgroundSelected}'),
        findsOneWidget,
      );
      await tester.tap(find.text(Content.backgroundRetry));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(CompanionBackgroundEditor), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, Content.backgroundCancel),
            )
            .onPressed,
        isNull,
      );
      expect(calls, 2);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CompanionBackgroundEditor), findsNothing);
    },
  );
  testWidgets('clair sombre, portrait paysage, 200 %, clavier et sémantique', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    for (final brightness in Brightness.values) {
      for (final size in [const Size(375, 700), const Size(700, 375)]) {
        tester.view.physicalSize = size;
        final saved = <CompanionPalette>[];
        await open(
          tester,
          (palette) async {
            saved.add(palette);
          },
          brightness: brightness,
          scale: 2,
        );
        final selected = find.text(
          '${Content.lavenderPeach} — ${Content.backgroundSelected}',
        );
        await tester.scrollUntilVisible(selected, 100);
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(selected)
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        await focusCommand(tester, Content.mintSky);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(
                find.text('${Content.mintSky} — ${Content.backgroundSelected}'),
              )
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        await focusCommand(tester, Content.roseLilac);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(
                find.text(
                  '${Content.roseLilac} — ${Content.backgroundSelected}',
                ),
              )
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        await tester.scrollUntilVisible(
          find.text(Content.backgroundApply),
          100,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(FilledButton)).height,
          greaterThanOrEqualTo(48),
        );
        await focusCommand(tester, Content.backgroundApply);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(saved, [CompanionPalette.roseLilac]);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await focusCommand(tester, Content.backgroundCancel);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(saved, hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    }
    semantics.dispose();
  });
}
