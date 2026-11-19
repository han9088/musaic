import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'xerox_raster_cache.dart';
import 'xerox_raster_request.dart';
import 'xerox_resolution.dart';

export 'xerox_config.dart';
export 'xerox_resolution.dart';
export 'xerox_seed.dart';

class XeroxArtwork extends StatefulWidget {
  const XeroxArtwork({
    super.key,
    required this.identity,
    required this.image,
    this.width,
    this.height,
    this.fit,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.scale = 1,
    this.errorBuilder,
    this.cache,
  });

  final String identity;
  final ImageProvider<Object> image;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final FilterQuality filterQuality;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final double scale;
  final ImageErrorWidgetBuilder? errorBuilder;
  final XeroxRasterCache? cache;

  @override
  State<XeroxArtwork> createState() => _XeroxArtworkState();
}

class _XeroxArtworkState extends State<XeroxArtwork> {
  XeroxRasterCache get _cache => widget.cache ?? XeroxRasterCache.instance;
  XeroxRasterLease? _lease;
  XeroxRasterTask? _task;
  Timer? _requestTimer;
  XeroxRasterKey? _scheduledKey;
  int _generation = 0;
  int _requestedResolution = 0;
  XeroxRasterKey? _failedKey;
  Object? _error;

  @override
  void didUpdateWidget(XeroxArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.image.toString() != widget.image.toString() ||
        oldWidget.cache != widget.cache) {
      _generation++;
      _requestTimer?.cancel();
      _task?.cancel();
      _task = null;
      _scheduledKey = null;
      _lease?.release();
      _lease = null;
      _requestedResolution = 0;
      _failedKey = null;
      _error = null;
    }
  }

  void _scheduleAcquire(
    XeroxRasterRequest request, {
    required Duration delay,
  }) {
    if (_lease?.key == request.key ||
        _scheduledKey == request.key ||
        _failedKey == request.key) {
      return;
    }
    if (_failedKey != null && _failedKey != request.key) {
      _failedKey = null;
      _error = null;
    }
    _requestTimer?.cancel();
    _task?.cancel();
    _task = null;
    _scheduledKey = request.key;
    final generation = ++_generation;

    Future<void> acquire() async {
      if (!mounted || generation != _generation) return;
      _requestTimer = null;
      final task = _lease == null
          ? _cache.requestBest(request)
          : _cache.request(request);
      _task = task;
      try {
        final next = await task.future;
        if (!mounted || generation != _generation) {
          next.release();
          return;
        }
        final previous = _lease;
        setState(() {
          _lease = next;
          _error = null;
          _failedKey = null;
        });
        previous?.release();
      } catch (error) {
        if (!mounted || generation != _generation) return;
        if (error is! XeroxRasterCancelled) {
          // The cache owns bounded retries for every caller, including
          // mode-transition preparation. If they fail, stay on a neutral
          // Xerox fallback instead of revealing the original artwork.
          setState(() {
            _error = error;
            _failedKey = request.key;
          });
        }
      } finally {
        if (identical(_task, task)) _task = null;
        if (_scheduledKey == request.key) _scheduledKey = null;
      }
    }

    if (delay == Duration.zero) {
      unawaited(acquire());
    } else {
      _requestTimer = Timer(delay, () => unawaited(acquire()));
    }
  }

  @override
  void dispose() {
    _generation++;
    _requestTimer?.cancel();
    _task?.cancel();
    _lease?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = widget.width ?? constraints.maxWidth;
      final height = widget.height ?? constraints.maxHeight;
      final extent = math.max(
        width.isFinite ? width : 0,
        height.isFinite ? height : 0,
      );
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final resolution = xeroxResolution(
        extent * widget.scale * dpr,
        current: _requestedResolution == 0 ? null : _requestedResolution,
      );
      final request = XeroxRasterRequest(
        identity: widget.identity,
        image: widget.image,
        resolution: resolution,
        fit: widget.fit ?? BoxFit.scaleDown,
        devicePixelRatio: dpr,
      );

      var currentLease = _lease;
      if (currentLease == null) {
        currentLease = _cache.tryAcquireBest(request);
        if (currentLease != null) _lease = currentLease;
      }
      final sameArtwork = currentLease?.key.sameArtwork(request.key) ?? false;
      final canKeepCurrent = sameArtwork &&
          currentLease!.resolution == resolution;
      if (!canKeepCurrent) {
        _requestedResolution = resolution;
        _scheduleAcquire(
          request,
          delay: currentLease == null
              ? Duration.zero
              : const Duration(milliseconds: 120),
        );
      } else {
        if (_scheduledKey != null) {
          _requestTimer?.cancel();
          _task?.cancel();
          _task = null;
          _requestTimer = null;
          _generation++;
          _scheduledKey = null;
        }
        _requestedResolution = currentLease.resolution;
      }

      final image = sameArtwork ? currentLease!.image : null;
      if (image != null) {
        return Semantics(
          image: true,
          label: widget.excludeFromSemantics ? null : widget.semanticLabel,
          excludeSemantics: widget.excludeFromSemantics,
          child: RawImage(
            image: image,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            filterQuality: widget.filterQuality,
          ),
        );
      }

      if (_error != null && widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error!, StackTrace.current);
      }
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const ColoredBox(color: Color(0xff171715)),
      );
    },
  );
}
