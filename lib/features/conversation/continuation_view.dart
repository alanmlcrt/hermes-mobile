import 'package:flutter/material.dart';

import '../../models/connection.dart';
import '../../models/draft.dart';
import '../../models/profile.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';
import '../profiles/profile_accents.dart';
import 'draft_view.dart';
import 'draft_view_model.dart';

/// `/c/<connexion>/<profil>/<session>` : retrouve (ou crée vide) le brouillon de
/// suite de la conversation, puis réutilise la vue de conversation.
class ContinuationView extends StatefulWidget {
  const ContinuationView({
    super.key,
    required this.outbox,
    required this.connection,
    required this.profile,
    required this.session,
    required this.createViewModel,
    required this.accents,
    required this.onHome,
    required this.onHistory,
    required this.onNewConversation,
  });
  final OutboxGateway outbox;
  final ConnectionKey connection;
  final ProfileKey profile;
  final String session;
  final DraftViewModel Function(DraftKey key) createViewModel;
  final ProfileAccents accents;
  final VoidCallback onHome;
  final void Function(ProfileKey profile) onHistory;
  final void Function(ProfileKey profile) onNewConversation;
  @override
  State<ContinuationView> createState() => _ContinuationViewState();
}

class _ContinuationViewState extends State<ContinuationView> {
  static final _cachedDrafts = <(String, String, String), Draft>{};

  (String, String, String) get _cacheKey => (
    widget.connection.value,
    widget.profile.value,
    widget.session,
  );

  late Future<Draft> _draft = _open();

  Future<Draft> _open() async {
    final draft = await widget.outbox.openContinuation(
      widget.connection,
      widget.profile,
      widget.session,
    );
    _cachedDrafts[_cacheKey] = draft;
    DraftViewModel.cacheDraft(draft);
    return draft;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Draft>(
    future: _draft,
    initialData: _cachedDrafts[_cacheKey],
    builder: (context, snapshot) {
      final draft = snapshot.data;
      if (draft != null) {
        DraftViewModel.cacheDraft(draft);
        return DraftView(
          continuation: true,
          create: () => widget.createViewModel(draft.key),
          accents: widget.accents,
          onHome: widget.onHome,
          onHistory: widget.onHistory,
          onNewConversation: widget.onNewConversation,
        );
      }
      final failed = snapshot.hasError;
      return Scaffold(
        appBar: AppBar(title: Text( failed ? Content.timelineTitle : '')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Semantics(
              liveRegion: true,
              label: failed ? null : Content.openingConversation,
              child: failed
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Content.error('storage.unavailable')),
                        TextButton(
                          onPressed: () {
                            final next = _open();
                            setState(() {
                              _draft = next;
                            });
                          },
                          child: const Text(Content.retryList),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
    },
  );
}
