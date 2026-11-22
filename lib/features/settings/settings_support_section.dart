import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/app_support.dart';
import '../../ui/dialogs/app_alert_dialog.dart';
import '../../ui/dialogs/app_notification.dart';
import '../../ui/widgets/settings_section_heading.dart';

class SettingsSupportSection extends StatefulWidget {
  const SettingsSupportSection({super.key});

  @override
  State<SettingsSupportSection> createState() => _SettingsSupportSectionState();
}

class _SettingsSupportSectionState extends State<SettingsSupportSection> {
  bool _sharing = false;
  bool _composingEmail = false;

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

  Future<void> _openContactLink(BuildContext dialog, Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // The device may have no app registered to open this link.
    }
    if (dialog.mounted) {
      showAppNotification(
        dialog,
        message: AppLocalizations.of(dialog).settingsContactLinkUnavailable,
      );
    }
  }

  Future<void> _composeContactEmail() async {
    if (_composingEmail) return;
    _composingEmail = true;
    final handled = await composeMusaicContactEmail();
    _composingEmail = false;
    if (!handled && mounted) {
      showAppNotification(
        context,
        message: AppLocalizations.of(context).settingsContactEmailUnavailable,
      );
    }
  }

  Future<void> _showContactDialog() async {
    const xAddress = 'x.com/deskbtm';
    const githubAddress = 'github.com/deskbtm/musaic';
    const xiaohongshuAddress = 'xhslink.cn/o/5Od3qtTfSu0';
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final showXiaohongshu =
        deviceLocale.countryCode == 'CN' ||
        (deviceLocale.countryCode == null &&
            deviceLocale.languageCode == 'zh' &&
            deviceLocale.scriptCode != 'Hant');
    await showAppDialog<void>(
      context: context,
      builder: (dialog) {
        final l10n = AppLocalizations.of(dialog);
        ListTile contactItem(
          Widget logo,
          String label,
          String address,
          VoidCallback onTap,
        ) => ListTile(
          contentPadding: EdgeInsets.zero,
          horizontalTitleGap: 12,
          minLeadingWidth: 24,
          tileColor: Colors.transparent,
          textColor: Colors.white,
          iconColor: Colors.white70,
          leading: logo,
          title: Text(label),
          subtitle: Text(
            address,
            style: const TextStyle(color: Colors.white70),
          ),
          onTap: onTap,
        );

        return AppAlertDialog(
          title: Text(l10n.settingsContactUs),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialog).height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    contactItem(
                      Image.asset(
                        'assets/branding/gmail.png',
                        width: 24,
                        height: 24,
                      ),
                      'Gmail',
                      musaicContactEmail,
                      _composeContactEmail,
                    ),
                    contactItem(
                      const Icon(PhosphorIcons.xLogo),
                      'X',
                      xAddress,
                      () => _openContactLink(
                        dialog,
                        Uri.parse('https://$xAddress'),
                      ),
                    ),
                    contactItem(
                      const Icon(
                        PhosphorIcons.githubLogo,
                        color: Color(0xFFD2A8FF),
                      ),
                      'GitHub',
                      githubAddress,
                      () => _openContactLink(
                        dialog,
                        Uri.parse('https://$githubAddress'),
                      ),
                    ),
                    if (showXiaohongshu)
                      contactItem(
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.asset(
                            'assets/branding/xiaohongshu.png',
                            width: 24,
                            height: 24,
                          ),
                        ),
                        l10n.settingsContactXiaohongshu,
                        xiaohongshuAddress,
                        () => _openContactLink(
                          dialog,
                          Uri.parse('https://$xiaohongshuAddress'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: Text(MaterialLocalizations.of(dialog).closeButtonLabel),
            ),
          ],
        );
      },
    );
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
          ListTile(
            leading: const Icon(PhosphorIcons.chatCircleDots),
            title: Text(l10n.settingsContactUs),
            onTap: _showContactDialog,
          ),
        ],
      ),
    );
  }
}
