// 文件职责：Cover Flow 的几何计算、输入处理与动效。

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../ui/theme/app_spacing.dart';

/// 封装或定义封面流动几何相关类型与行为，负责Cover Flow 的几何计算、输入处理与动效。
class CoverFlowGeometry {
  const CoverFlowGeometry._();

  static const _portraitBottom = AppSpacing.playbackBottom + 40.0;

  static double coverSize(Size viewport) =>
      math.min(viewport.height * 0.65, viewport.width * 0.31);

  static Alignment alignment({
    required bool portrait,
    required double height,
    required double coverSize,
    required double bottomPadding,
  }) {
    if (!portrait || height <= 0) return const Alignment(0, 0.04);

    final bottomGap = (_portraitBottom - bottomPadding).clamp(
      0.0,
      height - coverSize,
    );
    final centerY = height - bottomGap - coverSize / 2;
    return Alignment(0, 2 * centerY / height - 1);
  }

  static ({Map<int, double> widths, Map<int, double> centers, double anchor})
  calculate({
    required List<int> indices,
    required double position,
    required double size,
  }) {
    assert(indices.length >= 2);
    final widths = <int, double>{
      for (final index in indices)
        index:
            size * (0.7 + 0.3 * (1 - (index - position).abs()).clamp(0.0, 1.0)),
    };
    final centers = <int, double>{indices.first: 0};
    for (var i = 1; i < indices.length; i++) {
      final previous = indices[i - 1];
      final current = indices[i];
      centers[current] =
          centers[previous]! + (widths[previous]! + widths[current]!) / 2 + 6;
    }
    final lower = position.floor();
    final fraction = position - lower;
    final anchor =
        centers[lower]! * (1 - fraction) + centers[lower + 1]! * fraction;
    return (widths: widths, centers: centers, anchor: anchor);
  }
}
