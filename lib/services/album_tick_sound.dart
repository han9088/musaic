// 文件职责：应用级服务、平台适配与辅助能力。

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 封装或定义专辑刻度音音效相关类型与行为，负责应用级服务、平台适配与辅助能力。
class AlbumTickSound {
  AudioPool? _pool;
  final _stops = <StopFunction>{};
  Future<StopFunction>? _starting;

  /// 准备并调度后续任务，用于应用级服务、平台适配与辅助能力。
  Future<void> prepare() async {
    try {
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
    if (pool == null || _starting != null || _stops.length >= 3) return;
    _starting = pool.start(volume: volume);
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
