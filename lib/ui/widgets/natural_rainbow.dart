import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

part 'natural_rainbow_painter.dart';

/// A transparent, bottom-aligned rainbow rendered entirely with Canvas.
///
/// With [autoPlay] off, [progress] is visibility: 0 is absent, 1 fully formed.
/// Automatic playback fades in, rests with subtle light variation, then fades
/// out; [duration] covers one complete loop. Reduced motion uses [progress].
/// [radius] is the spectrum's central radius; [thickness] is its spectral width
/// in logical pixels. Both adapt to the available space when omitted.
class NaturalRainbow extends StatefulWidget {
  const NaturalRainbow({
    super.key,
    this.progress = 1,
    this.intensity = 1,
    this.radius,
    this.thickness,
    this.softness = 0.8,
    this.glowIntensity = 0.18,
    this.autoPlay = true,
    this.duration = const Duration(seconds: 18),
    this.sweepAngle,
    this.eraseAngle,
  }) : assert(progress >= 0 && progress <= 1),
       assert(intensity >= 0 && intensity < double.infinity),
       assert(radius == null || (radius > 0 && radius < double.infinity)),
       assert(
         thickness == null || (thickness > 0 && thickness < double.infinity),
       ),
       assert(softness >= 0 && softness <= 1),
       assert(glowIntensity >= 0 && glowIntensity < double.infinity);

  final double progress;
  final double intensity;
  final double? radius;
  final double? thickness;
  final double softness;
  final double glowIntensity;
  final bool autoPlay;
  final Duration duration;

  /// Optional hinge-driven reveal, in radians from 0 to pi. Its right endpoint
  /// stays fixed; inner hues lead the outer hues while opening. Only painting
  /// listens to changes, without rebuilding widgets.
  final ValueListenable<double>? sweepAngle;

  /// Removes the arc from right to left, in radians from 0 to pi. Inner hues
  /// lead the outer hues while disappearing.
  final ValueListenable<double>? eraseAngle;

  @override
  State<NaturalRainbow> createState() => _NaturalRainbowState();
}

class _NaturalRainbowState extends State<NaturalRainbow>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  bool get _playing =>
      widget.autoPlay &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _syncAnimation() {
    assert(widget.duration > Duration.zero);
    _animation.duration = widget.duration;
    if (_playing) {
      _animation.repeat();
    } else {
      _animation.stop();
      _animation.value = widget.progress;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(NaturalRainbow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.progress != widget.progress ||
        oldWidget.duration != widget.duration) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ClipRect(
      child: CustomPaint(
        painter: _NaturalRainbowPainter(_animation, widget, _playing),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

