import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/music/music_source_controller.dart';
import '../../ui/bottom_sheet/bottom_sheet.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/settings_section_heading.dart';
import '../music/presentation/music_source_picker.dart';
import 'settings_support_section.dart';

enum SettingsSection { musicSource, appearance, about }

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.sources,
    required this.sourceSwitching,
    required this.onSourceSelection,
    required this.onOpenSection,
    this.xeroxEnabled,
    this.onXeroxChanged,
    this.xeroxPalettePicker,
  });

  final MusicSourceController? sources;
  final ValueListenable<bool>? sourceSwitching;
  final Future<void> Function(Future<void> Function()) onSourceSelection;
  final void Function(BuildContext, SettingsSection) onOpenSection;
  final ValueListenable<bool>? xeroxEnabled;
  final ValueChanged<bool>? onXeroxChanged;
  final Widget? xeroxPalettePicker;

  Widget _section(IconData icon, String title, [SettingsSection? section]) =>
      Builder(
        builder: (origin) => ListTile(
          iconColor: Colors.white70,
          textColor: Colors.white,
          leading: Icon(icon),
          title: Text(title),
          trailing: section == null
              ? null
              : const Icon(PhosphorIcons.caretUp, size: settingsItemArrowSize),
          onTap: section == null ? null : () => onOpenSection(origin, section),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = sources;
    final tabBar = TabBar(
      isScrollable: false,
      indicatorColor: Colors.transparent,
      automaticIndicatorColorAdjustment: false,
      dividerColor: Colors.transparent,
      labelColor: Colors.white,
      unselectedLabelColor: const Color(0xFF9CA3AF),
      tabs: [
        if (controller != null)
          Tab(
            height: 48,
            icon: Icon(
              PhosphorIcons.slideshowBold,
              size: 22,
              semanticLabel: l10n.musicSourceDemoGroup,
            ),
          ),
        Tab(
          height: 48,
          icon: Icon(
            PhosphorIcons.gearBold,
            size: 22,
            semanticLabel: l10n.settings,
          ),
        ),
      ],
    );
    final content = DefaultTabController(
      length: controller == null ? 1 : 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabBarHeight = tabBar.preferredSize.height;
          final fits = constraints.maxHeight >= tabBarHeight;
          return Visibility(
            visible: fits,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: fits ? constraints.maxHeight : tabBarHeight,
              child: Column(
                children: [
                  Material(color: Colors.transparent, child: tabBar),
                  Expanded(
                    child: TabBarView(
                      children: [
                        if (controller != null)
                          BottomSheetScrollView(
                            child: MusicSourcePicker(
                              sources: controller,
                              sourceSwitching: sourceSwitching,
                              onSourceSelection: onSourceSelection,
                              demoOnly: true,
                            ),
                          ),
                        BottomSheetScrollView(
                          child: SettingsInteractionTheme(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if ((xeroxEnabled, onXeroxChanged) case (
                                  final mode?,
                                  final onChanged?,
                                ))
                                  ValueListenableBuilder<bool>(
                                    valueListenable: mode,
                                    builder: (context, enabled, picker) =>
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            ListTile(
                                              key: const ValueKey(
                                                'xerox-toggle',
                                              ),
                                              iconColor: Colors.white70,
                                              textColor: Colors.white,
                                              title: Text(l10n.xeroxMode),
                                              selected: enabled,
                                              selectedColor: Colors.white,
                                              trailing: enabled
                                                  ? const Icon(
                                                      PhosphorIcons.check,
                                                      size: 16,
                                                    )
                                                  : null,
                                              onTap: () => onChanged(!enabled),
                                            ),
                                            if (enabled && picker != null)
                                              picker,
                                          ],
                                        ),
                                    child: xeroxPalettePicker,
                                  ),
                                if (controller != null)
                                  _section(
                                    PhosphorIcons.musicNotes,
                                    l10n.musicSource,
                                    SettingsSection.musicSource,
                                  ),
                                _section(
                                  PhosphorIcons.paintBrush,
                                  l10n.settingsAppearance,
                                  SettingsSection.appearance,
                                ),
                                SettingsSectionHeading(
                                  l10n.settingsAboutAndHelp,
                                ),
                                _section(
                                  PhosphorIcons.stethoscope,
                                  l10n.settingsDiagnostics,
                                ),
                                _section(
                                  PhosphorIcons.info,
                                  l10n.settingsAbout,
                                  SettingsSection.about,
                                ),
                                const SettingsSupportSection(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return ListTileTheme.merge(
      contentPadding: settingsItemPadding,
      horizontalTitleGap: settingsItemTitleGap,
      child: content,
    );
  }
}
