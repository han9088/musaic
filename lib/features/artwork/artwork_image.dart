import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

import 'pipeline/artwork_decode_policy.dart';
import 'pipeline/xerox_background_processor.dart';
import 'xerox/xerox_artwork.dart';
import 'xerox/xerox_raster_cache.dart';
import 'xerox/xerox_raster_request.dart';
import 'xerox/xerox_resolution.dart';

/// Single display entry point for original and processed artwork.
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
