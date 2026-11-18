import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppIconChoice {
  classic(null, 'assets/branding/classic.png'),
  mosaic('MusaicMosaic', 'assets/branding/mosaic.png'),
  vinyl('MusaicVinyl', 'assets/branding/vinyl.png'),
  vinylWhite('MusaicVinylWhite', 'assets/branding/vinyl_white.png'),
  xerox('MuasicXerox', 'assets/branding/xerox.png');

  const AppIconChoice(this.nativeName, this.previewAsset);

  final String? nativeName;
  final String previewAsset;
}

typedef AppIconSnapshot = ({bool supported, AppIconChoice current});

/// Native configuration owns available icons; null selects the primary icon.
class AppIconService {
  const AppIconService();

  Iterable<AppIconChoice> get choices => AppIconChoice.values.where(
    (choice) =>
        choice != AppIconChoice.vinylWhite ||
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.macOS)),
  );

  Future<AppIconSnapshot> read() async {
    if (kIsWeb ||
        !const [
          TargetPlatform.iOS,
          TargetPlatform.android,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform) ||
        !await DynamicAppIconFlutterPlus.supportsAlternateIcons) {
      return (supported: false, current: AppIconChoice.classic);
    }
    final available = await DynamicAppIconFlutterPlus.getAvailableIcons();
    for (final choice in choices) {
      if (choice.nativeName != null && !available.contains(choice.nativeName)) {
        throw StateError(
          'The ${choice.nativeName} alternate icon is not configured',
        );
      }
    }
    final name = await DynamicAppIconFlutterPlus.getAlternateIconName();
    return (
      supported: true,
      current: AppIconChoice.values.firstWhere(
        (choice) => choice.nativeName == name,
      ),
    );
  }

  Future<void> change(AppIconChoice choice) async {
    try {
      await DynamicAppIconFlutterPlus.setAlternateIconName(
        choice.nativeName,
        showAlert: true,
        deferUntilBackground: false,
      );
    } on PlatformException {
      // Like Loive, accept an invalidated iOS callback only after OS confirmation.
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          await DynamicAppIconFlutterPlus.getAlternateIconName() ==
              choice.nativeName) {
        return;
      }
      rethrow;
    }
  }
}
