import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../canvas/album_grid_snapshot.dart';
import 'music_source_transition.dart';

/// Owns the exit -> handoff -> enter timeline; page-side data commits are
/// passed through onHandoff to preserve the original playback binding order.
enum SourceTransitionPhase { exit, handoff, enter }

class HomeSourceTransition {
  HomeSourceTransition({
    required TickerProvider vsync,
    required bool Function() isMounted,
    required VoidCallback notifyChanged,
    required void Function(List<Map<String, dynamic>>) onHandoff,
    required VoidCallback onMotionChanged,
  }) : _isMounted = isMounted,
       _notifyChanged = notifyChanged,
       _onHandoff = onHandoff,
       _onMotionChanged = onMotionChanged {
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

  Future<void> start({
    required List<Map<String, dynamic>> targetAlbums,
    required ({Map<(int, int), SourceTileMotion> tiles, double durationMs}) exit,
    required ({Map<(int, int), SourceTileMotion> tiles, double durationMs}) enter,
  }) {
    exitMotions = exit.tiles;
    enterMotions = enter.tiles;
    exitDurationMs = exit.durationMs;
    sourceDurationMs =
        (exit.durationMs + sourceHandoffMs + enter.durationMs).ceilToDouble();
    this.targetAlbums = targetAlbums;
    _completer = Completer<void>();
    timeline.duration = Duration(milliseconds: sourceDurationMs.ceil());
    phase = SourceTransitionPhase.exit;
    _notifyChanged();
    _onMotionChanged();
    timeline.forward(from: 0);
    return _completer!.future;
  }

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

  void _finish() {
    final done = _completer;
    _completer = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  Widget animateTile(
    int row,
    int column,
    Widget child, {
    required double Function() scale,
    required Size Function(BuildContext) viewport,
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

  void dispose() {
    _finish();
    timeline.dispose();
    switching.dispose();
  }
}
