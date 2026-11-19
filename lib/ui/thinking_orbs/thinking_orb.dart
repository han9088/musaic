// 文件职责：思考光球的状态驱动、几何计算与绘制动画。

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

part 'thinking_orb_engine.dart';

/// 封装或定义思考光球状态相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
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

/// 封装或定义思考光球尺寸相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
enum ThinkingOrbSize {
  regular(64),
  inline(20);

  const ThinkingOrbSize(this.pixels);

  final double pixels;
}

/// 封装或定义思考光球主题相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
enum ThinkingOrbTheme { auto, dark, light }

/// 封装或定义思考光球状态label相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
extension ThinkingOrbStateLabel on ThinkingOrbState {
  /// 执行当前模块中的label操作，用于思考光球的状态驱动、几何计算与绘制动画。
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
/// 执行当前模块中的debug绘制思考光球frame操作，用于思考光球的状态驱动、几何计算与绘制动画。
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

/// 封装或定义思考光球相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
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

/// 封装或定义思考光球状态相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
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
