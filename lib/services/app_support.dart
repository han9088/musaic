import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';

const _appleAppStoreId = String.fromEnvironment('MUSAIC_APP_STORE_ID');
const musaicContactEmail = 'deskbtm@gmail.com';
final _musaicUrl = Uri.https('musaic.deskbtm.com');

enum MusaicShareResult { handled, copied, unavailable }

Future<bool> composeMusaicContactEmail() async {
  try {
    await FlutterEmailSender.send(
      const Email(recipients: [musaicContactEmail]),
    );
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> openMusaicReview() async {
  final hasStoreListing = switch (defaultTargetPlatform) {
    TargetPlatform.android => true,
    TargetPlatform.iOS || TargetPlatform.macOS => _appleAppStoreId.isNotEmpty,
    _ => false,
  };
  if (kIsWeb || !hasStoreListing) return false;

  try {
    await InAppReview.instance.openStoreListing(
      appStoreId: _appleAppStoreId.isEmpty ? null : _appleAppStoreId,
    );
    return true;
  } catch (_) {
    return false;
  }
}

Future<MusaicShareResult> shareMusaic({Rect? anchor}) async {
  try {
    final result = await SharePlus.instance.share(
      ShareParams(
        uri: _musaicUrl,
        sharePositionOrigin: anchor,
        mailToFallbackEnabled: false,
      ),
    );
    // A successful browser share does not report a result. With email fallback
    // disabled, an unavailable share API throws instead.
    if (kIsWeb || result.status != ShareResultStatus.unavailable) {
      return MusaicShareResult.handled;
    }
  } catch (_) {
    // Fall back to copying the link when native sharing is unavailable.
  }

  try {
    await Clipboard.setData(ClipboardData(text: _musaicUrl.toString()));
    return MusaicShareResult.copied;
  } catch (_) {
    return MusaicShareResult.unavailable;
  }
}
