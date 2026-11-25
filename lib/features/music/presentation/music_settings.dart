import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../storage/settings/screensaver_delay_preference.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/horizontal_selection_wheel.dart';

class MusicSettings extends StatelessWidget {
  const MusicSettings({super.key, required this.screensaverDelay});

  final ScreensaverDelayPreference screensaverDelay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final foreground =
        theme.listTileTheme.textColor ?? theme.colorScheme.onSurface;
    const options = ScreensaverDelayPreference.options;

    return LayoutBuilder(
      builder: (context, constraints) => ListTile(
        title: Text(l10n.settingsScreensaverDelay),
        trailing: SizedBox(
          width: math.min(
            148,
            math.max(0, constraints.maxWidth - settingsItemPadding.horizontal) *
                0.44,
          ),
          child: Row(
            children: [
              Expanded(
                child: SignalBuilder(
                  builder: (context) => HorizontalSelectionWheel(
                    labels: [for (final seconds in options) '$seconds'],
                    selectedIndex: options.indexOf(
                      screensaverDelay.seconds.value,
                    ),
                    onSettled: (index) =>
                        unawaited(screensaverDelay.select(options[index])),
                    semanticLabel: l10n.settingsScreensaverDelay,
                    semanticValue: (index) =>
                        l10n.settingsScreensaverSeconds(options[index]),
                    textStyle: theme.textTheme.bodyMedium!.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ExcludeSemantics(
                child: Text(
                  l10n.settingsScreensaverSecondsUnit,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
