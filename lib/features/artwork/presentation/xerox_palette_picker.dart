import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.xeroxPaperColor,
            style: const TextStyle(color: Colors.white70),
          ),
          ValueListenableBuilder<XeroxPalette>(
            valueListenable: selection,
            builder: (context, current, _) => Wrap(
              children: [
                for (final palette in XeroxPalette.values)
                  Semantics(
                    selected: current == palette,
                    child: IconButton(
                      key: ValueKey(palette),
                      tooltip: switch (palette) {
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
                      onPressed: () => onChanged(palette),
                      icon: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: palette.paper,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.ink, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: current == palette
                            ? Icon(
                                PhosphorIcons.check,
                                size: 16,
                                color: palette.ink,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
