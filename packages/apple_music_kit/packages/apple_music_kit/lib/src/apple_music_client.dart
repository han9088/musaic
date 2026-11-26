/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'dart:async';

import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';

import 'package:apple_music_kit/src/config/apple_music_config.dart';
import 'package:apple_music_kit/src/player/apple_music_player.dart';
import 'package:apple_music_kit/src/services/authorization_service.dart';
import 'package:apple_music_kit/src/services/capabilities_service.dart';
import 'package:apple_music_kit/src/services/catalog_service.dart';
import 'package:apple_music_kit/src/services/library_service.dart';

/// The root facade for Apple MusicKit.
///
/// ```dart
/// final music = AppleMusicClient(
///   config: AppleMusicConfig(
///     appName: 'My Music',
///     developerTokenProvider: () async => fetchToken(),
///   ),
/// );
/// await music.initialize();
/// final status = await music.authorization.request();
/// await music.player.setQueue([ref]);
/// await music.player.play();
/// music.player.states.listen(render);
/// ```
///
/// [initialize] and [dispose] are idempotent. Calls on a disposed client
/// throw `MusicKitException(alreadyDisposed)`.
final class AppleMusicClient {
  /// Creates the client with [config] and an optional platform override
  /// (for tests or custom platform implementations).
  AppleMusicClient({required this.config, MusicKitPlatform? platform})
      : _platform = platform ?? MusicKitPlatform.instance {
    void guardUse() => ensureInitialized();
    authorization = MusicAuthorizationService(_platform, onUse: guardUse);
    subscription = MusicSubscriptionService(_platform, onUse: guardUse);
    catalog = MusicCatalogService(_platform, onUse: guardUse);
    library = MusicLibraryService(_platform, onUse: guardUse);
    capabilities = MusicCapabilitiesService(_platform, onUse: guardUse);
    player = AppleMusicPlayer(_platform, onUse: guardUse);
  }

  /// The configuration this client was created with.
  final AppleMusicConfig config;

  final MusicKitPlatform _platform;

  /// Authorization (request/observe Apple Music user permission).
  late final MusicAuthorizationService authorization;

  /// Subscription status (independent of authorization).
  late final MusicSubscriptionService subscription;

  /// Catalog search and resource fetches.
  late final MusicCatalogService catalog;

  /// The user's iCloud Music Library.
  late final MusicLibraryService library;

  /// Capability detection.
  late final MusicCapabilitiesService capabilities;

  /// The player.
  late final AppleMusicPlayer player;

  Future<void>? _initFuture;
  bool _disposed = false;
  bool _ready = false;
  Future<void>? _disposeFuture;

  /// Initializes the platform SDK. Idempotent; concurrent calls share one
  /// initialization. A failed initialization is not cached — the next
  /// call retries.
  Future<void> initialize() {
    if (_disposed) {
      throw MusicKitException(
        MusicKitErrorCode.alreadyDisposed,
        message: 'initialize() was called on a disposed AppleMusicClient.',
      );
    }
    final existing = _initFuture;
    if (existing != null) return existing;
    final run = _platform.initialize(config.toPlatformConfig()).then((_) {
      if (!_disposed) {
        _ready = true;
        player.start();
      }
    });
    _initFuture = run;
    // Do not cache a failed initialization; allow retry.
    run.catchError((_) {
      if (identical(_initFuture, run)) {
        _initFuture = null;
        _ready = false;
      }
    });
    return run;
  }

  /// Whether [initialize] has completed successfully.
  Future<bool> get isInitialized async {
    final future = _initFuture;
    if (future == null) return false;
    try {
      await future;
      return !_disposed;
    } catch (_) {
      return false;
    }
  }

  /// Releases this client's Dart-side resources.
  ///
  /// Idempotent. Does **not** stop shared native playback unless
  /// [stopPlayback] is true — releasing listeners should not yank the
  /// user's audio.
  Future<void> dispose({bool stopPlayback = false}) {
    if (_disposeFuture != null) return _disposeFuture!;
    _disposed = true;
    catalog.clearAnimatedArtworkRequests();
    return _disposeFuture = _release(stopPlayback);
  }

  Future<void> _release(bool stopPlayback) async {
    try {
      await _initFuture;
    } catch (_) {/* Failed initialization still needs cleanup. */}
    await player.shutdown();
    await _platform.dispose(stopPlayback: stopPlayback);
  }

  /// Guards a call requiring initialization.
  @pragma('vm:prefer-inline')
  void ensureInitialized() {
    if (_disposed) {
      throw MusicKitException(
        MusicKitErrorCode.alreadyDisposed,
        message: 'This AppleMusicClient has been disposed.',
      );
    }
    if (!_ready) {
      throw MusicKitException(
        MusicKitErrorCode.notInitialized,
        message: 'Call AppleMusicClient.initialize() before using the client.',
      );
    }
  }
}
