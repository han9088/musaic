import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/app_icon_service.dart';
import '../../storage/settings/manual_rotation_preference.dart';
import 'app_icon_picker.dart';
import 'fullscreen_control.dart';

class AppearanceSettings extends StatefulWidget {
  const AppearanceSettings({
    super.key,
    required this.icons,
    required this.xeroxEnabled,
    required this.onXeroxChanged,
    required this.xeroxPalettePicker,
    this.manualRotation,
  });

  final AppIconService icons;
  final bool xeroxEnabled;
  final FutureOr<bool> Function(bool enabled)? onXeroxChanged;
  final Widget? xeroxPalettePicker;
  final ManualRotationPreference? manualRotation;

  @override
  State<AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {
  late bool _xeroxEnabled = widget.xeroxEnabled;
  bool _xeroxPending = false;

  Future<void> _toggleXerox() async {
    setState(() => _xeroxPending = true);
    try {
      final applied = await widget.onXeroxChanged!(!_xeroxEnabled);
      if (mounted) _xeroxEnabled = applied;
    } finally {
      if (mounted) setState(() => _xeroxPending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.manualRotation case final rotation?)
        SignalBuilder(
          builder: (context) => SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            secondary: const Icon(
              PhosphorIcons.deviceRotate,
              color: Colors.white70,
            ),
            title: Text(AppLocalizations.of(context).settingsManualRotation),
            value: rotation.enabled.value,
            onChanged: rotation.setEnabled,
          ),
        ),
      if (widget.onXeroxChanged != null)
        ListTile(
          key: const ValueKey('xerox-toggle'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          selected: _xeroxEnabled,
          leading: const Icon(PhosphorIcons.printer),
          title: Text(AppLocalizations.of(context).xeroxMode),
          trailing: _xeroxPending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : _xeroxEnabled
              ? const Icon(PhosphorIcons.check)
              : null,
          onTap: _xeroxPending ? null : _toggleXerox,
        ),
      if (widget.xeroxPalettePicker case final picker? when _xeroxEnabled)
        picker,
      if (kIsWeb) const FullscreenControl(),
      AppIconPicker(icons: widget.icons),
    ],
  );
}
