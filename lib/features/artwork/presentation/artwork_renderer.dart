// 文件职责：将 Pipeline 已解析的原图或 Xerox 位图绘制到界面。

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../model/artwork_resource.dart';
import '../pipeline/artwork_lod_manager.dart';
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

  ImageProvider<Object> get originalImageProvider =>
      _resize(plan.originalDecodeResolution);

  @override
  Widget build(BuildContext context) {
    if (xerox) {
      final image = processedImage;
      if (image == null) return placeholder;
      return Semantics(
        image: true,
        label: excludeFromSemantics ? null : semanticLabel,
        excludeSemantics: excludeFromSemantics,
        child: _XeroxBitmap(
          image: image,
          width: width,
          height: height,
          fit: fit,
          filterQuality: filterQuality,
          filter: XeroxPaletteScope.of(context).filter,
        ),
      );
    }

    return _originalImage(
      originalImageProvider,
      frameBuilder: (context, child, frame, _) {
        if (frame != null) return child;
        final cached = _cachedOriginal(context);
        return cached == null ? child : _originalImage(cached);
      },
    );
  }

  ResizeImage _resize(int resolution) => ResizeImage(
    resource.image,
    width: resolution,
    height: resolution,
    policy: ResizeImagePolicy.fit,
  );

  ImageProvider<Object>? _cachedOriginal(BuildContext context) {
    final config = createLocalImageConfiguration(
      context,
      size: width != null && height != null ? Size(width!, height!) : null,
    );
    for (final resolution in artworkResolutions.reversed) {
      if (resolution == plan.originalDecodeResolution) continue;
      final provider = _resize(resolution);
      final key = provider.obtainKey(config);
      if (key is! SynchronousFuture<ResizeImageKey>) {
        key.ignore();
        continue;
      }
      var ready = false;
      key.then((value) {
        final status = PaintingBinding.instance.imageCache.statusForKey(value);
        ready = !status.pending && (status.keepAlive || status.live);
      });
      if (ready) return provider;
    }
    return null;
  }

  Widget _originalImage(
    ImageProvider<Object> image, {
    ImageFrameBuilder? frameBuilder,
  }) => Image(
    image: image,
    width: width,
    height: height,
    fit: fit,
    filterQuality: filterQuality,
    semanticLabel: semanticLabel,
    excludeFromSemantics: excludeFromSemantics || frameBuilder == null,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => placeholder,
    frameBuilder: frameBuilder,
  );
}

/// Apply paper and ink in the image draw, without replacing the image node.
class _XeroxBitmap extends RawImage {
  const _XeroxBitmap({
    required super.image,
    required super.width,
    required super.height,
    required super.fit,
    required super.filterQuality,
    required this.filter,
  });

  final ColorFilter? filter;

  @override
  _RenderXeroxBitmap createRenderObject(BuildContext context) =>
      _RenderXeroxBitmap(
        filter,
        image: image?.clone(),
        width: width,
        height: height,
        fit: fit,
        filterQuality: filterQuality,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderXeroxBitmap renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    renderObject.filter = filter;
  }
}

class _RenderXeroxBitmap extends RenderImage {
  _RenderXeroxBitmap(
    this._filter, {
    super.image,
    super.width,
    super.height,
    super.fit,
    super.filterQuality,
  });

  ColorFilter? _filter;

  set filter(ColorFilter? value) {
    if (_filter == value) return;
    _filter = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final bitmap = image;
    if (bitmap == null) return;
    paintImage(
      canvas: context.canvas,
      rect: offset & size,
      image: bitmap,
      colorFilter: _filter,
      fit: fit,
      filterQuality: filterQuality,
    );
  }
}
