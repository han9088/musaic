import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/music/music_source_controller.dart';
import '../../ui/bottom_sheet/bottom_sheet.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/app_selection_dot.dart';
import '../../ui/widgets/settings_section_heading.dart';
import '../music/presentation/music_source_picker.dart';
import 'settings_support_section.dart';

enum SettingsSection {
  musicSource,
  appearance,
  keyboardShortcuts,
  usageGuide,
  diagnostics,
  about,
  developerOptions,
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.sources,
    required this.sourceSwitching,
    required this.onSourceSelection,
    required this.onOpenSection,
    required this.usageGuideVisible,
    required this.developerOptionsEnabled,
    this.keyboardShortcutsVisible = false,
    this.xeroxEnabled,
    this.onXeroxChanged,
    this.xeroxPalettePicker,
  });

  final MusicSourceController? sources;
  final ValueListenable<bool>? sourceSwitching;
  final Future<void> Function(Future<void> Function()) onSourceSelection;
  final void Function(BuildContext, SettingsSection) onOpenSection;
  final ReadonlySignal<bool> usageGuideVisible;
  final ReadonlySignal<bool> developerOptionsEnabled;
  final bool keyboardShortcutsVisible;
  final ValueListenable<bool>? xeroxEnabled;
  final ValueChanged<bool>? onXeroxChanged;
  final Widget? xeroxPalettePicker;

  Widget _section(IconData icon, String title, SettingsSection section) =>
      Builder(
        builder: (origin) => ListTile(
          iconColor: Colors.white70,
          textColor: Colors.white,
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(
            PhosphorIcons.caretUp,
            size: settingsItemArrowSize,
          ),
          onTap: () => onOpenSection(origin, section),
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
      labelColor: AppColors.settingsAccent,
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
                                              title: AppSelectionTitle(
                                                selected: enabled,
                                                child: Text(l10n.xeroxMode),
                                              ),
                                              selected: enabled,
                                              selectedColor: Colors.white,
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
                                    PhosphorIcons.musicNoteSimple,
                                    l10n.musicSource,
                                    SettingsSection.musicSource,
                                  ),
                                _section(
                                  PhosphorIcons.monitor,
                                  l10n.settingsAppearance,
                                  SettingsSection.appearance,
                                ),
                                if (keyboardShortcutsVisible)
                                  _section(
                                    PhosphorIcons.keyboard,
                                    l10n.settingsKeyboardShortcuts,
                                    SettingsSection.keyboardShortcuts,
                                  ),
                                SettingsSectionHeading(
                                  l10n.settingsAboutAndHelp,
                                ),
                                SignalBuilder(
                                  builder: (_) => usageGuideVisible.value
                                      ? _section(
                                          PhosphorIcons.bookOpen,
                                          l10n.settingsUsageGuide,
                                          SettingsSection.usageGuide,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                _section(
                                  PhosphorIcons.stethoscope,
                                  l10n.settingsDiagnostics,
                                  SettingsSection.diagnostics,
                                ),
                                _section(
                                  PhosphorIcons.info,
                                  l10n.settingsAbout,
                                  SettingsSection.about,
                                ),
                                const SettingsSupportSection(),
                                SignalBuilder(
                                  builder: (_) => developerOptionsEnabled.value
                                      ? _section(
                                          PhosphorIcons.code,
                                          l10n.settingsDeveloperOptions,
                                          SettingsSection.developerOptions,
                                        )
                                      : const SizedBox.shrink(),
                                ),
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
