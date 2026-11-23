import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

typedef SpotlightExpansion = ({
  Animation<double> progress,
  RRect Function(Size viewport) shape,
});

/// Keeps the real target visible while dimming the rest of the route.
class GestureGuideSpotlight extends StatefulWidget {
  const GestureGuideSpotlight({
    super.key,
    required this.opacity,
    required this.focus,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
    this.foreground,
    this.expansion,
    this.caption,
  });

  final Animation<double> opacity;
  final Animation<double> focus;
  final Widget child;
  final EdgeInsets padding;
  final Widget Function(BuildContext context, Rect target)? foreground;
  final SpotlightExpansion? expansion;
  final Widget? caption;

  @override
  State<GestureGuideSpotlight> createState() => _GestureGuideSpotlightState();
}

class _GestureGuideSpotlightState extends State<GestureGuideSpotlight> {
  static final _program = ui.FragmentProgram.fromAsset(
    'shaders/gesture_guide_spotlight.frag',
  );
  final _portal = OverlayPortalController()..show();
  ({Size viewport, Rect target})? _anchor;
  ui.FragmentShader? _shader;
  bool _shaderUnavailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadShader());
  }

  Future<void> _loadShader() async {
    try {
      final program = await _program;
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    } catch (error) {
      debugPrint('Could not load gesture guide spotlight: $error');
      if (mounted) setState(() => _shaderUnavailable = true);
    }
  }

  Rect _focusBounds(Rect target, Size viewport) {
    if (_anchor case (viewport: final size, target: final opening)
        when size == viewport) {
      return opening;
    }
    final screen = Offset.zero & viewport;
    final inset = viewport.shortestSide > 16 ? screen.deflate(8) : screen;
    final opening = widget.padding.inflateRect(target).intersect(inset);
    _anchor = (viewport: viewport, target: opening);
    return opening;
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal.overlayChildLayoutBuilder(
    controller: _portal,
    overlayChildBuilder: (context, layout) {
      final target = MatrixUtils.transformRect(
        layout.childPaintTransform,
        Offset.zero & layout.childSize,
      );
      if (!target.isFinite || target.isEmpty) return const SizedBox.shrink();
      final opening = _focusBounds(target, layout.overlaySize);
      return SizedBox.fromSize(
        size: layout.overlaySize,
        child: IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!opening.isEmpty && (_shader != null || _shaderUnavailable))
                FadeTransition(
                  opacity: widget.opacity,
                  child: CustomPaint(
                    painter: _SpotlightMask(
                      opening,
                      _shader,
                      widget.focus,
                      widget.expansion,
                    ),
                  ),
                ),
              if (widget.foreground case final foreground?)
                foreground(context, target),
              if (widget.caption case final caption?)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: FadeTransition(
                      opacity: widget.focus.drive(
                        CurveTween(curve: const Interval(0.84, 1)),
                      ),
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        child: caption,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
    child: widget.child,
  );
}

class _SpotlightMask extends CustomPainter {
  _SpotlightMask(this.target, this.shader, this.focus, this.expansion)
    : super(repaint: Listenable.merge([focus, expansion?.progress]));

  final Rect target;
  final ui.FragmentShader? shader;
  final Animation<double> focus;
  final SpotlightExpansion? expansion;

  static const _feather = 32.0;
  static const _fallbackBlur = _feather / 4;
  static final _fallbackPaint = Paint()
    ..color = const Color(0xFF000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _fallbackBlur);

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    var shape = RRect.fromRectAndRadius(
      target,
      Radius.circular(target.shortestSide / 2),
    );
    if (expansion case (progress: final progress, shape: final expanded)
        when progress.value > 0) {
      shape = RRect.lerp(shape, expanded(size), progress.value)!;
    }
    final opening = shape.inflate(size.longestSide * 0.66 * (1 - focus.value));
    final radius = math.min(opening.tlRadiusX, opening.shortestSide / 2);
    if (shader case final mask?) {
      mask
        ..setFloat(0, opening.center.dx)
        ..setFloat(1, opening.center.dy)
        ..setFloat(2, opening.width / 2)
        ..setFloat(3, opening.height / 2)
        ..setFloat(4, radius)
        ..setFloat(5, _feather);
      canvas.drawRect(screen, Paint()..shader = mask);
      return;
    }

    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(screen.inflate(_fallbackBlur * 4))
      ..addRRect(opening.inflate(_feather / 2));
    canvas.save();
    canvas.clipRect(screen);
    canvas.drawPath(mask, _fallbackPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpotlightMask oldDelegate) =>
      target != oldDelegate.target ||
      shader != oldDelegate.shader ||
      focus != oldDelegate.focus ||
      expansion != oldDelegate.expansion;
}
