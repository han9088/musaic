import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Flips a surface as it expands between two rects.
class RectFlipTransition extends StatelessWidget {
  const RectFlipTransition({
    super.key,
    required this.origin,
    required this.target,
    required this.animation,
    required this.child,
  });

  static const duration = Duration(milliseconds: 460);
  static const curve = Curves.easeInOutCubic;

  static Rect originOf(BuildContext source, NavigatorState navigator) {
    final overlay = navigator.overlay!.context.findRenderObject()!;
    final anchor = source.findRenderObject()! as RenderBox;
    return MatrixUtils.transformRect(
      anchor.getTransformTo(overlay),
      Offset.zero & anchor.size,
    );
  }

  static Matrix4 transform({
    required Rect layout,
    required Rect rect,
    required double turnProgress,
    Axis axis = Axis.horizontal,
  }) {
    final offset = rect.center - layout.center;
    // Swap faces at edge-on so the artwork reads upright on either side.
    final angle =
        -math.pi * (turnProgress < 0.5 ? turnProgress : turnProgress - 1);
    final perspective = Matrix4.identity()..setEntry(3, 2, 0.7 / layout.width);
    switch (axis) {
      case Axis.horizontal:
        perspective.rotateY(angle);
      case Axis.vertical:
        perspective.rotateX(angle);
    }
    return Matrix4.identity()
      ..translateByDouble(offset.dx, offset.dy, 0, 1)
      ..scaleByDouble(
        rect.width / layout.width,
        rect.height / layout.height,
        1,
        1,
      )
      ..multiply(perspective);
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
      final progress = curve.transform(animation.value);
      final rect = Rect.lerp(origin, target, progress)!;
      return IgnorePointer(
        ignoring: animation.value < 1,
        child: Transform(
          alignment: Alignment.center,
          transform: transform(
            layout: target,
            rect: rect,
            turnProgress: progress,
          ),
          child: child,
        ),
      );
    },
  );
}
