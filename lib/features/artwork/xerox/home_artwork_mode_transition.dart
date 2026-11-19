// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../canvas/album_grid_snapshot.dart';
import '../../music/transition/music_source_transition.dart';

/// 封装或定义专辑封面模式过渡phase相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
enum ArtworkModeTransitionPhase { exit, handoff, enter }

/// 封装或定义首页专辑封面模式过渡相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class HomeArtworkModeTransition {
  HomeArtworkModeTransition({
    required TickerProvider vsync,
    required bool Function() isMounted,
    required VoidCallback notifyChanged,
    required VoidCallback onMotionChanged,
  }) : _isMounted = isMounted,
       _notifyChanged = notifyChanged,
       _onMotionChanged = onMotionChanged {
    timeline = AnimationController(vsync: vsync)
      ..addListener(_advance)
      ..addStatusListener(_handleStatus);
  }

  final bool Function() _isMounted;
  final VoidCallback _notifyChanged;
  final VoidCallback _onMotionChanged;

  late final AnimationController timeline;
  Map<(int, int), SourceTileMotion> _exit = const {};
  Map<(int, int), SourceTileMotion> _enter = const {};
  ArtworkModeTransitionPhase? phase;
  Completer<void>? _completer;
  VoidCallback? _onHandoff;
  VoidCallback? _onCompleted;
  double _exitDurationMs = 0;
  double _durationMs = 0;

  /// 判断当前状态是否满足指定条件，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  bool get isActive => phase != null || _completer != null;

  /// 控制流程的开始、暂停、取消或结束，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<void> start({
    required ({Map<(int, int), SourceTileMotion> tiles, double durationMs}) exit,
    required ({Map<(int, int), SourceTileMotion> tiles, double durationMs}) enter,
    required VoidCallback onHandoff,
    VoidCallback? onCompleted,
  }) {
    _exit = exit.tiles;
    _enter = enter.tiles;
    _exitDurationMs = exit.durationMs;
    _durationMs =
        (exit.durationMs + sourceHandoffMs + enter.durationMs).ceilToDouble();
    _onHandoff = onHandoff;
    _onCompleted = onCompleted;
    _completer = Completer<void>();
    timeline.duration = Duration(milliseconds: _durationMs.ceil());
    phase = ArtworkModeTransitionPhase.exit;
    _notifyChanged();
    _onMotionChanged();
    timeline.forward(from: 0);
    return _completer!.future;
  }

  /// 执行当前模块中的advance操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void _advance() {
    if (!_isMounted() || phase == null) return;
    final elapsed = timeline.value * _durationMs;
    if (phase == ArtworkModeTransitionPhase.exit &&
        elapsed >= _exitDurationMs) {
      phase = ArtworkModeTransitionPhase.handoff;
      _notifyChanged();
    }
    if (phase == ArtworkModeTransitionPhase.handoff &&
        elapsed >= _exitDurationMs + sourceHandoffMs) {
      _onHandoff?.call();
      _onHandoff = null;
      phase = ArtworkModeTransitionPhase.enter;
      _notifyChanged();
    }
  }

  /// 处理对应事件并协调后续状态变化，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_isMounted()) return;
    phase = null;
    _exit = const {};
    _enter = const {};
    _onHandoff = null;
    _notifyChanged();
    _finish();
    _onMotionChanged();
    _onCompleted?.call();
    _onCompleted = null;
  }

  /// 控制流程的开始、暂停、取消或结束，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void _finish() {
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  /// 协调动画进度与状态过渡，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Widget animateTile(
    int row,
    int column,
    Widget child, {
    required double Function() scale,
    required Size Function(BuildContext) viewport,
  }) {
    final current = phase;
    if (current == null) return child;
    final motion = current == ArtworkModeTransitionPhase.enter
        ? _enter[(row, column)]
        : _exit[(row, column)];
    if (motion == null) return child;

    return AnimatedBuilder(
      animation: timeline,
      child: child,
      builder: (context, child) {
        final elapsed = timeline.value * _durationMs;
        final window = viewport(context);
        final zoom = scale();
        final value = current == ArtworkModeTransitionPhase.enter
            ? motion.enterTransform(
                elapsedMs: elapsed - _exitDurationMs - sourceHandoffMs,
                viewport: window,
                scale: zoom,
                tileSize: albumGridExtent,
              )
            : motion.exitTransform(
                elapsedMs: elapsed,
                viewport: window,
                scale: zoom,
                tileSize: albumGridExtent,
              );
        return Transform(
          alignment: Alignment.center,
          transform: value.transform,
          child: Opacity(opacity: value.alpha, child: child),
        );
      },
    );
  }

  /// 释放控制器、订阅、动画及其他持有资源，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void dispose() {
    _onHandoff = null;
    _onCompleted = null;
    _finish();
    timeline.dispose();
  }
}
