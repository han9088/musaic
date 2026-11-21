import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/app_icon_service.dart';
import '../../storage/settings/manual_rotation_preference.dart';
import 'app_icon_picker.dart';
import 'fullscreen_control.dart';

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({
    super.key,
    required this.icons,
    this.manualRotation,
  });

  final AppIconService icons;
  final ManualRotationPreference? manualRotation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (manualRotation case final rotation?)
        SignalBuilder(
          builder: (context) => SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            secondary: const Icon(
              PhosphorIcons.deviceRotate,
              color: Colors.white70,
            ),
            title: Text(AppLocalizations.of(context).settingsShowLayoutSwitch),
            subtitle: Text(
              AppLocalizations.of(context).settingsShowLayoutSwitchDescription,
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
