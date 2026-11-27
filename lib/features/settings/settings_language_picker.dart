import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../storage/settings/app_language_preference.dart';
import '../../ui/widgets/app_dropdown_menu.dart';

class SettingsLanguagePicker extends StatelessWidget {
  const SettingsLanguagePicker({
    super.key,
    required this.preference,
    this.showSelectedLabel = true,
  });

  final AppLanguagePreference preference;
  final bool showSelectedLabel;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AppDropdownMenu<AppLanguage>(
        leading: const Icon(PhosphorIcons.translate),
        title: l10n.settingsLanguage,
        value: preference.selected.value,
        showSelectedLabel: showSelectedLabel,
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
}
