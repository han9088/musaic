// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

import 'pipeline/artwork_decode_policy.dart';
import 'pipeline/xerox_background_processor.dart';
import 'xerox/xerox_artwork.dart';
import 'xerox/xerox_raster_cache.dart';
import 'xerox/xerox_raster_request.dart';
import 'xerox/xerox_resolution.dart';

/// 封装或定义封面图图片相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class ArtworkImage extends StatefulWidget {
  const ArtworkImage({
    super.key,
    required this.identity,
    required this.image,
    this.sourceKey,
    this.width,
    this.height,
    this.fit,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.xerox = false,
    this.scale = 1,
    this.errorBuilder,
    this.xeroxCache,
    this.backgroundProcessor,
  });

  final String identity;
  /// Source revision used to invalidate stale Xerox cache entries.
  final String? sourceKey;
  final ImageProvider<Object> image;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final FilterQuality filterQuality;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final bool xerox;
  final double scale;
  final ImageErrorWidgetBuilder? errorBuilder;
  final XeroxRasterCache? xeroxCache;
  final XeroxBackgroundProcessor? backgroundProcessor;

  @override
  State<ArtworkImage> createState() => _ArtworkImageState();
}

/// 封装或定义封面图图片状态相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class _ArtworkImageState extends State<ArtworkImage> {
  // 在组件重建之间保留当前 LOD，以便缩放时应用滞回阈值。
  int? _decodeResolution;
  int? _xeroxResolution;
  XeroxRasterKey? _lastBackgroundKey;

  String get _sourceKey => widget.sourceKey ?? widget.image.toString();

  @override
  // 图片来源或显示模式变化时，重置当前组件的 LOD 与后台预处理状态。
  void didUpdateWidget(ArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.sourceKey != widget.sourceKey ||
        oldWidget.image.toString() != widget.image.toString() ||
        (oldWidget.xerox && !widget.xerox)) {
      _decodeResolution = null;
      _xeroxResolution = null;
      _lastBackgroundKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.xerox) {
      return XeroxArtwork(
        identity: widget.identity,
        sourceKey: _sourceKey,
        image: widget.image,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        semanticLabel: widget.semanticLabel,
        excludeFromSemantics: widget.excludeFromSemantics,
        scale: widget.scale,
        errorBuilder: widget.errorBuilder,
        cache: widget.xeroxCache,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = widget.width ?? constraints.maxWidth;
        final height = widget.height ?? constraints.maxHeight;
        final extent = math.max(
          width.isFinite ? width : 100,
          height.isFinite ? height : 100,
        );
        final dpr = MediaQuery.devicePixelRatioOf(context);
        // 选择解码档位前，先将卡片逻辑尺寸换算为物理像素。
        final physicalExtent = extent * widget.scale * dpr;
        final decodeResolution = artworkDecodeResolution(
          physicalExtent,
          current: _decodeResolution,
        );
        _decodeResolution = decodeResolution;

        final rasterResolution = xeroxResolution(
          physicalExtent,
          current: _xeroxResolution,
        );
        _xeroxResolution = rasterResolution;
        // Xerox 输出尺寸与原图解码尺寸分别计算，避免混用两套分辨率策略。
        final rasterRequest = XeroxRasterRequest(
          identity: widget.identity,
          sourceKey: _sourceKey,
          image: widget.image,
          resolution: rasterResolution,
          fit: widget.fit ?? BoxFit.scaleDown,
          devicePixelRatio: dpr,
        );

        return Image(
          image: ResizeImage(
            widget.image,
            width: decodeResolution,
            height: decodeResolution,
          ),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          semanticLabel: widget.semanticLabel,
          excludeFromSemantics: widget.excludeFromSemantics,
          gaplessPlayback: true,
          errorBuilder: widget.errorBuilder,
          // 原图成功解码并产生可显示帧后，再启动开销较大的后台处理。
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if ((frame != null || wasSynchronouslyLoaded) &&
                _lastBackgroundKey != rasterRequest.key) {
              _lastBackgroundKey = rasterRequest.key;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || widget.xerox) return;
                (widget.backgroundProcessor ??
                        XeroxBackgroundProcessor.instance)
                    .enqueue(rasterRequest);
              });
            }
            return child;
          },
        );
      },
    );
  }
}
