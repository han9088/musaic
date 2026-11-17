import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Owns the canvas drift formula and its previous-frame timestamp.
/// Gesture and animation lifecycle decisions remain with the viewport owner.
class CanvasDrift {
  CanvasDrift({math.Random? random})
      : velocity = Offset.fromDirection(
          (random ?? math.Random()).nextDouble() * math.pi * 2,
          12,
        );

  Offset velocity;
  Duration? lastTick;

  void advance(
    Duration elapsed,
    TransformationController transform, {
    required bool enabled,
  }) {
    final previous = lastTick;
    lastTick = elapsed;
    if (previous == null || !enabled) return;

    final dt = ((elapsed - previous).inMicroseconds / 1000000).clamp(0.0, 0.05);
    final speed = velocity.distance;
    const decay = 2.2;
    final attenuation = math.exp(-decay * dt);
    final distance = 12 * dt + (speed - 12) * (1 - attenuation) / decay;
    final displacement = Offset.fromDirection(velocity.direction, distance);
    velocity = Offset.fromDirection(
      velocity.direction,
      12 + (speed - 12) * attenuation,
    );
    final matrix = transform.value.clone();
    matrix.setEntry(0, 3, matrix.entry(0, 3) + displacement.dx);
    matrix.setEntry(1, 3, matrix.entry(1, 3) + displacement.dy);
    transform.value = matrix;
  }
}
