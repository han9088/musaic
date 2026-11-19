import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppIconChoice {
  primaryVinyl('PrimaryVinyl', 'assets/branding/primary_vinyl.png'),
  classic('musaic', 'assets/branding/classic.png'),
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
      return (supported: false, current: AppIconChoice.primaryVinyl);
    }
    final available = await DynamicAppIconFlutterPlus.getAvailableIcons();
    for (final choice in choices) {
      final nativeName = _nativeName(choice);
      if (nativeName != null && !available.contains(nativeName)) {
        throw StateError(
          'The $nativeName alternate icon is not configured',
        );
      }
    }
    final name = await DynamicAppIconFlutterPlus.getAlternateIconName();
    return (
      supported: true,
      current: AppIconChoice.values.firstWhere(
        (choice) => _nativeName(choice) == name,
      ),
    );
  }

  Future<void> change(AppIconChoice choice) async {
    try {
      await DynamicAppIconFlutterPlus.setAlternateIconName(
        _nativeName(choice),
        showAlert: true,
        deferUntilBackground: false,
      );
    } on PlatformException {
      // Like Loive, accept an invalidated iOS callback only after OS confirmation.
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          await DynamicAppIconFlutterPlus.getAlternateIconName() ==
              _nativeName(choice)) {
        return;
      }
      rethrow;
    }
  }

  String? _nativeName(AppIconChoice choice) {
    if (choice == AppIconChoice.primaryVinyl) {
      return null;
    }
    if (choice == AppIconChoice.classic &&
        defaultTargetPlatform == TargetPlatform.android) {
      return 'MusaicClassic';
    }
    return choice.nativeName;
  }
}
