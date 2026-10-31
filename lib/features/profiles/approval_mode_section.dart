import 'package:flutter/material.dart';

import '../../models/connection_gateway.dart';
import '../../models/profile.dart';
import '../../models/timeline.dart';
import '../../ui/components/status_label.dart';
import '../../ui/content.dart';
import '../../ui/tokens.dart';

/// Mode d'autorisation d'un profil, lu sur Hermes. Le mode affiché est
/// toujours la valeur relue après un changement réussi ; un échec garde
/// l'ancienne valeur et le dit. L'app n'écrit jamais de mode d'elle-même ;
/// passer en `off` demande une confirmation.
class ApprovalModeSection extends StatefulWidget {
  const ApprovalModeSection({
    super.key,
    required this.modes,
    required this.profile,
  });
  final ApprovalModes modes;
  final ProfileKey profile;

  @override
  State<ApprovalModeSection> createState() => _ApprovalModeSectionState();
}

class _ApprovalModeSectionState extends State<ApprovalModeSection> {
  String? _mode;
  bool _loading = true;
  bool _busy = false;
  bool _unreadable = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(ApprovalModeSection old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile) _read();
  }

  Future<void> _read() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    final profile = widget.profile;
    try {
      final mode = await widget.modes.read(profile);
      if (!mounted || profile != widget.profile) return;
      setState(() {
        _mode = mode;
        _unreadable = false;
      });
    } catch (_) {
      if (!mounted || profile != widget.profile) return;
      setState(() {
        _mode = null;
        _unreadable = true;
      });
    } finally {
      if (mounted && profile == widget.profile) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _choose(String mode) async {
    if (_busy || mode == _mode || _unreadable) return;
    if (mode == ApprovalMode.off && !await _confirmOff()) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final profile = widget.profile;
    try {
      final reread = await widget.modes.write(profile, mode);
      if (!mounted || profile != widget.profile) return;
      setState(() => _mode = reread);
    } catch (error) {
      if (!mounted || profile != widget.profile) return;
      // Hermes a pu changer le mode (écriture faite, relecture perdue) :
      // relire, pour n'afficher que sa valeur ou « Mode illisible ».
      final failure = error is RpcError
          ? Content.approvalModeRefused
          : Content.approvalModeUnconfirmed;
      await _read();
      if (mounted && profile == widget.profile) {
        setState(() => _failure = failure);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmOff() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Content.approvalModeOffTitle),
        content: const Text(Content.approvalModeOffWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(Content.approvalModeCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(Content.approvalModeOffConfirm),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = !_loading && !_busy && !_unreadable;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                Content.approvalModes,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (_loading || _busy) ...[
              const SizedBox(height: Spacing.sm),
              const LinearProgressIndicator(),
            ],
            if (_unreadable && !_loading) ...[
              const SizedBox(height: Spacing.sm),
              Semantics(
                liveRegion: true,
                child: const StatusLabel(
                  icon: Icons.sync_problem,
                  label: Content.approvalModeUnreadable,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      Layout.touchTarget,
                      Layout.touchTarget,
                    ),
                  ),
                  onPressed: _read,
                  child: const Text(Content.approvalModeRetry),
                ),
              ),
            ],
            const SizedBox(height: Spacing.sm),
            for (final mode in ApprovalMode.values)
              _ModeTile(
                mode: mode,
                selected: !_unreadable && mode == _mode,
                onTap: enabled ? () => _choose(mode) : null,
              ),
            if (_failure != null) ...[
              const SizedBox(height: Spacing.xs),
              Semantics(
                liveRegion: true,
                child: Text(
                  _failure!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Option de mode : choix exclusif, état dit par l'icône et la sémantique ;
/// la confirmation de `off` est présentée au moment du choix.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  final String mode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Un seul nœud : l'option, son nom et son état coché.
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        selected: selected,
        checked: selected,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          minTileHeight: Layout.touchTarget,
          enabled: onTap != null,
          selected: selected,
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? scheme.accent : null,
          ),
          title: Text(Content.approvalModeName(mode)),
          onTap: onTap,
        ),
      ),
    );
  }
}
