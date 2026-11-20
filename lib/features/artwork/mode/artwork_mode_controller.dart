// 文件职责：Artwork 模式和配色切换、资源准备、动画交接和 Lease 生命周期。

import 'package:material_ui/material_ui.dart';

import '../../../ui/transitions/source_tile_motion.dart';
import '../pipeline/artwork_prefetch_scheduler.dart';
import '../presentation/xerox_palette.dart';
import '../xerox/xerox_job_scheduler.dart';
import '../xerox/xerox_raster_cache.dart';
import '../xerox/xerox_raster_request.dart';
import 'artwork_mode_transition.dart';

/// 统一协调 Original 与 Xerox 两种显示模式。
///
/// 这里只管理 Artwork 的模式状态和切换过程；具体 Raster 处理由 XeroxJobScheduler
/// 负责，原图预热由 ArtworkPrefetchScheduler 负责。
class ArtworkModeController {
  ArtworkModeController({
    required TickerProvider vsync,
    required bool Function() isMounted,
    required VoidCallback notifyChanged,
    required VoidCallback onMotionChanged,
    XeroxJobScheduler? scheduler,
    ArtworkPrefetchScheduler? prefetchScheduler,
  }) : _isMounted = isMounted,
       _notifyChanged = notifyChanged,
       _onMotionChanged = onMotionChanged,
       scheduler = scheduler ?? XeroxJobScheduler(),
       _prefetchScheduler =
           prefetchScheduler ?? const ArtworkPrefetchScheduler() {
    _transition = ArtworkModeTransition(
      vsync: vsync,
      isMounted: isMounted,
      notifyChanged: notifyChanged,
      onMotionChanged: onMotionChanged,
    );
  }

  final bool Function() _isMounted;
  final VoidCallback _notifyChanged;
  final VoidCallback _onMotionChanged;
  final XeroxJobScheduler scheduler;
  final ArtworkPrefetchScheduler _prefetchScheduler;
  final _preparedLeases = <XeroxRasterLease>[];
  final palette = ValueNotifier(XeroxPalette.original);
  late final ArtworkModeTransition _transition;

  bool enabled = false;
  bool preparing = false;

  bool get isTransitioning => _transition.isActive;
  ArtworkModeTransitionPhase? get phase => _transition.phase;

  void beginPreparation() {
    if (preparing) return;
    preparing = true;
    _notifyChanged();
    _onMotionChanged();
  }

  void cancelPreparation() {
    preparing = false;
    _releasePrepared();
    if (!_isMounted()) return;
    _notifyChanged();
    _onMotionChanged();
  }

  /// 先准备目标模式所需资源，再执行 Exit → Handoff → Enter。
  Future<void> apply({
    required bool enabled,
    required List<XeroxRasterRequest> requests,
    required List<({int row, int column, Rect rect})> visibleCells,
    required Size viewport,
    required bool reduceMotion,
    required BuildContext context,
  }) async {
    if (!preparing) beginPreparation();
    try {
      if (enabled) {
        await _prepareXerox(requests);
      } else {
        await _prepareOriginals(requests, context);
      }
      if (!_isMounted()) return;

      await _animateChange(
        visibleCells: visibleCells,
        viewport: viewport,
        reduceMotion: reduceMotion,
        onHandoff: () => _commit(enabled),
        onCompleted: _finishTransition,
      );
    } catch (_) {
      cancelPreparation();
      rethrow;
    } finally {
      if (_isMounted() && preparing && !_transition.isActive) {
        cancelPreparation();
      }
    }
  }

  Future<void> applyPalette({
    required XeroxPalette selection,
    required List<({int row, int column, Rect rect})> visibleCells,
    required Size viewport,
    required bool reduceMotion,
  }) async {
    if (!enabled ||
        preparing ||
        isTransitioning ||
        selection == palette.value) {
      return;
    }
    await _animateChange(
      visibleCells: visibleCells,
      viewport: viewport,
      reduceMotion: reduceMotion,
      onHandoff: () => palette.value = selection,
    );
  }

  Future<void> _animateChange({
    required List<({int row, int column, Rect rect})> visibleCells,
    required Size viewport,
    required bool reduceMotion,
    required VoidCallback onHandoff,
    VoidCallback? onCompleted,
  }) async {
    if (reduceMotion || visibleCells.isEmpty) {
      onHandoff();
      if (onCompleted != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isMounted()) onCompleted();
        });
      }
      return;
    }

    preparing = false;
    await _transition.start(
      exit: SourceTileMotion.exit(visibleCells, viewport),
      enter: SourceTileMotion.enter(visibleCells),
      onHandoff: onHandoff,
      onCompleted: onCompleted,
    );
  }

  Future<void> _prepareXerox(List<XeroxRasterRequest> requests) async {
    preparing = true;
    _releasePrepared();
    final leases = await scheduler.prepare(requests, isActive: _isMounted);
    if (!_isMounted()) {
      for (final lease in leases) {
        lease.release();
      }
      throw StateError('Xerox mode preparation was cancelled.');
    }
    _preparedLeases.addAll(leases);
  }

  Future<void> _prepareOriginals(
    List<XeroxRasterRequest> requests,
    BuildContext context,
  ) => _prefetchScheduler.warmProviders(
    requests.map(
      (request) => (
        image: request.image,
        sourceKey: request.sourceKey,
        decodeResolution: request.originalDecodeResolution,
      ),
    ),
    context,
    isActive: _isMounted,
  );

  void _commit(bool value) {
    enabled = value;
    preparing = false;
    _notifyChanged();
  }

  void _finishTransition() {
    preparing = false;
    _releasePrepared();
    if (!_isMounted()) return;
    _notifyChanged();
    _onMotionChanged();
  }

  Widget animateTile(
    int row,
    int column,
    Widget child, {
    required double Function() scale,
    required Size Function(BuildContext) viewport,
    required double tileSize,
  }) => _transition.animateTile(
    row,
    column,
    child,
    scale: scale,
    viewport: viewport,
    tileSize: tileSize,
  );

  void _releasePrepared() {
    for (final lease in _preparedLeases) {
      lease.release();
    }
    _preparedLeases.clear();
  }

  void dispose() {
    palette.dispose();
    _transition.dispose();
    _releasePrepared();
  }
}
