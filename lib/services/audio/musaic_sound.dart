import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:musaic_audio/musaic_audio.dart';

import '../diagnostics/diagnostic_log.dart';

/// A short effect that leaves the app's music session and audio focus alone.
final class MusaicSound {
  final _player = AudioPlayer(
    handleAudioSessionActivation: false,
    handleInterruptions: false,
    androidApplyAudioAttributes: false,
  );

  Future<void> prepare(String asset) async {
    await _player.setAndroidAudioAttributes(
      const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        usage: AndroidAudioUsage.assistanceSonification,
      ),
    );
    await _player.setAsset(asset);
  }

  Future<void> start({double volume = 1}) async {
    if (_player.playing) await _player.pause();
    await _player.setVolume(volume);
    await _player.seek(Duration.zero);
    unawaited(
      _player.play().onError((Object error, StackTrace stack) {
        diagnosticLog.record(
          DiagnosticEvent.playbackPlayerFailed,
          error: error,
          nativeErrorCode: error is PlayerException ? error.code : null,
          stack: stack,
        );
      }),
    );
  }

  Future<void> pause() => _player.pause();

  Future<void> dispose() => _player.dispose();
}
