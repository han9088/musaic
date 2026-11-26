/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';
import 'package:meta/meta.dart';

/// User-facing configuration for [AppleMusicClient].
@immutable
final class AppleMusicConfig {
  /// Creates the configuration.
  ///
  /// [developerTokenProvider] fetches the Apple Music developer token
  /// (JWT) from **your server**. It is required on Android and Web; on iOS
  /// MusicKit manages tokens automatically, so it may be omitted there.
  const AppleMusicConfig({
    this.appName,
    this.appBuild,
    this.developerTokenProvider,
  });

  /// Display name of your app, used where attribution is possible.
  final String? appName;

  /// Build/version string of your app.
  final String? appBuild;

  /// Developer token source. Never embed the .p8 key in the client.
  final DeveloperTokenProvider? developerTokenProvider;

  /// Converts to the platform-layer config.
  MusicKitPlatformConfig toPlatformConfig() => MusicKitPlatformConfig(
        appName: appName,
        appBuild: appBuild,
        developerTokenProvider: developerTokenProvider,
      );
}
