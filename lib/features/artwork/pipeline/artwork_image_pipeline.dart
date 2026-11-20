// 文件职责：统一展示原始封面或已缓存的 Xerox 位图，并管理两套 LOD。

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'artwork_decode_policy.dart';
import 'xerox_background_processor.dart';
import '../xerox/xerox_artwork.dart';
import '../xerox/xerox_raster_cache.dart';
import '../xerox/xerox_raster_request.dart';

/// 原图与 Xerox 资源的统一展示入口；两种模式使用不同的渲染路径。
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

class _ArtworkImageState extends State<ArtworkImage> {
  int? _decodeResolution;
  int? _xeroxResolution;
  XeroxRasterKey? _lastBackgroundKey;

  String get _sourceKey => widget.sourceKey ?? widget.image.toString();

  @override
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
      // Xerox 模式只挂载处理后的位图，不在底层保留原图 Image。
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
        final rasterRequest = XeroxRasterRequest(
          identity: widget.identity,
          sourceKey: _sourceKey,
          image: widget.image,
          resolution: rasterResolution,
          originalDecodeResolution: decodeResolution,
          fit: widget.fit ?? BoxFit.scaleDown,
          devicePixelRatio: dpr,
          priority: XeroxRasterPriority.background,
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
