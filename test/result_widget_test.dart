import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/features/conversation/draft_view.dart';
import 'package:hermes_mobile/features/conversation/draft_view_model.dart';
import 'package:hermes_mobile/features/profiles/profile_accents.dart';
import 'package:hermes_mobile/models/app_error.dart';
import 'package:hermes_mobile/models/draft.dart';
import 'package:hermes_mobile/models/profile.dart';
import 'package:hermes_mobile/models/result.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/content.dart';

import 'support/connection_fakes.dart';

class _MemoryResults extends MemoryConversation implements ResultGateway {
  final downloads = <String>[];
  final opens = <String>[];
  AppError? openError;

  @override
  Future<void> downloadResult(TimelineKey key, String resultKey) async {
    downloads.add(resultKey);
  }

  @override
  Future<void> openResult(TimelineKey key, String resultKey) async {
    if (openError != null) throw openError!;
    opens.add(resultKey);
  }
}

const _activityKey = 'evt-1';
final _resultKey = ResultKey.of(_activityKey);

class _Harness {
  _Harness(
    this.h,
    this.outbox,
    this.conversation,
    this.timelineKey,
    this.draftKey,
  );

  final Harness h;
  final MemoryOutbox outbox;
  final _MemoryResults conversation;
  final TimelineKey timelineKey;
  final DraftKey draftKey;

  static Future<_Harness> create({
    ResultState state = ResultState.available,
    String body = '',
  }) async {
    final h = Harness();
    await h.connect();
    final outbox = MemoryOutbox();
    const draftKey = DraftKey('d-r');
    final connection = h.repository.snapshot.connection!.key;
    final profile = const ProfileKey('default');
    outbox.drafts[draftKey] = Draft(
      key: draftKey,
      connection: connection,
      profile: profile,
      body: body,
      storedSessionId: 's-1',
    );
    final conversation = _MemoryResults();
    final timelineKey = TimelineKey(connection, profile, 's-1');
    conversation.set(
      timelineKey,
      TimelineProjection(
        items: [
          const ActivityItem(
            1,
            ActivityKind.fileCreate,
            toolId: 'W',
            started: true,
            completed: true,
            eventKey: _activityKey,
            details: {
              'name': 'write_file',
              'args': {'path': '/home/u/rapport.pdf'},
            },
          ),
          ResultItem(
            1,
            resultKey: _resultKey,
            path: '/home/u/rapport.pdf',
            name: 'rapport.pdf',
            mediaType: 'application/pdf',
            bytes: state == ResultState.downloaded ? 2048 : null,
            localKey: _resultKey,
            state: state,
          ),
        ],
        workState: WorkState.succeeded,
        turns: 1,
        userTurns: 1,
      ),
    );
    return _Harness(h, outbox, conversation, timelineKey, draftKey);
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DraftView(
          create: () => DraftViewModel(
            outbox: outbox,
            gateway: h.repository,
            conversation: conversation,
            results: conversation,
            key: draftKey,
          ),
          accents: ProfileAccents(h.repository),
        ),
      ),
    );
    await pumpFrames(tester);
  }
}

/// Laisse le chargement du brouillon et du fil se terminer sans dépendre
/// d'une animation qui ne s'arrête pas.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets(
    'la carte du fil télécharge par le view model et n’affiche pas la mention '
    'de chemin non récupérable',
    (tester) async {
      final lib = await _Harness.create();
      await lib.pump(tester);

      expect(find.text(Content.resultTitle), findsOneWidget);
      expect(find.text('rapport.pdf'), findsOneWidget);
      expect(find.text(Content.activityPathUnavailable), findsNothing);
      expect(find.text(Content.resultDownload), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, Content.resultDownload),
      );
      await pumpFrames(tester);
      expect(lib.conversation.downloads, [_resultKey]);
    },
  );

  testWidgets(
    'échec d’ouverture : le message de résultat reste seul, sans « brouillon '
    'conservé »',
    (tester) async {
      final lib = await _Harness.create(
        state: ResultState.downloaded,
        body: 'texte encore là',
      );
      lib.conversation.openError = const AppError('result.open');
      await lib.pump(tester);

      await tester.tap(find.widgetWithText(FilledButton, Content.resultOpen));
      await pumpFrames(tester);

      expect(find.text(Content.error('result.open')), findsOneWidget);
      expect(find.textContaining(Content.draftKept), findsNothing);
      expect(lib.conversation.opens, isEmpty);
    },
  );
}
