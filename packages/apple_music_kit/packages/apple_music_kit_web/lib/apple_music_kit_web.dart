/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'src/music_kit_web.dart';

export 'src/music_kit_web.dart';

/// Web entry point; registers the platform implementation with the
/// plugin registry.
final class AppleMusicKitWeb {
  /// Registers [AppleMusicKitWebPlatform] as the apple_music_kit web
  /// implementation.
  static void registerWith(Registrar registrar) {
    AppleMusicKitWebPlatform.registerWith();
  }
}
