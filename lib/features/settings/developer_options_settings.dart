import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/diagnostics/diagnostic_log.dart';
import '../../storage/settings/usage_guide_preference.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/widgets/app_navigation_back_button.dart';
import '../music/playback/screensaver/screensaver_demo.dart';

class DeveloperOptionsSettings extends StatefulWidget {
  const DeveloperOptionsSettings({super.key});

  @override
  State<DeveloperOptionsSettings> createState() =>
      _DeveloperOptionsSettingsState();
}

enum _ResetResult { success, failure }

class _DeveloperOptionsSettingsState extends State<DeveloperOptionsSettings> {
  static const _talkerTitle = 'Talker DevTool';

  bool _resetting = false;
  bool _previewingScreensaver = false;
  _ResetResult? _result;

  Future<void> _previewScreensaver(bool enabled) async {
    if (!enabled || _previewingScreensaver) return;
    setState(() => _previewingScreensaver = true);
    try {
      await showScreensaverDemo(context);
    } finally {
      if (mounted) setState(() => _previewingScreensaver = false);
    }
  }

  Future<void> _resetDemos() async {
    if (_resetting) return;
    setState(() => _resetting = true);
    var result = _ResetResult.success;
    try {
      await UsageGuidePreference.resetIntros();
    } catch (error) {
      debugPrint('Could not reset usage guide demos: $error');
      result = _ResetResult.failure;
    }
    if (!mounted) return;
    setState(() {
      _resetting = false;
      _result = result;
    });
  }

  void _openTalker() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(
            name: '/settings/developer-options/talker',
          ),
          builder: (context) {
            final theme = Theme.of(context);
            return Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(
                  primaryContainer: AppColors.settingsAccent,
                ),
              ),
              child: TalkerScreen(
                talker: diagnosticLog.talker,
                appBarTitle: _talkerTitle,
                theme: const TalkerScreenTheme(
                  backgroundColor: AppColors.sheetBackground,
                  cardColor: AppColors.sheetHostBackground,
                ),
                appBarLeading: AppNavigationBackButton(
                  icon: PhosphorIcons.caretLeftBold,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = switch (_result) {
      null => l10n.developerResetDemosDescription,
      _ResetResult.success => l10n.developerResetDemosDone,
      _ResetResult.failure => l10n.developerResetDemosFailed,
    };
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(PhosphorIcons.monitor, color: Colors.white70),
          title: Text(l10n.developerScreensaverDemo),
          subtitle: Text(
            l10n.developerScreensaverDemoDescription,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          value: _previewingScreensaver,
          onChanged: _previewScreensaver,
        ),
        ListTile(
          leading: const Icon(PhosphorIcons.arrowCounterClockwise),
          title: Text(l10n.developerResetDemos),
          subtitle: Semantics(
            liveRegion: true,
            child: Text(
              subtitle,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          onTap: _resetting ? null : _resetDemos,
        ),
        ListTile(
          leading: const Icon(PhosphorIcons.bug),
          title: const Text(_talkerTitle),
          onTap: _openTalker,
        ),
      ],
    );
  }
}
