import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

part 'thinking_orb_engine.dart';

/// The nine animation states from Jakub Antalik's thinking-orbs.
enum ThinkingOrbState {
  working,
  searching,
  solving,
  listening,
  connecting,
  weaving,
  composing,
  breathing,
  shaping,
}

/// The source project ships two separately tuned designs, not arbitrary scale.
enum ThinkingOrbSize {
  regular(64),
  inline(20);

  const ThinkingOrbSize(this.pixels);

  final double pixels;
}

enum ThinkingOrbTheme { auto, dark, light }

extension ThinkingOrbStateLabel on ThinkingOrbState {
  String get label => switch (this) {
    ThinkingOrbState.working => 'Working…',
    ThinkingOrbState.searching => 'Searching…',
    ThinkingOrbState.solving => 'Solving…',
    ThinkingOrbState.listening => 'Listening…',
    ThinkingOrbState.connecting => 'Connecting…',
    ThinkingOrbState.weaving => 'Weaving…',
    ThinkingOrbState.composing => 'Composing…',
    ThinkingOrbState.breathing => 'Thinking…',
    ThinkingOrbState.shaping => 'Shaping…',
  };
}

@visibleForTesting
void debugPaintThinkingOrbFrame(
  Canvas canvas, {
  required ThinkingOrbState state,
  required ThinkingOrbSize size,
  double time = 0.6,
  bool dark = true,
}) {
  final preset = _resolvePreset(state, size);
  _drawMode(canvas, size.pixels, time, dark, preset);
}

/// Flutter port of https://github.com/Jakubantalik/thinking-orbs.
///
/// It retains the original nine painters, the independently tuned 64/20
/// presets, monochrome depth shading, shared clock, pause behavior, and a
/// static representative frame when animations are disabled.
class ThinkingOrb extends StatefulWidget {
  const ThinkingOrb({
    super.key,
    this.state = ThinkingOrbState.working,
    this.size = ThinkingOrbSize.regular,
    this.theme = ThinkingOrbTheme.auto,
    this.speed = 1,
    this.paused = false,
    this.semanticLabel,
  }) : assert(speed >= 0);

  final ThinkingOrbState state;
  final ThinkingOrbSize size;
  final ThinkingOrbTheme theme;
  final double speed;
  final bool paused;
  final String? semanticLabel;

  @override
  State<ThinkingOrb> createState() => _ThinkingOrbState();
}

class _ThinkingOrbState extends State<ThinkingOrb>
    with SingleTickerProviderStateMixin {
  static final Stopwatch _sharedClock = Stopwatch()..start();

  late final AnimationController _repaint;
  bool _reduceMotion = false;
  double? _pausedAt;

  double get _sharedSeconds =>
      _sharedClock.elapsedMicroseconds / Duration.microsecondsPerSecond;

  @override
  void initState() {
    super.initState();
    _repaint = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.paused) _pausedAt = _sharedSeconds;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncTicker();
  }

  @override
  void didUpdateWidget(ThinkingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.paused && widget.paused) {
      _pausedAt = _sharedSeconds;
    } else if (oldWidget.paused && !widget.paused) {
      _pausedAt = null;
    } else if (widget.paused && oldWidget.speed != widget.speed) {
      _pausedAt = _sharedSeconds;
    }
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.paused || _reduceMotion || widget.speed == 0) {
      _repaint.stop();
    } else if (!_repaint.isAnimating) {
      _repaint.repeat();
    }
  }

  @override
  void dispose() {
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = switch (widget.theme) {
      ThinkingOrbTheme.auto => Theme.of(context).brightness == Brightness.dark,
      ThinkingOrbTheme.dark => true,
      ThinkingOrbTheme.light => false,
    };
    final dimension = widget.size.pixels;
    final time = _reduceMotion
        ? 0.6
        : (_pausedAt ?? _sharedSeconds) * widget.speed;

    return Semantics(
      image: true,
      label: widget.semanticLabel ?? widget.state.label,
      child: SizedBox.square(
        dimension: dimension,
        child: CustomPaint(
          key: const Key('thinking-orb-canvas'),
          painter: _ThinkingOrbPainter(
            state: widget.state,
            presetSize: widget.size,
            dark: dark,
            initialTime: time,
            speed: widget.speed,
            paused: widget.paused || _reduceMotion || widget.speed == 0,
            reducedMotion: _reduceMotion,
            sharedSeconds: () => _sharedSeconds,
            repaint: _repaint,
          ),
        ),
      ),
    );
  }
}
