import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/features/conversation/draft_view_model.dart';
import 'package:hermes_mobile/models/connection.dart';
import 'package:hermes_mobile/models/timeline.dart';
import 'package:hermes_mobile/ui/content.dart';

import 'support/connection_fakes.dart';

class _Results implements ResultGateway {
  @override
  Future<void> downloadResult(TimelineKey key, String resultKey) async {}

  @override
  Future<void> openResult(TimelineKey key, String resultKey) async {}
}

void main() {
  test('lien coupé : téléchargement désactivé avec sa raison, carte gardée', () async {
    final h = Harness();
    addTearDown(h.repository.dispose);
    await h.connect();
    final outbox = MemoryOutbox();
    final connection = h.repository.snapshot.connection!.key;
    final profile = h.repository.snapshot.selectedProfile!;
    final draft = await outbox.openContinuation(connection, profile, 's-1');
    final key = TimelineKey(connection, profile, 's-1');
    final conversation = MemoryConversation()
      ..set(
        key,
        const TimelineProjection(
          items: [
            ResultItem(
              1,
              resultKey: 'cle',
              path: '/home/u/rapport.pdf',
              name: 'rapport.pdf',
              mediaType: 'application/pdf',
            ),
          ],
        ),
      );
    final vm = DraftViewModel(
      outbox: outbox,
      gateway: h.repository,
      conversation: conversation,
      key: draft.key,
      results: _Results(),
    );
    addTearDown(vm.dispose);

    Future<void> settle() async {
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        if (vm.draft != null) return;
      }
    }

    await settle();
    expect(vm.canDownloadResult, isTrue);
    expect(vm.resultBlockedReason, isNull);
    expect(vm.timeline.items.whereType<ResultItem>(), hasLength(1));

    await h.transport.sockets.last.drop();
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
      if (h.repository.snapshot.link != LinkState.connected) break;
    }
    expect(h.repository.snapshot.link, isNot(LinkState.connected));
    expect(vm.canDownloadResult, isFalse);
    expect(vm.resultBlockedReason, Content.resultOffline);
    expect(vm.timeline.items.whereType<ResultItem>(), hasLength(1));
  });
}
