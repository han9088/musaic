import 'dart:async';

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
import '../../ui/widgets/app_selection_dot.dart';
import '../../ui/widgets/settings_section_heading.dart';
import '../music/presentation/music_source_picker.dart';
import 'settings_language_picker.dart';
import 'settings_support_section.dart';

part 'desktop_settings_split_view.dart';

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
    this.desktop = false,
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
  final PageRoute<void>? Function(BuildContext, SettingsSection) onOpenSection;
  final ReadonlySignal<bool> usageGuideVisible;
  final ReadonlySignal<bool> developerOptionsEnabled;
  final bool desktop;
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

  Widget _demoContent(BuildContext context, MusicSourceController controller) {
    final content = Column(
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
    );
    return desktop
        ? Theme(
            data: buildDesktopSettingsTheme(Theme.of(context)),
            child: content,
          )
        : content;
  }

  Widget? _xeroxSetting(AppLocalizations l10n, {double? sidebarInset}) {
    final mode = xeroxEnabled;
    final onChanged = onXeroxChanged;
    if (mode == null || onChanged == null) return null;
    return ValueListenableBuilder<bool>(
      valueListenable: mode,
      builder: (context, enabled, picker) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            key: const ValueKey('xerox-toggle'),
            dense: desktop ? true : null,
            visualDensity: desktop ? VisualDensity.compact : null,
            contentPadding: sidebarInset == null
                ? null
                : EdgeInsetsDirectional.only(
                    start: sidebarInset,
                    end: settingsContentInset,
                  ),
            title: AppSelectionTitle(
              selected: enabled,
              child: Text(l10n.xeroxMode),
            ),
            selected: enabled,
            onTap: () => onChanged(!enabled),
          ),
          if (enabled && picker != null) picker,
        ],
      ),
      child: xeroxPalettePicker,
    );
  }

  List<Widget> _settingsItems(
    AppLocalizations l10n, {
    required Widget Function(IconData, String, SettingsSection) buildSection,
    double? sidebarInset,
    Widget? support,
  }) => [
    buildSection(
      PhosphorIcons.crownSimple,
      l10n.settingsPro,
      SettingsSection.pro,
    ),
    ?_xeroxSetting(l10n, sidebarInset: sidebarInset),
    if (sources != null)
      buildSection(
        PhosphorIcons.rss,
        l10n.musicSource,
        SettingsSection.musicSource,
      ),
    SettingsSectionHeading(
      l10n.settingsAppearance,
      horizontalPadding: sidebarInset ?? settingsContentInset,
    ),
    if (!desktop)
      if (language case final preference?)
        SettingsLanguagePicker(preference: preference),
    buildSection(
      PhosphorIcons.musicNoteSimple,
      l10n.settingsMusic,
      SettingsSection.music,
    ),
    buildSection(
      PhosphorIcons.monitor,
      l10n.settingsSystem,
      SettingsSection.system,
    ),
    if (keyboardShortcutsVisible)
      buildSection(
        PhosphorIcons.keyboard,
        l10n.settingsKeyboardShortcuts,
        SettingsSection.keyboardShortcuts,
      ),
    SettingsSectionHeading(
      l10n.settingsAboutAndHelp,
      horizontalPadding: sidebarInset ?? settingsContentInset,
    ),
    SignalBuilder(
      builder: (_) => usageGuideVisible.value
          ? buildSection(
              PhosphorIcons.bookOpen,
              l10n.settingsUsageGuide,
              SettingsSection.usageGuide,
            )
          : const SizedBox.shrink(),
    ),
    buildSection(
      PhosphorIcons.stethoscope,
      l10n.settingsDiagnostics,
      SettingsSection.diagnostics,
    ),
    buildSection(PhosphorIcons.info, l10n.settingsAbout, SettingsSection.about),
    if (support == null) const SettingsSupportSection(),
    SignalBuilder(
      builder: (_) => developerOptionsEnabled.value
          ? buildSection(
              PhosphorIcons.code,
              l10n.settingsDeveloperOptions,
              SettingsSection.developerOptions,
            )
          : const SizedBox.shrink(),
    ),
    ?support,
  ];

  List<Widget> _tabPages(BuildContext context, AppLocalizations l10n) => [
    if (sources case final controller?)
      BottomSheetScrollView(child: _demoContent(context, controller)),
    if (desktop)
      _DesktopSettingsSplitView(sheet: this)
    else
      BottomSheetScrollView(
        child: SettingsInteractionTheme(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _settingsItems(l10n, buildSection: _section),
          ),
        ),
      ),
  ];

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
                    child: TabBarView(children: _tabPages(context, l10n)),
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
