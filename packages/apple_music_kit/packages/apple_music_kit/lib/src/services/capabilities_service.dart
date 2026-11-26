/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';

/// Capabilities facade: what the current platform/state can actually do.
final class MusicCapabilitiesService {
  /// Creates the facade over [platform].
  MusicCapabilitiesService(this._platform, {void Function()? onUse})
      : _onUse = onUse;

  final MusicKitPlatform _platform;
  final void Function()? _onUse;

  /// The capability snapshot.
  ///
  /// Each capability reports both `supported` and a machine-readable
  /// `reason` when unsupported — distinguishing "structurally unsupported",
  /// "needs authorization", "needs subscription", and "SDK missing".
  Future<MusicCapabilities> get() {
    _onUse?.call();
    return _platform.getCapabilities();
  }
}
