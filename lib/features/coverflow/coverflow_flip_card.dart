import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../ui/transitions/rect_flip_transition.dart';

class CoverFlowFlipCard extends StatelessWidget {
  const CoverFlowFlipCard({
    super.key,
    required this.progress,
    required this.source,
    required this.destination,
    required this.child,
    this.back,
  });

  static const reflectionFraction = 0.36;
  // Finish rotating before the last stretch of the enlargement.
  static const turnCurve = Interval(0, 0.8, curve: Curves.easeInOutSine);

  final Animation<double> progress;
  final Rect source;
  final Rect destination;
  final Widget child;
  final Widget? back;

  static Rect? destinationFor(Size viewport, Rect source) {
    const top = 64.0;
    final bottom = source.top - 20;
    final size = math.min(viewport.width - 32, bottom - top);
    if (size <= source.width) return null;
    return Rect.fromCenter(
      center: Offset(viewport.width / 2, (top + bottom) / 2),
      width: size,
      height: size,
    );
  }

  static double scaleAt(double progress, double from, double to) =>
      lerpDouble(1, to / from, progress)!;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final t = progress.value;
        final turn = turnCurve.transform(t);
        final reverse = back;
        return Transform(
          key: const ValueKey('cover-flow-flipping-card'),
          // Pivot around the artwork center. The reflection sits below it.
          alignment: const Alignment(0, 1 / (1 + reflectionFraction) - 1),
          transform: RectFlipTransition.transform(
            layout: source,
            rect: Rect.lerp(source, destination, t)!,
            turnProgress: reducedMotion ? 0 : turn,
            axis: Axis.vertical,
          ),
          child: reverse != null && turn >= 0.5
              ? IgnorePointer(ignoring: t < 1, child: reverse)
              : child,
        );
      },
    );
  }
}
