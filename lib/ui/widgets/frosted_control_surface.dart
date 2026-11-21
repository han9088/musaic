import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show VelocityTracker, kPrimaryButton;
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:material_ui/material_ui.dart';

part 'frosted_control_pair.dart';

class FrostedControlSurface extends StatelessWidget {
  const FrostedControlSurface({
    super.key,
    required this.child,
    required this.visible,
    this.outline = BorderSide.none,
  });

  static const compactHeight = 38.0;
  static const _tint = Color(0x490F1115);
  static const _noise = AssetImage('assets/textures/dialog_noise.png');
  static final _blur = ImageFilter.blur(sigmaX: 12, sigmaY: 12);

  final Widget child;
  final bool visible;
  final BorderSide outline;

  @override
  Widget build(BuildContext context) {
    final backdropPaintedByPair =
        context
            .dependOnInheritedWidgetOfExactType<_SharedGlassBackdrop>()
            ?.active ??
        false;
    return ClipPath(
      clipper: const ShapeBorderClipper(shape: StadiumBorder()),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: visible ? 1.0 : 0.0),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        child: child,
        builder: (context, opacity, child) => _material(
          opacity: backdropPaintedByPair ? 0 : opacity,
          shape: StadiumBorder(
            side: outline.copyWith(
              color: outline.color.withValues(alpha: outline.color.a * opacity),
            ),
          ),
          child: Opacity(
            opacity: opacity,
            child: TickerMode(enabled: opacity > 0, child: child!),
          ),
        ),
      ),
    );
  }

  static Widget _material({
    required double opacity,
    required ShapeBorder shape,
    required Widget child,
  }) {
    final shown = opacity > 0;
    // A backdrop filter inside an opacity layer can sample an empty backdrop.
    final filter = opacity == 1 || !shown
        ? _blur
        : ImageFilter.compose(
            inner: _blur,
            outer: ColorFilter.mode(
              Colors.white.withValues(alpha: opacity),
              BlendMode.dstIn,
            ),
          );
    return BackdropFilter(
      enabled: shown,
      filter: filter,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: _tint.withValues(alpha: _tint.a * opacity),
          image: shown
              ? DecorationImage(
                  image: _noise,
                  fit: BoxFit.none,
                  opacity: 0.08 * opacity,
                  filterQuality: FilterQuality.low,
                )
              : null,
          shape: opacity > 0 ? shape : const RoundedRectangleBorder(),
        ),
        child: child,
      ),
    );
  }
}
