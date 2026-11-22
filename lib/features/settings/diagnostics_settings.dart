import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/diagnostics/diagnostic_log.dart';
import '../../services/diagnostics/diagnostic_report.dart';
import '../../ui/dialogs/app_notification.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/settings_section_heading.dart';

class DiagnosticsSettings extends StatefulWidget {
  const DiagnosticsSettings({super.key});

  @override
  State<DiagnosticsSettings> createState() => _DiagnosticsSettingsState();
}

class _DiagnosticsSettingsState extends State<DiagnosticsSettings> {
  final _description = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _openReport({BuildContext? mailOrigin}) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final description = _description.text.trim();
    final renderObject = mailOrigin?.findRenderObject();
    final anchor = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    String? message;
    try {
      final report = await DiagnosticReport.create();
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      if (mailOrigin == null) {
        if (await report.export() != null) message = l10n.diagnosticsExported;
      } else {
        final details = l10n.diagnosticsEmailDetails(
          report.device ?? l10n.diagnosticsUnavailableValue,
          report.system,
          report.appVersion ?? l10n.diagnosticsUnavailableValue,
        );
        final body = [
          if (description.isNotEmpty) description,
          details,
        ].join('\n\n');
        final result = await report.openEmail(
          subject: l10n.diagnosticsEmailSubject,
          body: body,
          anchor: anchor,
        );
        message = switch (result) {
          DiagnosticMailResult.handled => null,
          DiagnosticMailResult.unavailable => l10n.diagnosticsMailUnavailable,
          DiagnosticMailResult.failed => l10n.diagnosticsMailFailed,
        };
      }
    } catch (error) {
      diagnosticLog.record(
        mailOrigin == null
            ? DiagnosticEvent.reportExportFailed
            : DiagnosticEvent.reportMailFailed,
        error: error,
      );
      message = mailOrigin == null
          ? l10n.diagnosticsExportFailed
          : l10n.diagnosticsMailFailed;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted &&
        message != null &&
        ModalRoute.of(context)?.isCurrent != false) {
      showAppNotification(context, message: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: settingsItemPadding.add(const EdgeInsets.only(top: 16)),
          child: Text(
            l10n.diagnosticsPrivacy,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
        SettingsSectionHeading(l10n.diagnosticsDescription),
        Padding(
          padding: settingsItemPadding,
          child: TextField(
            controller: _description,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l10n.diagnosticsDescriptionHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SettingsSectionHeading(l10n.diagnosticsAttachment),
        ListTile(
          leading: const Icon(PhosphorIcons.downloadSimple),
          title: Text(l10n.diagnosticsExport),
          onTap: _busy ? null : _openReport,
        ),
      ],
    );
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: content),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: settingsItemPadding.add(
                const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.diagnosticsEmailSubtitle,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (origin) => FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _openReport(mailOrigin: origin),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.settingsAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.settingsAccent
                            .withValues(alpha: 0.45),
                        disabledForegroundColor: Colors.white70,
                        minimumSize: const Size.fromHeight(56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(
                        l10n.diagnosticsEmail,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
