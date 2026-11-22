import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'diagnostic_log.dart';

const _feedbackEmail = String.fromEnvironment('MUSAIC_FEEDBACK_EMAIL');
const _mimeType = 'text/plain';
typedef _Device = ({String? model, String system});

enum DiagnosticMailResult { handled, unavailable, failed }

class DiagnosticReport {
  DiagnosticReport._({
    required this.device,
    required this.system,
    required this.appVersion,
    required this.fileName,
    required this.bytes,
  });

  final String? device;
  final String system;
  final String? appVersion;
  final String fileName;
  final Uint8List bytes;

  static Future<DiagnosticReport> create() async {
    final deviceFuture = _readDevice();
    final versionFuture = _readVersion();
    final entries = await diagnosticLog.recentEvents();
    final device = await deviceFuture;
    final version = await versionFuture;
    final time = DateTime.now().toUtc().toIso8601String();
    final stamp = time.replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
    final content = [
      'Musaic diagnostic report',
      'Generated (UTC): $time',
      'Device model: ${device.model ?? 'Unavailable'}',
      'System: ${device.system}',
      'Musaic version: ${version ?? 'Unavailable'}',
      '',
      'Recent events (UTC):',
      ...entries,
    ].join('\n');
    return DiagnosticReport._(
      device: device.model,
      system: device.system,
      appVersion: version,
      fileName: 'musaic-diagnostics-$stamp.txt',
      bytes: utf8.encode('$content\n'),
    );
  }

  Future<Uri?> export() => FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: _mimeType,
  );

  Future<DiagnosticMailResult> openEmail({
    required String subject,
    required String body,
    required Rect? anchor,
  }) async {
    if (!kIsWeb) {
      try {
        await FlutterEmailSender.send(
          Email(
            recipients: [if (_feedbackEmail.isNotEmpty) _feedbackEmail],
            subject: subject,
            body: body,
            attachments: [
              EmailAttachment.data(
                bytes,
                fileName: fileName,
                mimeType: _mimeType,
              ),
            ],
          ),
        );
        return DiagnosticMailResult.handled;
      } on FlutterEmailSenderUnsupportedFeatureException {
        // Some mail clients can accept an attachment through the share sheet.
      } on FlutterEmailSenderNotAvailableException {
        // Try the share sheet when the native composer is unavailable.
      } on MissingPluginException {
        // Try the share sheet where only the sharing plugin is registered.
      } catch (error) {
        diagnosticLog.record(DiagnosticEvent.reportMailFailed, error: error);
        return DiagnosticMailResult.failed;
      }
    }

    // The macOS share plugin shares either the attachment or the body.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await SharePlus.instance.share(
          ShareParams(
            subject: subject,
            text: body,
            files: [XFile.fromData(bytes, mimeType: _mimeType)],
            fileNameOverrides: [fileName],
            sharePositionOrigin: anchor,
            downloadFallbackEnabled: false,
            mailToFallbackEnabled: false,
          ),
        );
        if (kIsWeb || result.status != ShareResultStatus.unavailable) {
          return DiagnosticMailResult.handled;
        }
      } catch (_) {
        // The export action is still available without a mail or share target.
      }
    }
    diagnosticLog.record(DiagnosticEvent.reportMailUnavailable);
    return DiagnosticMailResult.unavailable;
  }
}

Future<_Device> _readDevice() async {
  final info = DeviceInfoPlugin();
  try {
    if (kIsWeb) {
      final browser = await info.webBrowserInfo;
      return (model: null, system: 'Web (${browser.browserName.name})');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = await info.androidInfo;
        return (
          model: android.model,
          system: 'Android ${android.version.release}',
        );
      case TargetPlatform.iOS:
        final ios = await info.iosInfo;
        return (
          model: ios.modelName.isEmpty ? ios.utsname.machine : ios.modelName,
          system: '${ios.systemName} ${ios.systemVersion}',
        );
      case TargetPlatform.macOS:
        final mac = await info.macOsInfo;
        return (
          model: mac.modelName.isEmpty ? mac.model : mac.modelName,
          system:
              'macOS ${mac.majorVersion}.${mac.minorVersion}.${mac.patchVersion}',
        );
      case _:
        break;
    }
  } catch (_) {
    // A report is still usable if the device information plugin is unavailable.
  }
  return (model: null, system: kIsWeb ? 'Web' : defaultTargetPlatform.name);
}

Future<String?> _readVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version} (${info.buildNumber})';
  } catch (_) {
    return null;
  }
}
