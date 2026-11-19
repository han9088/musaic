// 文件职责：应用级服务、平台适配与辅助能力。

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pulsar_haptics/pulsar.dart';

import 'album_tick_sound.dart';

/// 封装或定义专辑触觉反馈相关类型与行为，负责应用级服务、平台适配与辅助能力。
class AlbumHaptics {
  AlbumHaptics({AlbumTickSound? sound}) : _sound = sound ?? AlbumTickSound();

  final bool _usesSystemSound =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final AlbumTickSound _sound;
  final bool _supportsHaptics =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  final _pulsar = Pulsar();
  late final _players = List.generate(
    _supportsHaptics ? 10 : 0,
    (_) => _pulsar.getPatternComposer(),
  );
  Future<void>? _preparation;
  bool _ready = false;
  bool _active = true;
  bool _disposed = false;
  bool _playing = false;

  /// 准备并调度后续任务，用于应用级服务、平台适配与辅助能力。
  Future<void> prepare() => _preparation ??= _prepare();

  /// 准备并调度后续任务，用于应用级服务、平台适配与辅助能力。
  Future<void> _prepare() async {
    if (_disposed) return;
    if (!_usesSystemSound) await _sound.prepare();
    if (!_supportsHaptics) return;
    try {
      if (_disposed || !await _pulsar.isHapticsSupported()) return;
      await _pulsar.enableSound(false);
      for (var i = 0; i < _players.length; i++) {
        final amplitude = (0.42 + (i ~/ 2) * 0.145) * (i.isEven ? 1.0 : 0.9);
        await _players[i].parsePattern(
          PatternData(
            continuousPattern: const ContinuousPattern(
              amplitude: [],
              frequency: [],
            ),
            discretePattern: [
              DiscretePoint(time: 0, amplitude: amplitude, frequency: 1),
            ],
          ),
        );
      }
      _ready = !_disposed;
    } catch (error) {
      debugPrint('Album haptics unavailable: $error');
    }
  }

  /// 应用选择并更新对应状态，用于应用级服务、平台适配与辅助能力。
  Future<void> setActive(bool active) async {
    _active = active;
    if (!active && !_usesSystemSound) await _sound.stop();
    if (!active && _ready) {
      try {
        await _pulsar.stopHaptics();
      } catch (error) {
        debugPrint('Album haptics stop failed: $error');
      }
    }
  }

  /// 执行当前模块中的刻度音操作，用于应用级服务、平台适配与辅助能力。
  Future<void> tick({required bool movingLeft, double strength = 1}) async {
    if (!_active || _disposed || _playing) return;
    _playing = true;
    try {
      // 复用已解析的原生播放器，不为错过的滚动刻度累积待播放音效。
      final level = strength.clamp(0.0, 1.0);
      await Future.wait([
        if (_usesSystemSound)
          SystemSound.play(SystemSoundType.tick)
        else
          _sound.play(level),
        if (_ready)
          _players[(level * 4).round() * 2 + (movingLeft ? 0 : 1)].play(),
      ]);
    } catch (error) {
      _ready = false;
      debugPrint('Album haptics playback failed: $error');
    } finally {
      _playing = false;
    }
  }

  /// 释放控制器、订阅、动画及其他持有资源，用于应用级服务、平台适配与辅助能力。
  Future<void> dispose() async {
    _disposed = true;
    await _preparation;
    if (!_usesSystemSound) await _sound.dispose();
    for (final composer in _players) {
      try {
        await composer.dispose();
      } catch (error) {
        debugPrint('Album haptics release failed: $error');
      }
    }
    _ready = false;
  }
}
