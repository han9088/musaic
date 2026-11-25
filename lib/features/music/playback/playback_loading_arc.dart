import 'dart:math' as math;

import 'package:flutter/material.dart';

class PlaybackLoadingArc extends StatefulWidget {
  const PlaybackLoadingArc({super.key});

  @override
  State<PlaybackLoadingArc> createState() => _PlaybackLoadingArcState();
}

class _PlaybackLoadingArcState extends State<PlaybackLoadingArc>
    with SingleTickerProviderStateMixin {
  late final _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final _painter = _PlaybackLoadingArcPainter(_rotation);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _rotation.reset();
    } else if (!_rotation.isAnimating) {
      _rotation.repeat();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: CustomPaint(painter: _painter));
}

class _PlaybackLoadingArcPainter extends CustomPainter {
  _PlaybackLoadingArcPainter(this.rotation) : super(repaint: rotation);

  final Animation<double> rotation;
  final Paint _paint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = size.shortestSide;
    _paint.strokeWidth = (diameter * 0.035).clamp(1.4, 2.4);
    canvas.drawArc(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: diameter * 0.425,
      ),
      rotation.value * 2 * math.pi - math.pi * 0.45,
      math.pi * 0.4,
      false,
      _paint,
    );
  }

  @override
  bool shouldRepaint(_PlaybackLoadingArcPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}
