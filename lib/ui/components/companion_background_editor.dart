import 'package:flutter/material.dart';

import '../../models/companion_background.dart';
import '../content.dart';
import '../tokens.dart';
import 'companion_backdrop.dart';
import 'rabbit_companion.dart';

String companionPaletteLabel(CompanionPalette palette) => switch (palette) {
  CompanionPalette.lavenderPeach => Content.lavenderPeach,
  CompanionPalette.mintSky => Content.mintSky,
  CompanionPalette.roseLilac => Content.roseLilac,
};

class CompanionBackgroundEditor extends StatefulWidget {
  const CompanionBackgroundEditor({
    super.key,
    required this.initialPalette,
    required this.onApply,
  });
  final CompanionPalette initialPalette;
  final Future<void> Function(CompanionPalette) onApply;
  @override
  State<CompanionBackgroundEditor> createState() =>
      _CompanionBackgroundEditorState();
}

class _CompanionBackgroundEditorState extends State<CompanionBackgroundEditor> {
  late CompanionPalette _palette = widget.initialPalette;
  bool _saving = false;
  bool _error = false;
  bool _paused = false;
  Future<void> _apply() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = false;
    });
    try {
      await widget.onApply(_palette);
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: const Text(Content.backgroundTitle),
        automaticallyImplyLeading: !_saving,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            const Text(Content.backgroundPreview),
            const SizedBox(height: Spacing.sm),
            Center(
              child: CompanionBackdrop(
                palette: _palette,
                child: RabbitCompanion(
                  name: Content.companionName,
                  paused: _paused,
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, RabbitTokens.minimum),
              ),
              onPressed: () => setState(() => _paused = !_paused),
              child: Text(
                _paused ? Content.resumeCompanion : Content.pauseCompanion,
              ),
            ),
            for (final palette in CompanionPalette.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: MergeSemantics(
                  child: Semantics(
                    selected: _palette == palette,
                    liveRegion: _palette == palette,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, RabbitTokens.minimum),
                      ),
                      onPressed: _saving
                          ? null
                          : () => setState(() => _palette = palette),
                      child: Text(
                        '${companionPaletteLabel(palette)}${_palette == palette ? ' — ${Content.backgroundSelected}' : ''}',
                      ),
                    ),
                  ),
                ),
              ),
            if (_error)
              Semantics(
                liveRegion: true,
                child: const Text(Content.backgroundSaveError),
              ),
            if (_saving)
              Semantics(
                liveRegion: true,
                child: const Text(Content.backgroundSaving),
              ),
            const SizedBox(height: Spacing.sm),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, RabbitTokens.minimum),
              ),
              onPressed: _saving ? null : _apply,
              child: Text(
                _error ? Content.backgroundRetry : Content.backgroundApply,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, RabbitTokens.minimum),
              ),
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text(Content.backgroundCancel),
            ),
          ],
        ),
      ),
    ),
  );
}
