import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_theme.dart';
import 'camera_background_demo.dart';
import 'playback_drag_demo.dart';

class UsageGuideSettings extends StatelessWidget {
  const UsageGuideSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final topics = [
      (l10n.usageGuideBrowseTitle, l10n.usageGuideBrowse, null),
      (
        l10n.usageGuidePlaybackTitle,
        l10n.usageGuidePlayback,
        const PlaybackDragDemo(),
      ),
      (
        l10n.musicSource,
        isMobile
            ? '${l10n.usageGuideMusic}\n\n${l10n.usageGuideMusicMobile}'
            : l10n.usageGuideMusic,
        null,
      ),
      (l10n.usageGuideLayoutTitle, l10n.usageGuideLayout, null),
      if (isMobile)
        (
          l10n.usageGuideCameraTitle,
          l10n.usageGuideCamera,
          const CameraBackgroundDemo(),
        ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: settingsItemPadding.add(const EdgeInsets.only(bottom: 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (title, description, demo) in topics) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
                if (demo != null) ...[const SizedBox(height: 12), demo],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class UsageGuideDismissFooter extends StatelessWidget {
  const UsageGuideDismissFooter({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Padding(
        padding: settingsItemPadding.copyWith(
          top: AppSpacing.sm,
          bottom: AppSpacing.md,
        ),
        child: FilledButton(
          onPressed: onDismiss,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.settingsAccent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(
            AppLocalizations.of(context).usageGuideDismiss,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
