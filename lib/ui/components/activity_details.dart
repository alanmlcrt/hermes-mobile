import 'dart:convert';

import 'package:flutter/material.dart';

import '../content.dart';
import '../tokens.dart';

/// Données reçues en texte/JSON sélectionnable, sans lien ni exécution.
class ActivityDetails extends StatelessWidget {
  const ActivityDetails({super.key, required this.details});
  final Map<String, Object?> details;

  static Map<String, Object> sections(Map<String, Object?> details) {
    Object? present(String key) {
      final value = details[key];
      return value is String && value.trim().isEmpty ? null : value;
    }

    final result = present('result');
    final error = result is Map ? result['error'] : null;
    return {
      Content.detailName: ?present('name'),
      Content.detailContext: ?present('context'),
      Content.detailArguments: ?(details.containsKey('args')
          ? present('args')
          : present('args_text') ?? present('preview')),
      Content.detailOutput: ?(details.containsKey('result')
          ? result
          : present('result_text')),
      Content.detailDiff: ?present('inline_diff'),
      if (error is String && error.trim().isNotEmpty)
        Content.detailError: error,
    };
  }

  static String _text(Object value) => value is String
      ? value
      : const JsonEncoder.withIndent('  ').convert(value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Spacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections(details).entries)
          _DetailSection(
            key: ValueKey(section.key),
            title: section.key,
            text: _text(section.value),
          ),
      ],
    ),
  );
}

class _DetailSection extends StatefulWidget {
  const _DetailSection({super.key, required this.title, required this.text});
  final String title;
  final String text;

  @override
  State<_DetailSection> createState() => _DetailSectionState();
}

class _DetailSectionState extends State<_DetailSection> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Spacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: ActivityTokens.detailHeight,
          ),
          child: SelectionArea(
            child: Scrollbar(
              controller: _vertical,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _vertical,
                primary: false,
                child: Scrollbar(
                  controller: _horizontal,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontal,
                    primary: false,
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: Spacing.sm,
                        bottom: Spacing.sm,
                      ),
                      child: Text(
                        widget.text,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontFamily: ActivityTokens.detailFont),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
