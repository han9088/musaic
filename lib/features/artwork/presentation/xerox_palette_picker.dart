import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/app_color_palette.dart';
import 'xerox_palette.dart';

class XeroxPalettePicker extends StatelessWidget {
  const XeroxPalettePicker({
    super.key,
    required this.selection,
    required this.onChanged,
  });

  final ValueListenable<XeroxPalette> selection;
  final ValueChanged<XeroxPalette> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        settingsContentInset,
        4,
        settingsContentInset,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.xeroxPaperColor,
            style: const TextStyle(color: Colors.white70),
          ),
          ValueListenableBuilder<XeroxPalette>(
            valueListenable: selection,
            builder: (context, current, _) => AppColorPalette<XeroxPalette>(
              selection: current,
              onSelected: onChanged,
              swatches: [
                for (final palette in XeroxPalette.values)
                  (
                    value: palette,
                    label: switch (palette) {
                      XeroxPalette.original => l10n.xeroxPaperOriginal,
                      XeroxPalette.ivory => l10n.xeroxPaperIvory,
                      XeroxPalette.sand => l10n.xeroxPaperSand,
                      XeroxPalette.sage => l10n.xeroxPaperSage,
                      XeroxPalette.mist => l10n.xeroxPaperMist,
                      XeroxPalette.dustyRose => l10n.xeroxPaperDustyRose,
                      XeroxPalette.ochre => l10n.xeroxPaperOchre,
                      XeroxPalette.terracotta => l10n.xeroxPaperTerracotta,
                      XeroxPalette.indigo => l10n.xeroxPaperIndigo,
                      XeroxPalette.celadon => l10n.xeroxPaperCeladon,
                    },
                    fill: BoxDecoration(color: palette.paper),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
