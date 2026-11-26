import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../artwork/presentation/album_color_family.dart';
import '../../services/music/music_source_controller.dart';
import '../../storage/settings/app_language_preference.dart';
import '../../ui/bottom_sheet/bottom_sheet.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/app_color_palette.dart';
import '../../ui/widgets/app_dropdown_menu.dart';
import '../../ui/widgets/app_selection_dot.dart';
import '../../ui/widgets/settings_section_heading.dart';
import '../music/presentation/music_source_picker.dart';
import 'settings_support_section.dart';

enum SettingsSection {
  pro,
  musicSource,
  music,
  system,
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
    this.language,
    this.colorIndex,
    this.colorOrganizeEnabled,
    this.selectedColorFamily,
    this.onColorOrganizeChanged,
    this.onColorFamilySelected,
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
  final AppLanguagePreference? language;
  final AlbumColorFamilyIndex? colorIndex;
  final ValueListenable<bool>? colorOrganizeEnabled;
  final ValueListenable<AlbumColorFamily?>? selectedColorFamily;
  final ValueChanged<bool>? onColorOrganizeChanged;
  final ValueChanged<AlbumColorFamily?>? onColorFamilySelected;

  Widget _section(IconData icon, String title, SettingsSection section) =>
      Builder(
        builder: (origin) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(
            PhosphorIcons.caretUp,
            size: settingsItemArrowSize,
          ),
          onTap: () => onOpenSection(origin, section),
        ),
      );

  Widget _languageSetting(AppLanguagePreference preference) => SignalBuilder(
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AppDropdownMenu<AppLanguage>(
        leading: const Icon(PhosphorIcons.translate),
        title: l10n.settingsLanguage,
        value: preference.selected.value,
        entries: [
          AppDropdownMenuEntry(
            AppLanguage.system,
            l10n.settingsLanguageSystem,
            keywords: 'System default 跟随系统',
          ),
          const AppDropdownMenuEntry(
            AppLanguage.simplifiedChinese,
            '简体中文',
            keywords: 'Simplified Chinese zh Hans',
          ),
          const AppDropdownMenuEntry(
            AppLanguage.english,
            'English',
            keywords: '英文 英语 en',
          ),
        ],
        onSelected: preference.select,
        searchLabel: l10n.settingsLanguageSearch,
        emptyLabel: l10n.settingsLanguageNoResults,
      );
    },
  );

  Widget _colorOrganizationControls() {
    final index = colorIndex;
    final enabled = colorOrganizeEnabled;
    final onChanged = onColorOrganizeChanged;
    final selected = selectedColorFamily;
    final onSelect = onColorFamilySelected;
    if (index == null || enabled == null || onChanged == null) {
      return const SizedBox.shrink();
    }
    return SettingsInteractionTheme(
      child: AnimatedBuilder(
        animation: index,
        builder: (context, _) {
          final families = index.availableFamilies;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: enabled,
                builder: (_, value, __) => SwitchListTile(
                  key: const ValueKey('album-color-organize-toggle'),
                  secondary: const Icon(
                    PhosphorIcons.palette,
                    color: Colors.white70,
                  ),
                  title: const Text('按色系整理画布'),
                  subtitle: const Text(
                    '将主题色相近的专辑集中排列',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  value: value,
                  onChanged: onChanged,
                ),
              ),
              if (selected != null && onSelect != null)
                ValueListenableBuilder<bool>(
                  valueListenable: enabled,
                  builder: (_, isEnabled, __) {
                    if (!isEnabled || families.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        settingsContentInset,
                        0,
                        settingsContentInset,
                        12,
                      ),
                      child: ValueListenableBuilder<AlbumColorFamily?>(
                        valueListenable: selected,
                        builder: (_, current, __) =>
                            AppColorPalette<AlbumColorFamily?>(
                              selection: current,
                              onSelected: onSelect,
                              swatches: [
                                const (
                                  value: null,
                                  label: '显示全部色系',
                                  fill: BoxDecoration(
                                    gradient: SweepGradient(
                                      colors: [
                                        Color(0xffe34b4b),
                                        Color(0xffe5a33b),
                                        Color(0xffe4d34a),
                                        Color(0xff59a96a),
                                        Color(0xff45aeb0),
                                        Color(0xff477bd0),
                                        Color(0xff9368c5),
                                        Color(0xffe34b4b),
                                      ],
                                    ),
                                  ),
                                ),
                                for (final family in families)
                                  (
                                    value: family,
                                    label: family.label,
                                    fill: BoxDecoration(
                                      color: family.isNeutral
                                          ? const Color(0xff888888)
                                          : HSLColor.fromAHSL(
                                              1,
                                              family.hue,
                                              0.62,
                                              0.52,
                                            ).toColor(),
                                    ),
                                  ),
                              ],
                            ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                MusicSourcePicker(
                                  sources: controller,
                                  sourceSwitching: sourceSwitching,
                                  onSourceSelection: onSourceSelection,
                                  demoOnly: true,
                                ),
                                _colorOrganizationControls(),
                              ],
                            ),
                          ),
                        BottomSheetScrollView(
                          child: SettingsInteractionTheme(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _section(
                                  PhosphorIcons.crownSimple,
                                  l10n.settingsPro,
                                  SettingsSection.pro,
                                ),
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
                                              title: AppSelectionTitle(
                                                selected: enabled,
                                                child: Text(l10n.xeroxMode),
                                              ),
                                              selected: enabled,
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
                                    PhosphorIcons.rss,
                                    l10n.musicSource,
                                    SettingsSection.musicSource,
                                  ),
                                SettingsSectionHeading(l10n.settingsAppearance),
                                if (language case final preference?)
                                  _languageSetting(preference),
                                _section(
                                  PhosphorIcons.musicNoteSimple,
                                  l10n.settingsMusic,
                                  SettingsSection.music,
                                ),
                                _section(
                                  PhosphorIcons.monitor,
                                  l10n.settingsSystem,
                                  SettingsSection.system,
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
    return Theme(
      data: buildSettingsContentTheme(Theme.of(context)),
      child: content,
    );
  }
}
