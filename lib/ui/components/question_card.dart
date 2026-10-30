import 'package:flutter/material.dart';

import '../../models/timeline.dart';
import '../content.dart';
import '../tokens.dart';
import 'status_label.dart';

/// Question de Hermes dans le fil : texte et choix tels qu'émis (suffixe
/// « (Recommended) » compris), état dit par un libellé. La réponse se saisit
/// ici, jamais dans le composeur ; chaque question exige un texte non vide.
class QuestionCard extends StatefulWidget {
  const QuestionCard({
    super.key,
    required this.questions,
    required this.state,
    this.previousUnanswered = false,
    this.canAnswer = true,
    this.onSubmit,
  });

  final List<ClarifyQuestion> questions;
  final QuestionState state;
  final bool previousUnanswered;

  /// Faux hors connexion : la saisie reste, l'envoi est désactivé.
  final bool canAnswer;
  final ValueChanged<Map<String, String>>? onSubmit;

  static String label(QuestionState state) => switch (state) {
    QuestionState.open => Content.questionOpen,
    QuestionState.sending => Content.questionSending,
    QuestionState.sent => Content.questionSent,
    QuestionState.confirmed => Content.questionConfirmed,
    QuestionState.unknown => Content.questionUnknown,
    QuestionState.expired => Content.questionExpired,
    QuestionState.cancelled => Content.questionCancelled,
    QuestionState.closed => Content.questionClosed,
  };

  static IconData icon(QuestionState state) => switch (state) {
    QuestionState.open => Icons.help_outline,
    QuestionState.sending => Icons.upload_outlined,
    QuestionState.sent => Icons.outbox_outlined,
    QuestionState.confirmed => Icons.check_circle_outline,
    QuestionState.unknown => Icons.sync_problem,
    QuestionState.expired => Icons.timer_off_outlined,
    QuestionState.cancelled => Icons.cancel_outlined,
    QuestionState.closed => Icons.lock_outline,
  };

  /// Réponse d'une question : choix cochés joints par « , », texte libre en
  /// dernier ; choix unique : le texte saisi prime sur le choix.
  static String compose(
    ClarifyQuestion question,
    Set<String> selected,
    String text,
  ) {
    final typed = text.trim();
    final chosen = [
      for (final c in question.choices)
        if (selected.contains(c)) c,
    ];
    if (question.multiSelect) {
      return [...chosen, if (typed.isNotEmpty) typed].join(', ');
    }
    return typed.isNotEmpty ? typed : chosen.firstOrNull ?? '';
  }

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  final _selected = <String, Set<String>>{};
  final _controllers = <String, TextEditingController>{};

  TextEditingController _controller(String qid) =>
      _controllers.putIfAbsent(qid, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _answers => {
    for (final q in widget.questions)
      q.qid: QuestionCard.compose(
        q,
        _selected[q.qid] ?? const {},
        _controller(q.qid).text,
      ),
  };

  bool get _complete => _answers.values.every((a) => a.isNotEmpty);

  void _toggle(ClarifyQuestion q, String choice, bool on) => setState(() {
    final set = _selected.putIfAbsent(q.qid, () => <String>{});
    if (!q.multiSelect) {
      set.clear();
      // Choix unique : ce qui part est ce qui est montré.
      if (on) _controller(q.qid).clear();
    }
    if (on) {
      set.add(choice);
    } else {
      set.remove(choice);
    }
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final open = widget.state == QuestionState.open;
    final complete = _complete;
    final reason = !widget.canAnswer
        ? Content.questionOffline
        : complete
        ? null
        : Content.questionIncomplete;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                Content.questionTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.muted,
                ),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Semantics(
              liveRegion: true,
              child: StatusLabel(
                icon: QuestionCard.icon(widget.state),
                label: QuestionCard.label(widget.state),
              ),
            ),
            if (open && widget.previousUnanswered) ...[
              const SizedBox(height: Spacing.xs),
              Text(Content.questionPreviousUnanswered),
            ],
            for (final (index, q) in widget.questions.indexed) ...[
              const SizedBox(height: Spacing.md),
              SelectableText(
                q.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.content,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (open) ..._inputs(context, q, index),
            ],
            if (open) ...[
              const SizedBox(height: Spacing.md),
              if (reason != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: Text(
                    reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.muted,
                    ),
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: Layout.touchTarget,
                    minWidth: Layout.touchTarget,
                  ),
                  child: FilledButton(
                    onPressed: reason == null && widget.onSubmit != null
                        ? () => widget.onSubmit!(_answers)
                        : null,
                    child: const Text(Content.questionSend),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _inputs(BuildContext context, ClarifyQuestion q, int index) {
    final selected = _selected[q.qid] ?? const {};
    return [
      if (q.choices.isNotEmpty) ...[
        const SizedBox(height: Spacing.sm),
        if (q.multiSelect)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Text(
              Content.questionMultiHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final choice in q.choices)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: Layout.touchTarget,
                ),
                child: q.multiSelect
                    ? FilterChip(
                        label: Text(choice),
                        selected: selected.contains(choice),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: (on) => _toggle(q, choice, on),
                      )
                    : ChoiceChip(
                        label: Text(choice),
                        selected: selected.contains(choice),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: (on) => _toggle(q, choice, on),
                      ),
              ),
          ],
        ),
      ],
      const SizedBox(height: Spacing.sm),
      TextField(
        controller: _controller(q.qid),
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: Content.questionFieldLabel(index, widget.questions.length),
        ),
        onChanged: (text) => setState(() {
          if (!q.multiSelect && text.trim().isNotEmpty) {
            _selected[q.qid]?.clear();
          }
        }),
      ),
    ];
  }
}
