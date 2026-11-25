// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'xerox_config.dart';
import 'xerox_seed.dart';

/// 封装或定义Xerox着色器渲染器相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxShaderRenderer {
  const XeroxShaderRenderer._();

  /// 根据当前状态和几何参数绘制视觉内容，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  static void paint({
    required ui.Canvas canvas,
    required ui.Size size,
    required ui.Image image,
    required ui.FragmentShader shader,
    required BoxFit fit,
    required String identity,
    required XeroxConfig config,
  }) {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(fit, imageSize, size);
    final source = Alignment.center.inscribe(
      fitted.source,
      ui.Offset.zero & imageSize,
    );
    final destination = Alignment.center.inscribe(
      fitted.destination,
      ui.Offset.zero & size,
    );
    if (destination.isEmpty) return;

    shader
      ..setFloat(0, image.width.toDouble())
      ..setFloat(1, image.height.toDouble())
      ..setFloat(2, source.left)
      ..setFloat(3, source.top)
      ..setFloat(4, source.width)
      ..setFloat(5, source.height)
      ..setFloat(6, destination.left)
      ..setFloat(7, destination.top)
      ..setFloat(8, destination.width)
      ..setFloat(9, destination.height)
      ..setFloat(10, xeroxSeed(identity).toDouble())
      ..setFloat(11, config.edge)
      ..setFloat(12, config.contrast)
      ..setFloat(13, config.grain)
      ..setFloat(14, config.invert ? 1 : 0)
      ..setImageSampler(0, image, filterQuality: ui.FilterQuality.medium);

    canvas.drawRect(destination, ui.Paint()..shader = shader);
  }
}
