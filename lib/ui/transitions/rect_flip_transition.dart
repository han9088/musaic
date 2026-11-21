import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Flips a surface around its vertical axis as it expands between two rects.
class RectFlipTransition extends StatelessWidget {
  const RectFlipTransition({
    super.key,
    required this.origin,
    required this.target,
    required this.animation,
    required this.child,
  });

  static const duration = Duration(milliseconds: 460);

  static Rect originOf(BuildContext source, NavigatorState navigator) {
    final overlay = navigator.overlay!.context.findRenderObject()!;
    final anchor = source.findRenderObject()! as RenderBox;
    return MatrixUtils.transformRect(
      anchor.getTransformTo(overlay),
      Offset.zero & anchor.size,
    );
  }

  final Rect origin;
  final Rect target;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final progress = Curves.easeInOutCubic.transform(animation.value);
      final rect = Rect.lerp(origin, target, progress)!;
      final offset = rect.center - target.center;
      // Swap faces at edge-on to keep the surface readable on both sides.
      final angle = math.pi * (progress < 0.5 ? progress : progress - 1);
      final perspective = Matrix4.identity()
        ..setEntry(3, 2, 0.7 / target.width)
        ..rotateY(-angle);
      return IgnorePointer(
        ignoring: animation.value < 1,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(offset.dx, offset.dy, 0, 1)
            ..scaleByDouble(
              rect.width / target.width,
              rect.height / target.height,
              1,
              1,
            )
            ..multiply(perspective),
          child: child,
        ),
      );
    },
  );
}
