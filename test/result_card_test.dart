import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/result.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/components/result_card.dart';
import 'package:hermes_mobile/ui/content.dart';

ResultItem item(ResultState state, {int? bytes, String? errorCode}) =>
    ResultItem(
      1,
      resultKey: 'cle',
      path: '/home/u/rapport.pdf',
      name: 'rapport.pdf',
      mediaType: 'application/pdf',
      bytes: bytes,
      localKey: 'cle',
      state: state,
      errorCode: errorCode,
    );

Future<void> show(
  WidgetTester tester,
  Widget card, {
  double scale = 1,
  Size size = const Size(375, 812),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ),
  );
}

void main() {
  testWidgets('disponible : nom, type, état et téléchargement accessible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var downloads = 0;
    await show(
      tester,
      ResultCard(
        item: item(ResultState.available),
        onDownload: () => downloads++,
      ),
    );
    expect(find.text('rapport.pdf'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text(Content.resultAvailable), findsOneWidget);
    expect(find.text(Content.resultDownload), findsOneWidget);
    expect(find.text(Content.resultSize(0)), findsNothing);
    expect(
      find.bySemanticsLabel(Content.downloadResult('rapport.pdf')),
      findsOneWidget,
    );
    final button = find.widgetWithText(FilledButton, Content.resultDownload);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    final node = tester.getSemantics(
      find.bySemanticsLabel(Content.downloadResult('rapport.pdf')),
    );
    expect(node, isSemantics(isButton: true, hasTapAction: true));
    final live = tester.getSemantics(
      find.bySemanticsLabel(Content.resultAvailable),
    );
    expect(live.flagsCollection.isLiveRegion, isTrue);
    await tester.tap(button);
    expect(downloads, 1);
    semantics.dispose();
  });

  testWidgets(
    'téléchargé : taille et ouverture, jamais un second téléchargement',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var opens = 0;
      await show(
        tester,
        ResultCard(
          item: item(ResultState.downloaded, bytes: 1536),
          onOpen: () => opens++,
        ),
      );
      expect(find.text(Content.resultDownloaded), findsOneWidget);
      expect(find.text('PDF · 1.5 Ko'), findsOneWidget);
      expect(find.text(Content.resultOpen), findsOneWidget);
      expect(find.text(Content.resultDownload), findsNothing);
      expect(
        find.bySemanticsLabel(Content.openResult('rapport.pdf')),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, Content.resultOpen));
      expect(opens, 1);
      semantics.dispose();
    },
  );

  testWidgets('taille inconnue : type seul, aucune taille inventée', (
    tester,
  ) async {
    await show(tester, ResultCard(item: item(ResultState.downloaded)));
    expect(find.text('PDF'), findsOneWidget);
    expect(find.textContaining('Ko'), findsNothing);
    expect(find.textContaining('Mo'), findsNothing);
  });

  testWidgets('échec 404 : message clair et réessai, jamais « Téléchargé »', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var retries = 0;
    await show(
      tester,
      ResultCard(
        item: item(ResultState.failed, errorCode: 'result.missing'),
        onDownload: () => retries++,
      ),
    );
    expect(find.text(Content.resultFailed), findsOneWidget);
    expect(find.text(Content.resultMissing), findsOneWidget);
    expect(find.text(Content.resultDownloaded), findsNothing);
    expect(find.text(Content.resultRetry), findsOneWidget);
    expect(
      find.bySemanticsLabel(Content.retryResult('rapport.pdf')),
      findsOneWidget,
    );
    final live = tester.getSemantics(
      find.bySemanticsLabel(
        '${Content.resultFailed}. ${Content.resultMissing}',
      ),
    );
    expect(live.flagsCollection.isLiveRegion, isTrue);
    await tester.tap(find.widgetWithText(FilledButton, Content.resultRetry));
    expect(retries, 1);
    semantics.dispose();
  });

  testWidgets('interrompu : état « Échec — interrompu » et réessai', (
    tester,
  ) async {
    await show(tester, ResultCard(item: item(ResultState.interrupted)));
    expect(find.text(Content.resultInterrupted), findsOneWidget);
    expect(find.text(Content.resultRetry), findsOneWidget);
    expect(find.text(Content.resultDownloaded), findsNothing);
  });

  testWidgets('téléchargement : état live, aucune action contradictoire', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await show(tester, ResultCard(item: item(ResultState.downloading)));
    expect(find.text(Content.resultDownloading), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(Content.resultDownloading))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets(
    'hors connexion : action désactivée, carte et message conservés',
    (tester) async {
      await show(
        tester,
        ResultCard(
          item: item(ResultState.available),
          canDownload: false,
          blockedReason: Content.resultOffline,
          onDownload: () => fail('Aucun téléchargement hors connexion'),
        ),
      );
      expect(find.text(Content.resultOffline), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, Content.resultDownload),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('serveur sans téléchargement : raison affichée', (tester) async {
    await show(
      tester,
      ResultCard(
        item: item(ResultState.available),
        canDownload: false,
        blockedReason: Content.resultUnavailable,
      ),
    );
    expect(find.text(Content.resultUnavailable), findsOneWidget);
  });

  testWidgets('texte 200 % et largeur étroite : aucune troncature critique', (
    tester,
  ) async {
    await show(
      tester,
      ResultCard(item: item(ResultState.downloaded, bytes: 2000000)),
      scale: 2,
      size: const Size(320, 700),
    );
    expect(find.text(Content.resultDownloaded), findsOneWidget);
    expect(find.textContaining('Mo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('échec hors résultat : message générique, jamais celui d’un '
      'autre domaine', (tester) async {
    await show(
      tester,
      ResultCard(
        item: item(ResultState.failed, errorCode: 'transport.unreachable'),
      ),
    );
    expect(find.text(Content.resultUnknown), findsOneWidget);
    expect(find.text(Content.error('transport.unreachable')), findsNothing);
    expect(find.text(Content.resultRetry), findsOneWidget);
  });

  test('taille : arrondi sous le mégaoctet sans « 1024.0 Ko »', () {
    expect(Content.resultSize(1024 * 1024 - 1), '1.0 Mo');
    expect(Content.resultSize(1024), '1.0 Ko');
    expect(Content.resultSize(1024 * 1024), '1.0 Mo');
  });
}
