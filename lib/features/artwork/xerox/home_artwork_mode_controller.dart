import 'package:material_ui/material_ui.dart';

import '../../canvas/album_grid_snapshot.dart';
import 'home_artwork_mode_transition.dart';
import 'xerox_job_scheduler.dart';
import 'xerox_mode_controller.dart';
import 'xerox_raster_request.dart';

/// Coordinates viewport preparation, resource handoff, and tile choreography.
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

  bool get enabled => _mode.enabled;
  bool get preparing => _mode.preparing;
  bool get isTransitioning => _transition.isActive;
  ArtworkModeTransitionPhase? get phase => _transition.phase;
  XeroxJobScheduler get scheduler => _mode.scheduler;

  void beginPreparation() {
    if (_mode.preparing) return;
    _mode.beginPreparation();
    _notifyChanged();
    _onMotionChanged();
  }

  void cancelPreparation() {
    _mode.cancelPreparation();
    if (!_isMounted()) return;
    _notifyChanged();
    _onMotionChanged();
  }

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

  void dispose() {
    _transition.dispose();
    _mode.dispose();
  }
}
