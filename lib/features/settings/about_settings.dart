import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/app_icon_service.dart';
import '../../services/app_updates.dart';
import '../../services/diagnostics/diagnostic_log.dart';
import '../../ui/dialogs/app_alert_dialog.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/thinking_orbs/thinking_orb.dart';

String _displayVersion(PackageInfo info) => info.buildNumber.isEmpty
    ? info.version
    : '${info.version} (${info.buildNumber})';

Future<void> _showAboutDialog(
  BuildContext context,
  String title,
  Widget content, {
  Widget? action,
}) async {
  await showAppDialog<void>(
    context: context,
    builder: (dialog) => AppAlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(dialog).height * 0.5,
        ),
        child: SingleChildScrollView(child: content),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(MaterialLocalizations.of(dialog).closeButtonLabel),
        ),
        ?action,
      ],
    ),
  );
}

class AboutSettings extends StatefulWidget {
  const AboutSettings({super.key, required this.onOpenDetail});

  final void Function(BuildContext context, String title, Widget body)
  onOpenDetail;

  @override
  State<AboutSettings> createState() => _AboutSettingsState();
}

class AboutCopyrightFooter extends StatelessWidget {
  const AboutCopyrightFooter({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      settingsContentInset,
      24,
      settingsContentInset,
      24,
    ),
    child: Text(
      '© ${DateTime.now().year} deskbtm',
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white38, fontSize: 12),
    ),
  );
}

class _AboutSettingsState extends State<AboutSettings> {
  late final _packageInfo = PackageInfo.fromPlatform();
  bool _checking = false;

  void _openDetail(String title, String text) => widget.onOpenDetail(
    context,
    title,
    Padding(
      padding: const EdgeInsets.fromLTRB(
        settingsContentInset,
        16,
        settingsContentInset,
        24,
      ),
      child: SelectableText(
        text,
        style: const TextStyle(color: Colors.white70, height: 1.5),
      ),
    ),
  );

  Future<void> _checkUpdate(PackageInfo installed) async {
    if (_checking) return;
    setState(() => _checking = true);
    final l10n = AppLocalizations.of(context);
    var available = false;
    String message;
    try {
      final latest = await latestMusaicRelease();
      available =
          latest != null &&
          isMusaicUpdateAvailable(
            latest,
            installed.version,
            installed.buildNumber,
          );
      message = latest == null
          ? l10n.settingsNoRelease
          : available
          ? l10n.settingsUpdateAvailable(latest.toString())
          : l10n.settingsUpToDate;
      diagnosticLog.record(
        latest == null
            ? DiagnosticEvent.updateNoRelease
            : available
            ? DiagnosticEvent.updateFound
            : DiagnosticEvent.updateCurrent,
      );
    } catch (error) {
      diagnosticLog.record(DiagnosticEvent.updateCheckFailed, error: error);
      message = l10n.settingsUpdateFailed;
    } finally {
      if (mounted) setState(() => _checking = false);
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
    await _showAboutDialog(
      context,
      l10n.settingsCheckUpdate,
      Text(message),
      action: available
          ? Builder(
              builder: (dialog) => TextButton(
                onPressed: () async {
                  try {
                    if (await launchUrl(musaicReleasesUrl)) return;
                  } catch (_) {
                    // Keep the release address available if launching fails.
                  }
                  if (!dialog.mounted) return;
                  await _showAboutDialog(
                    dialog,
                    l10n.settingsViewRelease,
                    SelectableText(musaicReleasesUrl.toString()),
                  );
                },
                child: Text(l10n.settingsViewRelease),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const arrow = Icon(PhosphorIcons.caretLeft, size: settingsItemArrowSize);
    const tagline = 'Music in Mosaic';
    const taglineStyle = TextStyle(fontFamily: 'Italianno', fontSize: 24);
    return Column(
      children: [
        const SizedBox(height: 30),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            AppIconChoice.vinylPrimary.previewAsset,
            width: 75,
            height: 75,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 30),
        Stack(
          alignment: Alignment.center,
          children: [
            Text(
              tagline,
              textAlign: TextAlign.center,
              style: taglineStyle.copyWith(color: const Color(0xFFEACD58)),
            ),
            // Trim the edge of the regular-weight glyphs against the black page.
            ExcludeSemantics(
              child: Text(
                tagline,
                textAlign: TextAlign.center,
                style: taglineStyle.copyWith(
                  foreground: Paint()
                    ..color = Colors.black
                    ..style = PaintingStyle.stroke
                    ..strokeJoin = StrokeJoin.round
                    ..strokeWidth = 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 95),
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (context, snapshot) {
            final info = snapshot.data;
            return ListTile(
              title: Text(l10n.settingsVersion),
              trailing: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width / 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        info == null
                            ? (snapshot.hasError
                                  ? l10n.settingsVersionUnavailable
                                  : '…')
                            : _displayVersion(info),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                    if (_checking) ...[
                      const SizedBox(width: 8),
                      ThinkingOrb(
                        state: ThinkingOrbState.working,
                        size: ThinkingOrbSize.inline,
                        theme: ThinkingOrbTheme.dark,
                        semanticLabel: l10n.settingsCheckUpdate,
                      ),
                    ],
                  ],
                ),
              ),
              onTap: info == null || _checking
                  ? null
                  : () => _checkUpdate(info),
            );
          },
        ),
        ListTile(
          title: Text(l10n.settingsPrivacyPolicy),
          trailing: arrow,
          onTap: () => _openDetail(
            l10n.settingsPrivacyPolicy,
            l10n.settingsPrivacyDetails,
          ),
        ),
        ListTile(
          title: Text(l10n.settingsWhatsNew),
          trailing: arrow,
          onTap: () =>
              _openDetail(l10n.settingsWhatsNew, l10n.settingsWhatsNewDetails),
        ),
      ],
    );
  }
}
