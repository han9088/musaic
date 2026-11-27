// 文件职责：应用级服务、平台适配与辅助能力。

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio/musaic_audio_platform.dart';
import 'audio/musaic_sound.dart';

/// 封装或定义专辑刻度音音效相关类型与行为，负责应用级服务、平台适配与辅助能力。
class AlbumTickSound {
  AudioPool? _pool;
  final _sounds = <MusaicSound>[];
  final _available = <MusaicSound>[];
  final _stops = <StopFunction>{};
  Future<StopFunction>? _starting;
  bool _disposed = false;

  /// 准备并调度后续任务，用于应用级服务、平台适配与辅助能力。
  Future<void> prepare() async {
    if (_disposed) return;
    try {
      if (usesMusaicAudio) {
        _sounds.addAll(List.generate(3, (_) => MusaicSound()));
        for (final sound in _sounds) {
          await sound.prepare('assets/sounds/ios_wheel_tick.m4a');
        }
        if (!_disposed) _available.addAll(_sounds);
        return;
      }
      _pool = await AudioPool.create(
        source: AssetSource('sounds/ios_wheel_tick.m4a'),
        minPlayers: 3,
        maxPlayers: 3,
        playerMode: defaultTargetPlatform == TargetPlatform.macOS
            ? PlayerMode.mediaPlayer
            : PlayerMode.lowLatency,
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

  /// 执行当前模块中的播放操作，用于应用级服务、平台适配与辅助能力。
  Future<void> play(double volume) async {
    final pool = _pool;
    if (_disposed || _starting != null || _stops.length >= 3) return;
    if (pool == null && _available.isEmpty) return;
    _starting = pool?.start(volume: volume) ?? _startNative(volume);
    try {
      final stop = await _starting!;
      _stops.add(stop);
      // 低延迟播放模式不会提供完成回调；音效资源本身时长为 65 毫秒。
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

  Future<StopFunction> _startNative(double volume) async {
    final sound = _available.removeLast();
    try {
      await sound.start(volume: volume);
    } catch (_) {
      if (!_disposed) _available.add(sound);
      rethrow;
    }
    return () async {
      try {
        await sound.pause();
      } finally {
        if (!_disposed) _available.add(sound);
      }
    };
  }

  /// 控制流程的开始、暂停、取消或结束，用于应用级服务、平台适配与辅助能力。
  Future<void> stop() async {
    try {
      await _starting;
    } catch (_) {
      // 播放器会自行上报播放失败。
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

  /// 释放控制器、订阅、动画及其他持有资源，用于应用级服务、平台适配与辅助能力。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final pool = _pool;
    _pool = null;
    await stop();
    _available.clear();
    try {
      await Future.wait([
        if (pool != null) pool.dispose(),
        for (final sound in _sounds) sound.dispose(),
      ]);
    } catch (error) {
      debugPrint('Album tick sound release failed: $error');
    }
  }
}
