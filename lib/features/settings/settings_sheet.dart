import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../storage/settings/app_language_preference.dart';
import '../../ui/bottom_sheet/bottom_sheet.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/app_selection_dot.dart';
import '../../ui/widgets/settings_section_heading.dart';
import 'settings_language_picker.dart';
import 'settings_support_section.dart';

part 'desktop_settings_split_view.dart';

const _proIconColor = Color.fromARGB(255, 195, 153, 68);

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
    required this.musicSourceVisible,
    required this.onOpenSection,
    required this.usageGuideVisible,
    required this.developerOptionsEnabled,
    this.desktop = false,
    this.keyboardShortcutsVisible = false,
    this.xeroxEnabled,
    this.onXeroxChanged,
    this.xeroxPalettePicker,
    this.language,
    this.musicAccount,
  });

  final bool musicSourceVisible;
  final PageRoute<void>? Function(BuildContext, SettingsSection) onOpenSection;
  final ReadonlySignal<bool> usageGuideVisible;
  final ReadonlySignal<bool> developerOptionsEnabled;
  final bool desktop;
  final bool keyboardShortcutsVisible;
  final ValueListenable<bool>? xeroxEnabled;
  final ValueChanged<bool>? onXeroxChanged;
  final Widget? xeroxPalettePicker;
  final AppLanguagePreference? language;
  final ({Widget icon, Widget page})? musicAccount;

  Widget _section(IconData icon, String title, SettingsSection section) =>
      Builder(
        builder: (origin) => ListTile(
          leading: Icon(
            icon,
            color: section == SettingsSection.pro ? _proIconColor : null,
          ),
          title: Text(title),
          trailing: const Icon(
            PhosphorIcons.caretUp,
            size: settingsItemArrowSize,
          ),
          onTap: () => onOpenSection(origin, section),
        ),
      );

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
    if (musicSourceVisible)
      buildSection(
        PhosphorIcons.rss,
        l10n.musicSource,
        SettingsSection.musicSource,
      ),
    SettingsSectionHeading(
      l10n.settingsAppearance,
      horizontalPadding: sidebarInset ?? settingsContentInset,
    ),
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
    if (language case final preference?)
      if (sidebarInset == null)
        SettingsLanguagePicker(preference: preference)
      else
        ListTileTheme.merge(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: EdgeInsets.symmetric(horizontal: sidebarInset),
          minLeadingWidth: 18,
          horizontalTitleGap: 10,
          child: SettingsLanguagePicker(
            preference: preference,
            showSelectedLabel: false,
          ),
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

  Widget _settingsPage(AppLocalizations l10n) => desktop
      ? _DesktopSettingsSplitView(sheet: this)
      : BottomSheetScrollView(
          child: SettingsInteractionTheme(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _settingsItems(l10n, buildSection: _section),
            ),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = musicAccount;
    final settings = _settingsPage(l10n);
    return Theme(
      data: buildSettingsContentTheme(Theme.of(context)),
      child: account == null ? settings : _withAccount(l10n, settings, account),
    );
  }

  Widget _withAccount(
    AppLocalizations l10n,
    Widget settings,
    ({Widget icon, Widget page}) account,
  ) {
    final tabBar = TabBar(
      isScrollable: false,
      indicatorColor: Colors.transparent,
      automaticIndicatorColorAdjustment: false,
      dividerColor: Colors.transparent,
      labelColor: AppColors.settingsAccent,
      unselectedLabelColor: const Color(0xFF9CA3AF),
      tabs: [
        Tab(
          height: 48,
          icon: Icon(
            PhosphorIcons.gearBold,
            size: 22,
            semanticLabel: l10n.settings,
          ),
        ),
        Tab(height: 48, icon: account.icon),
      ],
    );
    return DefaultTabController(
      length: 2,
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
                    child: TabBarView(children: [settings, account.page]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
