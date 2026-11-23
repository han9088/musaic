import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../storage/settings/usage_guide_preference.dart';

class DeveloperOptionsSettings extends StatefulWidget {
  const DeveloperOptionsSettings({super.key});

  @override
  State<DeveloperOptionsSettings> createState() =>
      _DeveloperOptionsSettingsState();
}

enum _ResetResult { success, failure }

class _DeveloperOptionsSettingsState extends State<DeveloperOptionsSettings> {
  bool _resetting = false;
  _ResetResult? _result;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = switch (_result) {
      null => l10n.developerResetDemosDescription,
      _ResetResult.success => l10n.developerResetDemosDone,
      _ResetResult.failure => l10n.developerResetDemosFailed,
    };
    return ListTile(
      leading: const Icon(PhosphorIcons.arrowCounterClockwise),
      title: Text(l10n.developerResetDemos),
      subtitle: Semantics(
        liveRegion: true,
        child: Text(subtitle, style: const TextStyle(color: Colors.white60)),
      ),
      enabled: !_resetting,
      onTap: _resetDemos,
    );
  }
}
