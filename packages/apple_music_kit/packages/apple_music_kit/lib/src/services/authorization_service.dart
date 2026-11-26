/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'dart:async';

import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';

/// Authorization facade: request and observe Apple Music user authorization.
final class MusicAuthorizationService {
  /// Creates the facade over [platform].
  MusicAuthorizationService(this._platform, {void Function()? onUse})
      : _onUse = onUse;

  final MusicKitPlatform _platform;
  final void Function()? _onUse;

  /// Current status without prompting the user.
  Future<MusicAuthorizationStatus> getStatus() {
    _onUse?.call();
    return _platform.getAuthorizationStatus();
  }

  /// Prompts the user (when needed) and returns the resulting status.
  ///
  /// On iOS this maps to `MusicAuthorization.request()`. Repeated calls
  /// after `denied` will not spam prompts — the system reports the stored
  /// decision; guide the user to Settings.
  Future<MusicAuthorizationStatus> request() {
    _onUse?.call();
    return _platform.requestAuthorization();
  }

  /// Status changes, starting with the current status.
  Stream<MusicAuthorizationStatus> get statusChanges {
    _onUse?.call();
    return _platform.onAuthorizationChanged;
  }
}

/// Subscription facade: Apple Music subscription state, independent of
/// authorization.
final class MusicSubscriptionService {
  /// Creates the facade over [platform].
  MusicSubscriptionService(this._platform, {void Function()? onUse})
      : _onUse = onUse;

  final MusicKitPlatform _platform;
  final void Function()? _onUse;

  /// The current subscription snapshot.
  Future<MusicSubscription> get status {
    _onUse?.call();
    return _platform.getSubscription();
  }
}
