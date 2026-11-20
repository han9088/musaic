// 文件职责：音乐源、媒体库、播放及切换流程。

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../ui/transitions/source_tile_motion.dart';

/// 封装或定义来源过渡phase相关类型与行为，负责音乐源、媒体库、播放及切换流程。
enum SourceTransitionPhase { exit, handoff, enter }

/// 封装或定义首页来源过渡相关类型与行为，负责音乐源、媒体库、播放及切换流程。
class HomeSourceTransition {
  HomeSourceTransition({
    required TickerProvider vsync,
    required this._isMounted,
    required this._notifyChanged,
    required this._onHandoff,
    required this._onMotionChanged,
  }) {
    timeline = AnimationController(vsync: vsync)
      ..addListener(_advance)
      ..addStatusListener(_handleStatus);
  }

  final bool Function() _isMounted;
  final VoidCallback _notifyChanged;
  final void Function(List<Map<String, dynamic>>) _onHandoff;
  final VoidCallback _onMotionChanged;

  late final AnimationController timeline;
  final switching = ValueNotifier(false);
  List<Map<String, dynamic>>? targetAlbums;
  Map<(int, int), SourceTileMotion> exitMotions = const {};
  Map<(int, int), SourceTileMotion> enterMotions = const {};
  SourceTransitionPhase? phase;
  Completer<void>? _completer;
  double exitDurationMs = 0;
  double sourceDurationMs = 0;
  bool preparing = false;

  /// 控制流程的开始、暂停、取消或结束，用于音乐源、媒体库、播放及切换流程。
  Future<void> start({
    required List<Map<String, dynamic>> targetAlbums,
    required ({Map<(int, int), SourceTileMotion> tiles, double durationMs})
    exit,
    required ({Map<(int, int), SourceTileMotion> tiles, double durationMs})
    enter,
  }) {
    exitMotions = exit.tiles;
    enterMotions = enter.tiles;
    exitDurationMs = exit.durationMs;
    sourceDurationMs = (exit.durationMs + sourceHandoffMs + enter.durationMs)
        .ceilToDouble();
    this.targetAlbums = targetAlbums;
    _completer = Completer<void>();
    timeline.duration = Duration(milliseconds: sourceDurationMs.ceil());
    phase = SourceTransitionPhase.exit;
    _notifyChanged();
    _onMotionChanged();
    timeline.forward(from: 0);
    return _completer!.future;
  }

  /// 执行当前模块中的advance操作，用于音乐源、媒体库、播放及切换流程。
  void _advance() {
    final current = phase;
    if (!_isMounted() || current == null) return;
    final elapsed = timeline.value * sourceDurationMs;
    if (current == SourceTransitionPhase.exit && elapsed >= exitDurationMs) {
      phase = SourceTransitionPhase.handoff;
      _notifyChanged();
    }
    if (phase == SourceTransitionPhase.handoff &&
        elapsed >= exitDurationMs + sourceHandoffMs) {
      _onHandoff(targetAlbums!);
      phase = SourceTransitionPhase.enter;
      _notifyChanged();
    }
  }

  /// 处理对应事件并协调后续状态变化，用于音乐源、媒体库、播放及切换流程。
  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_isMounted()) return;
    phase = null;
    targetAlbums = null;
    exitMotions = const {};
    enterMotions = const {};
    preparing = false;
    _notifyChanged();
    _onMotionChanged();
    _finish();
  }

  /// 控制流程的开始、暂停、取消或结束，用于音乐源、媒体库、播放及切换流程。
  void _finish() {
    final done = _completer;
    _completer = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// 协调动画进度与状态过渡，用于音乐源、媒体库、播放及切换流程。
  Widget animateTile(
    int row,
    int column,
    Widget child, {
    required double Function() scale,
    required Size Function(BuildContext) viewport,
    required double tileSize,
  }) {
    final current = phase;
    if (current == null) return child;
    final motion = current == SourceTransitionPhase.enter
        ? enterMotions[(row, column)]
        : exitMotions[(row, column)];
    if (motion == null) return child;
    return AnimatedBuilder(
      animation: timeline,
      child: child,
      builder: (context, child) {
        final zoom = scale();
        final window = viewport(context);
        final elapsed = timeline.value * sourceDurationMs;
        final value = current == SourceTransitionPhase.enter
            ? motion.enterTransform(
                elapsedMs: elapsed - exitDurationMs - sourceHandoffMs,
                viewport: window,
                scale: zoom,
                tileSize: tileSize,
              )
            : motion.exitTransform(
                elapsedMs: elapsed,
                viewport: window,
                scale: zoom,
                tileSize: tileSize,
              );
        return Transform(
          alignment: Alignment.center,
          transform: value.transform,
          child: Opacity(opacity: value.alpha, child: child),
        );
      },
    );
  }

  /// 释放控制器、订阅、动画及其他持有资源，用于音乐源、媒体库、播放及切换流程。
  void dispose() {
    _finish();
    timeline.dispose();
    switching.dispose();
  }
}
