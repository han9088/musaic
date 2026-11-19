// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'package:material_ui/material_ui.dart';

import '../../canvas/album_grid_snapshot.dart';
import '../../music/transition/music_source_transition.dart';
import 'home_artwork_mode_transition.dart';
import 'xerox_job_scheduler.dart';
import 'xerox_mode_controller.dart';
import 'xerox_raster_request.dart';

/// 封装或定义首页专辑封面模式控制器相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class HomeArtworkModeController {
  HomeArtworkModeController({
    required TickerProvider vsync,
    required bool Function() isMounted,
    required VoidCallback notifyChanged,
    required VoidCallback onMotionChanged,
  }) : _isMounted = isMounted,
       _notifyChanged = notifyChanged,
       _onMotionChanged = onMotionChanged {
    _transition = HomeArtworkModeTransition(
      vsync: vsync,
      isMounted: isMounted,
      notifyChanged: notifyChanged,
      onMotionChanged: onMotionChanged,
    );
  }

  final bool Function() _isMounted;
  final VoidCallback _notifyChanged;
  final VoidCallback _onMotionChanged;
  final _mode = XeroxModeController();
  late final HomeArtworkModeTransition _transition;

  /// 执行当前模块中的enabled操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  bool get enabled => _mode.enabled;
  /// 执行当前模块中的preparing操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  bool get preparing => _mode.preparing;
  /// 判断当前状态是否满足指定条件，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  bool get isTransitioning => _transition.isActive;
  /// 执行当前模块中的phase操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  ArtworkModeTransitionPhase? get phase => _transition.phase;
  /// 准备并调度后续任务，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  XeroxJobScheduler get scheduler => _mode.scheduler;

  /// 控制流程的开始、暂停、取消或结束，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void beginPreparation() {
    if (_mode.preparing) return;
    _mode.beginPreparation();
    _notifyChanged();
    _onMotionChanged();
  }

  /// 判断当前状态是否满足指定条件，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void cancelPreparation() {
    _mode.cancelPreparation();
    if (!_isMounted()) return;
    _notifyChanged();
    _onMotionChanged();
  }

  /// 应用选择并更新对应状态，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<void> apply({
    required bool enabled,
    required List<XeroxRasterRequest> requests,
    required List<({int row, int column, Rect rect})> visibleCells,
    required Size viewport,
    required bool reduceMotion,
    required BuildContext context,
  }) async {
    if (!_mode.preparing) beginPreparation();
    try {
      if (enabled) {
        await _mode.prepareEnable(
          requests,
          isActive: _isMounted,
        );
      } else {
        await _mode.prepareDisable(
          requests,
          context,
          isActive: _isMounted,
        );
      }
      if (!_isMounted()) return;

      final exit = SourceTileMotion.exit(visibleCells, viewport);
      final enter = SourceTileMotion.enter(visibleCells);
      if (visibleCells.isEmpty || reduceMotion || exit.tiles.isEmpty) {
        _mode.commit(enabled);
        _notifyChanged();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isMounted()) return;
          _mode.finishTransition();
          _onMotionChanged();
        });
        return;
      }

      _mode.endPreparation();
      await _transition.start(
        exit: exit,
        enter: enter,
        onHandoff: () => _mode.commit(enabled),
        onCompleted: () {
          _mode.finishTransition();
          _onMotionChanged();
        },
      );
    } catch (_) {
      cancelPreparation();
      rethrow;
    } finally {
      if (_isMounted() && _mode.preparing && !_transition.isActive) {
        cancelPreparation();
      }
    }
  }

  /// 协调动画进度与状态过渡，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Widget animateTile(
    int row,
    int column,
    Widget child, {
    required double Function() scale,
    required Size Function(BuildContext) viewport,
  }) => _transition.animateTile(
    row,
    column,
    child,
    scale: scale,
    viewport: viewport,
  );

  /// 释放控制器、订阅、动画及其他持有资源，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void dispose() {
    _transition.dispose();
    _mode.dispose();
  }
}
