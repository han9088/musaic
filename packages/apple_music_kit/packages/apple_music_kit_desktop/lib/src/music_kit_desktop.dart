import 'dart:async';
import 'dart:io';

import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';

import 'browser_connection.dart';

/// Windows/Linux implementation; the system browser owns MusicKit JS playback.
final class AppleMusicKitDesktop extends MethodChannelMusicKit {
  AppleMusicKitDesktop() : super(Platform.operatingSystem);

  static void registerWith() =>
      MusicKitPlatform.instance = AppleMusicKitDesktop();

  BrowserConnection? _connection;
  StreamController<MusicAuthorizationStatus>? _auth;
  StreamController<MusicPlayerState>? _states;
  MusicAuthorizationStatus _lastAuth = MusicAuthorizationStatus.notDetermined;
  MusicPlayerState _lastState = const MusicPlayerState.initial();

  @override
  Future<void> initialize(MusicKitPlatformConfig config) async {
    if (_connection != null) return;
    final String token;
    try {
      token = await config.developerTokenProvider?.getToken() ?? '';
      if (token.trim().isEmpty) throw const FormatException();
    } catch (_) {
      throw MusicKitException(MusicKitErrorCode.developerTokenMissing,
          message: 'Desktop MusicKit requires a developer token provider.',
          platform: platformName);
    }
    _auth = StreamController.broadcast();
    _states = StreamController.broadcast();
    final connection =
        BrowserConnection(platform: platformName, onEvent: _event);
    _connection = connection;
    try {
      await connection.connect();
      await connection.call('initialize', {
        'developerToken': token,
        'appName': config.appName ?? 'Apple Music',
        'appBuild': config.appBuild ?? '1.0.0',
      });
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  @override
  Future<T?> invoke<T>(String method, [Map<String, Object?>? args]) async {
    final connection = _connection;
    if (connection == null) {
      throw MusicKitException(MusicKitErrorCode.notInitialized,
          message: 'Call initialize() first.', platform: platformName);
    }
    final result = await connection.call(method, args);
    return result as T?;
  }

  void _event(String event, Object? value) {
    if (event == 'authorization') {
      final status = MusicAuthorizationStatus.fromName(value as String?);
      if (status != _lastAuth) {
        _lastAuth = status;
        _auth?.add(status);
      }
    } else if (event == 'state') {
      final m = Map<String, dynamic>.from(value as Map);
      _emit(MusicPlayerState(
        status: MusicPlayerStatus.fromName(m['status'] as String?),
        currentItem: m['currentItem'] == null
            ? null
            : MusicItemRef.fromJson(
                Map<String, dynamic>.from(m['currentItem'] as Map)),
        currentIndex: m['currentIndex'] as int?,
        position: Duration(milliseconds: m['positionMillis'] as int? ?? 0),
        duration: m['durationMillis'] == null
            ? null
            : Duration(milliseconds: m['durationMillis'] as int),
        queueLength: m['queueLength'] as int? ?? 0,
        shuffleMode: MusicShuffleMode.fromName(m['shuffleMode'] as String?),
        repeatMode: MusicRepeatMode.fromName(m['repeatMode'] as String?),
        isPlaying: m['isPlaying'] as bool? ?? false,
        isBuffering: m['isBuffering'] as bool? ?? false,
      ));
    } else if (event == 'disconnected') {
      _emit(_lastState.copyWith(
          status: MusicPlayerStatus.error,
          isPlaying: false,
          isBuffering: false,
          error: MusicKitException(MusicKitErrorCode.platformUnavailable,
              message: 'The playback browser disconnected.',
              platform: platformName)));
    }
  }

  void _emit(MusicPlayerState state) {
    if (state == _lastState) return;
    _lastState = state;
    _states?.add(state);
  }

  @override
  Stream<MusicAuthorizationStatus> get onAuthorizationChanged =>
      _replay(_auth, () => _lastAuth);

  @override
  Stream<MusicPlayerState> get playerStates =>
      _replay(_states, () => _lastState);

  Stream<T> _replay<T>(StreamController<T>? source, T Function() latest) =>
      Stream.multi((sink) {
        final subscription = source?.stream.listen(sink.addSync,
            onError: sink.addErrorSync, onDone: sink.closeSync);
        sink.addSync(latest());
        if (subscription == null) {
          sink.closeSync();
        } else {
          sink.onCancel = subscription.cancel;
        }
      }, isBroadcast: true);

  @override
  Future<void> dispose({bool stopPlayback = false}) async {
    final connection = _connection;
    if (connection == null) return;
    try {
      if (stopPlayback) await connection.call('stop');
    } finally {
      _connection = null;
      await connection.close();
      if (_auth != null) unawaited(_auth!.close());
      if (_states != null) unawaited(_states!.close());
      _auth = null;
      _states = null;
      _lastAuth = MusicAuthorizationStatus.notDetermined;
      _lastState = const MusicPlayerState.initial();
    }
  }
}
