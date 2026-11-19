import 'dart:async';

import 'package:flutter/material.dart';

import 'xerox/xerox_raster_cache.dart';
import 'xerox/xerox_raster_request.dart';
import 'xerox/xerox_resolution.dart';
import 'xerox/xerox_artwork.dart';

/// Displays the original provider and opportunistically prepares its Xerox
/// raster after the original has decoded successfully.
class ArtworkImage extends StatefulWidget {
  const ArtworkImage({
    super.key,
    required this.identity,
    required this.image,
    this.width,
    this.height,
    this.fit,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.xerox = false,
    this.scale = 1,
    this.errorBuilder,
  });

  final String identity;
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

  @override
  State<ArtworkImage> createState() => _ArtworkImageState();
}

class _ArtworkImageState extends State<ArtworkImage> {
  XeroxRasterKey? _preparingKey;
  int _generation = 0;
  XeroxRasterTask? _task;

  @override
  void didUpdateWidget(ArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.image.toString() != widget.image.toString()) {
      _generation++;
      _task?.cancel();
      _task = null;
      _preparingKey = null;
    }
  }

  void _prepareInBackground(
    XeroxRasterRequest request,
    BuildContext context,
  ) {
    if (widget.xerox || _preparingKey == request.key) return;
    _preparingKey = request.key;
    final generation = ++_generation;
    unawaited(_prepare(request, context, generation));
  }

  Future<void> _prepare(
    XeroxRasterRequest request,
    BuildContext context,
    int generation,
  ) async {
    try {
      await precacheImage(
        ResizeImage(request.image, width: request.resolution),
        context,
        size: Size.square(request.resolution.toDouble()),
      );
      if (!mounted || generation != _generation) return;
      final task = XeroxRasterCache.instance.request(request);
      _task = task;
      final lease = await task.future;
      lease.release();
      if (identical(_task, task)) _task = null;
    } catch (_) {
      // Background preparation is opportunistic. A later visible Xerox
      // request retries through the same bounded raster cache.
      if (identical(_task, task)) _task = null;
      if (mounted && generation == _generation) _preparingKey = null;
    }
  }

  @override
  void dispose() {
    _generation++;
    _task?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.xerox) {
      return XeroxArtwork(
        identity: widget.identity,
        image: widget.image,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        semanticLabel: widget.semanticLabel,
        excludeFromSemantics: widget.excludeFromSemantics,
        scale: widget.scale,
        errorBuilder: widget.errorBuilder,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = widget.width ?? constraints.maxWidth;
        final height = widget.height ?? constraints.maxHeight;
        final extent = width.isFinite && height.isFinite
            ? (width > height ? width : height)
            : width.isFinite
            ? width
            : height.isFinite
            ? height
            : 0.0;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final resolution = xeroxResolution(extent * widget.scale * dpr);
        final request = XeroxRasterRequest(
          identity: widget.identity,
          image: widget.image,
          resolution: resolution,
          fit: widget.fit ?? BoxFit.cover,
          devicePixelRatio: dpr,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _prepareInBackground(request, context);
        });

        return Image(
          image: ResizeImage(widget.image, width: resolution),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          gaplessPlayback: true,
          semanticLabel: widget.excludeFromSemantics
              ? null
              : widget.semanticLabel,
          excludeFromSemantics: widget.excludeFromSemantics,
          errorBuilder: widget.errorBuilder,
        );
      },
    );
  }
}
