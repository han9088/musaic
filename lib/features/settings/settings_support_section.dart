import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/app_support.dart';
import '../../ui/dialogs/app_notification.dart';
import '../../ui/widgets/settings_section_heading.dart';

class SettingsSupportSection extends StatefulWidget {
  const SettingsSupportSection({super.key});

  @override
  State<SettingsSupportSection> createState() => _SettingsSupportSectionState();
}

class _SettingsSupportSectionState extends State<SettingsSupportSection> {
  bool _sharing = false;

  Future<void> _rate() async {
    final opened = await openMusaicReview();
    if (!opened && mounted) {
      showAppNotification(
        context,
        message: AppLocalizations.of(context).settingsReviewUnavailable,
      );
    }
  }

  Future<void> _share(BuildContext origin) async {
    if (_sharing) return;
    _sharing = true;
    final renderObject = origin.findRenderObject();
    final anchor = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    final result = await shareMusaic(anchor: anchor);
    _sharing = false;
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final message = switch (result) {
      MusaicShareResult.handled => null,
      MusaicShareResult.copied => l10n.settingsShareLinkCopied,
      MusaicShareResult.unavailable => l10n.settingsShareUnavailable,
    };
    if (message != null) showAppNotification(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTileTheme.merge(
      iconColor: Colors.white70,
      textColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSectionHeading(l10n.settingsSupport),
          ListTile(
            leading: const Icon(PhosphorIcons.star),
            title: Text(l10n.settingsRateApp),
            onTap: _rate,
          ),
          Builder(
            builder: (origin) => ListTile(
              leading: const Icon(PhosphorIcons.share),
              title: Text(l10n.settingsShareApp),
              onTap: () => _share(origin),
            ),
          ),
        ],
      ),
    );
  }
}
