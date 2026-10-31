import 'package:flutter/material.dart';

import '../../models/result.dart';
import '../../models/timeline.dart';
import '../content.dart';
import '../tokens.dart';
import 'status_label.dart';

/// Fichier produit par Hermes : nom, type et taille connus, état dit par un
/// libellé. Télécharger et ouvrir restent deux actions distinctes ; aucune
/// n'est déclenchée sans appui.
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.item,
    this.canDownload = true,
    this.blockedReason,
    this.onDownload,
    this.onOpen,
  });

  final ResultItem item;

  /// Faux hors connexion ou quand le serveur ne propose pas le téléchargement.
  final bool canDownload;

  /// Explique pourquoi le téléchargement est désactivé ; jamais un succès.
  final String? blockedReason;
  final VoidCallback? onDownload;
  final VoidCallback? onOpen;

  static IconData icon(ResultState state) => switch (state) {
    ResultState.available => Icons.download_outlined,
    ResultState.downloading => Icons.downloading,
    ResultState.downloaded => Icons.check_circle_outline,
    ResultState.failed => Icons.error_outline,
    ResultState.interrupted => Icons.sync_problem,
  };

  bool get _canRetry =>
      item.state == ResultState.available ||
      item.state == ResultState.failed ||
      item.state == ResultState.interrupted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final type = Content.resultType(item.mediaType);
    final size = item.bytes == null ? null : Content.resultSize(item.bytes!);
    final meta = [type, ?size].where((value) => value.isNotEmpty).join(' · ');
    final error = item.state == ResultState.failed
        ? Content.resultError(item.errorCode ?? 'result.unavailable')
        : null;
    final action = _action();
    final disabledReason = _canRetry && !canDownload ? blockedReason : null;
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
                Content.resultTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.muted,
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AttachmentTokens.preview,
                  height: AttachmentTokens.preview,
                  decoration: BoxDecoration(
                    color: scheme.bubbleSurface,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: scheme.line),
                  ),
                  child: Icon(
                    switch (item.state) {
                      ResultState.downloaded => Icons.description_outlined,
                      _ => Icons.insert_drive_file_outlined,
                    },
                    size: IconSizes.sm,
                    color: scheme.muted,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.content,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.muted,
                          ),
                        ),
                      const SizedBox(height: Spacing.xs),
                      Semantics(
                        container: true,
                        liveRegion: true,
                        label: error == null
                            ? Content.resultStatus(item.state)
                            : '${Content.resultStatus(item.state)}. $error',
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusLabel(
                              icon: icon(item.state),
                              label: Content.resultStatus(item.state),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: Spacing.xs),
                              Text(
                                error,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.content,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (disabledReason != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                disabledReason,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Spacing.sm),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [action],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _action() => switch (item.state) {
    ResultState.available => _ResultAction(
      label: Content.resultDownload,
      semantics: Content.downloadResult(item.name),
      onPressed: canDownload ? onDownload : null,
    ),
    ResultState.failed || ResultState.interrupted => _ResultAction(
      label: Content.resultRetry,
      semantics: Content.retryResult(item.name),
      onPressed: canDownload ? onDownload : null,
    ),
    ResultState.downloaded => _ResultAction(
      label: Content.resultOpen,
      semantics: Content.openResult(item.name),
      onPressed: onOpen,
    ),
    ResultState.downloading => null,
  };
}

/// Action de la carte : nom accessible distinct et cible d'au moins
/// [Layout.touchTarget].
class _ResultAction extends StatelessWidget {
  const _ResultAction({
    required this.label,
    required this.semantics,
    required this.onPressed,
  });
  final String label;
  final String semantics;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(Layout.touchTarget, Layout.touchTarget),
      ),
      onPressed: onPressed,
      child: Semantics(
        label: semantics,
        child: ExcludeSemantics(child: Text(label)),
      ),
    );
  }
}
