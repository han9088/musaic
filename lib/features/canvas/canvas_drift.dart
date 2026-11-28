// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// 封装或定义画布漂移相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class CanvasDrift {
  CanvasDrift({math.Random? random})
    : velocity = Offset.fromDirection(
        (random ?? math.Random()).nextDouble() * math.pi * 2,
        idleSpeed,
      );

  static const idleSpeed = 12.0;
  Offset velocity;
  Duration? lastTick;

  /// 执行当前模块中的advance操作，用于专辑墙无限画布的布局、视口与交互状态。
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
    final distance =
        idleSpeed * dt + (speed - idleSpeed) * (1 - attenuation) / decay;
    final displacement = Offset.fromDirection(velocity.direction, distance);
    velocity = Offset.fromDirection(
      velocity.direction,
      idleSpeed + (speed - idleSpeed) * attenuation,
    );
    final matrix = transform.value.clone();
    matrix.setEntry(0, 3, matrix.entry(0, 3) + displacement.dx);
    matrix.setEntry(1, 3, matrix.entry(1, 3) + displacement.dy);
    transform.value = matrix;
  }
}
