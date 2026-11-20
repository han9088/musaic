// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../pipeline/artwork_decode_policy.dart';
import 'xerox_raster_cache.dart';
import 'xerox_raster_request.dart';
import 'xerox_resolution.dart';

export 'xerox_config.dart';
export 'xerox_resolution.dart';
export 'xerox_seed.dart';

/// 封装或定义Xerox专辑封面相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxArtwork extends StatefulWidget {
  const XeroxArtwork({
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
    this.scale = 1,
    this.errorBuilder,
    this.cache,
  });

  final String identity;
  final ImageProvider<Object> image;
  final String? sourceKey;
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

/// 封装或定义Xerox专辑封面状态相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class _XeroxArtworkState extends State<XeroxArtwork> {
  XeroxRasterCache get _cache => widget.cache ?? XeroxRasterCache.instance;
  XeroxRasterLease? _lease;
  XeroxRasterTask? _task;
  Timer? _requestTimer;
  XeroxRasterKey? _scheduledKey;
  int _generation = 0;
  int _requestedResolution = 0;
  int _requestedOriginalDecodeResolution = 0;
  XeroxRasterKey? _failedKey;
  Object? _error;

  @override
  void didUpdateWidget(XeroxArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.image.toString() != widget.image.toString() ||
        oldWidget.sourceKey != widget.sourceKey ||
        oldWidget.cache != widget.cache) {
      _generation++;
      _requestTimer?.cancel();
      _task?.cancel();
      _task = null;
      _scheduledKey = null;
      _lease?.release();
      _lease = null;
      _requestedResolution = 0;
      _requestedOriginalDecodeResolution = 0;
      _failedKey = null;
      _error = null;
    }
  }

  /// 准备并调度后续任务，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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
          // 所有调用方的有限次数重试都由缓存层统一管理，包括
          // 模式切换前的资源准备；重试仍失败时，继续显示中性
          // Xerox 占位内容，不回退显示原始彩色封面。
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
      final physicalExtent = extent * widget.scale * dpr;
      final resolution = xeroxResolution(
        physicalExtent,
        current: _requestedResolution == 0 ? null : _requestedResolution,
      );
      final originalDecodeResolution = artworkDecodeResolution(
        physicalExtent,
        current: _requestedOriginalDecodeResolution == 0
            ? null
            : _requestedOriginalDecodeResolution,
      );
      final request = XeroxRasterRequest(
        identity: widget.identity,
        image: widget.image,
        sourceKey: widget.sourceKey,
        resolution: resolution,
        originalDecodeResolution: originalDecodeResolution,
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
          currentLease!.resolution == resolution &&
          currentLease.key.originalDecodeResolution == originalDecodeResolution;
      if (!canKeepCurrent) {
        _requestedResolution = resolution;
        _requestedOriginalDecodeResolution = originalDecodeResolution;
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
        _requestedOriginalDecodeResolution = currentLease.key.originalDecodeResolution;
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
