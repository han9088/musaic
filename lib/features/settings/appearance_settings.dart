import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/app_icon_service.dart';
import '../../storage/settings/app_language_preference.dart';
import '../../storage/settings/manual_rotation_preference.dart';
import '../../ui/widgets/app_dropdown_menu.dart';
import 'app_icon_picker.dart';
import 'fullscreen_control.dart';

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({
    super.key,
    required this.icons,
    this.language,
    this.manualRotation,
  });

  final AppIconService icons;
  final AppLanguagePreference? language;
  final ManualRotationPreference? manualRotation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (language case final preference?)
        SignalBuilder(
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
        ),
      if (manualRotation case final rotation?)
        SignalBuilder(
          builder: (context) => SwitchListTile(
            secondary: const Icon(
              PhosphorIcons.deviceRotate,
              color: Colors.white70,
            ),
            title: Text(AppLocalizations.of(context).settingsShowLayoutSwitch),
            subtitle: Text(
              AppLocalizations.of(context).settingsShowLayoutSwitchDescription,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            value: rotation.enabled.value,
            onChanged: rotation.setEnabled,
          ),
        ),
      if (kIsWeb) const FullscreenControl(),
      AppIconPicker(icons: icons),
    ],
  );
}
