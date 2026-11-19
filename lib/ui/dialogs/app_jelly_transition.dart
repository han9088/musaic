// 文件职责：对话框、通知及其转场和展示管理。

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// 封装或定义应用果冻过渡相关类型与行为，负责对话框、通知及其转场和展示管理。
class AppJellyTransition extends StatelessWidget {
  const AppJellyTransition({
    super.key,
    required this.animation,
    required this.child,
    this.transformKey,
    this.alignment = Alignment.center,
    this.openingOffset = const Offset(0, 20),
  });

  final Animation<double> animation;
  final Widget child;
  final Key? transformKey;
  final AlignmentGeometry alignment;
  final Offset openingOffset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        final closing = animation.status == AnimationStatus.reverse;

        final double scaleX;
        final double scaleY;
        final Offset offset;
        final double opacity;

        if (closing) {
          final eased = Curves.easeOutCubic.transform(t);
          scaleX = 0.94 + (0.06 * eased);
          scaleY = 0.96 + (0.04 * eased);
          offset = openingOffset * (0.5 * (1 - eased));
          opacity = t;
        } else {
          final spring = const _JellySpringCurve().transform(t);
          final wobble = math.sin(t * math.pi * 3) * math.exp(-5.8 * t) * 0.032;
          final baseScale = 0.84 + (0.16 * spring);
          scaleX = baseScale + wobble;
          scaleY = baseScale - wobble;
          offset = openingOffset * (1 - Curves.easeOutCubic.transform(t));
          opacity = const Interval(0, 0.22, curve: Curves.easeOut).transform(t);
        }

        return Opacity(
          opacity: opacity.clamp(0, 1),
          child: Transform.translate(
            offset: offset,
            child: Transform(
              key: transformKey,
              alignment: alignment,
              transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// 封装或定义果冻弹簧curve相关类型与行为，负责对话框、通知及其转场和展示管理。
class _JellySpringCurve extends Curve {
  const _JellySpringCurve();

  @override
  double transformInternal(double t) {
    if (t == 0 || t == 1) return t;
    return 1 - (math.exp(-7.5 * t) * math.cos(12 * t));
  }
}
