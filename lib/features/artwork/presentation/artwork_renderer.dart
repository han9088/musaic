// 文件职责：将 Pipeline 已解析的原图或 Xerox 位图绘制到界面。

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../model/artwork_resource.dart';
import '../pipeline/artwork_pipeline.dart';
import 'xerox_palette.dart';

/// 纯渲染组件：只消费原图资源、LOD 计划或已处理位图，不操作缓存和任务队列。
class ArtworkRenderer extends StatelessWidget {
  const ArtworkRenderer({
    super.key,
    required this.resource,
    required this.plan,
    required this.width,
    required this.height,
    required this.fit,
    required this.filterQuality,
    required this.semanticLabel,
    required this.excludeFromSemantics,
    required this.xerox,
    required this.placeholder,
    this.processedImage,
  });

  final ArtworkResource resource;
  final ArtworkDisplayPlan plan;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final FilterQuality filterQuality;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final bool xerox;
  final Widget placeholder;
  final ui.Image? processedImage;

  @override
  Widget build(BuildContext context) {
    if (xerox) {
      final image = processedImage;
      if (image == null) return placeholder;
      final bitmap = RawImage(
        image: image,
        width: width,
        height: height,
        fit: fit,
        filterQuality: filterQuality,
      );
      final filter = XeroxPaletteScope.of(context).filter;
      return Semantics(
        image: true,
        label: excludeFromSemantics ? null : semanticLabel,
        excludeSemantics: excludeFromSemantics,
        child: filter == null
            ? bitmap
            : ColorFiltered(colorFilter: filter, child: bitmap),
      );
    }

    return Image(
      image: ResizeImage(
        resource.image,
        width: plan.originalDecodeResolution,
        height: plan.originalDecodeResolution,
      ),
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
