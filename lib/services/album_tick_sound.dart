import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AlbumTickSound {
  AudioPool? _pool;
  final _stops = <StopFunction>{};
  Future<StopFunction>? _starting;

  Future<void> prepare() async {
    try {
      _pool = await AudioPool.create(
        source: AssetSource('sounds/ios_wheel_tick.m4a'),
        minPlayers: 3,
        maxPlayers: 3,
        playerMode: PlayerMode.lowLatency,
        audioContext: AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
            usageType: AndroidUsageType.assistanceSonification,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Album tick sound unavailable: $error');
    }
  }

  Future<void> play(double volume) async {
    final pool = _pool;
    if (pool == null || _starting != null || _stops.length >= 3) return;
    _starting = pool.start(volume: volume);
    try {
      final stop = await _starting!;
      _stops.add(stop);
      // Low-latency mode has no completion event; the asset lasts 65 ms.
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 80), () async {
          if (_stops.remove(stop)) await stop();
        }).catchError((Object error) {
          debugPrint('Album tick sound stop failed: $error');
        }),
      );
    } catch (error) {
      debugPrint('Album tick sound playback failed: $error');
    } finally {
      _starting = null;
    }
  }

  Future<void> stop() async {
    try {
      await _starting;
    } catch (_) {
      // Playback reports its own failure.
    }
    final stops = _stops.toList();
    _stops.clear();
    for (final stop in stops) {
      try {
        await stop();
      } catch (error) {
        debugPrint('Album tick sound stop failed: $error');
      }
    }
  }

  Future<void> dispose() async {
    final pool = _pool;
    _pool = null;
    await stop();
    try {
      await pool?.dispose();
    } catch (error) {
      debugPrint('Album tick sound release failed: $error');
    }
  }
}
