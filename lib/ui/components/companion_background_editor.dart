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
  CompanionPalette.peachSun => Content.peachSun,
  CompanionPalette.oceanMist => Content.oceanMist,
  CompanionPalette.sageSand => Content.sageSand,
  CompanionPalette.coralRose => Content.coralRose,
  CompanionPalette.pearl => Content.pearl,
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

  /// Pastille seule, sans légende visible : le nom reste annoncé. Fusionnée
  /// pour que le focus clavier et la sémantique désignent la même pastille.
  Widget _swatch(BuildContext context, CompanionPalette palette) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _palette == palette;
    final label = companionPaletteLabel(palette);
    return MergeSemantics(
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _saving ? null : () => setState(() => _palette = palette),
        child: Semantics(
          button: true,
          selected: selected,
          liveRegion: selected,
          label: selected ? '$label — ${Content.backgroundSelected}' : label,
          excludeSemantics: true,
          child: Container(
            width: Layout.swatch,
            height: Layout.swatch,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: paletteGradient(palette),
              border: Border.all(
                color: selected ? scheme.emphasis : scheme.outlineVariant,
                width: selected ? Layout.swatchSelected : Layout.swatchBorder,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, color: RabbitTokens.ink)
                : null,
          ),
        ),
      ),
    );
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
                  size: RabbitTokens.preview,
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
            // Palette prête à l'emploi : pastilles en grille, légende sous
            // chacune ; l'état sélectionné est annoncé, pas seulement coloré.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Spacing.md,
              runSpacing: Spacing.md,
              children: [
                for (final palette in CompanionPalette.values)
                  _swatch(context, palette),
              ],
            ),
            const SizedBox(height: Spacing.md),
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
