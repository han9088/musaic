// 文件职责：在 Pipeline 内申请、持有并释放 Xerox 光栅资源。

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'artwork_pipeline.dart';
import '../xerox/xerox_raster_cache.dart';
import '../xerox/xerox_raster_request.dart';

typedef XeroxRasterResourceBuilder =
    Widget Function(ui.Image? image, Object? error);

/// Pipeline 的 Xerox 资源适配器。
///
/// 它管理 Raster Lease 和请求取消；实际绘制交给上层纯 Renderer。
class XeroxRasterResource extends StatefulWidget {
  const XeroxRasterResource({
    super.key,
    required this.request,
    required this.builder,
    this.pipeline,
  });

  final XeroxRasterRequest request;
  final XeroxRasterResourceBuilder builder;
  final ArtworkPipeline? pipeline;

  @override
  State<XeroxRasterResource> createState() => _XeroxRasterResourceState();
}

class _XeroxRasterResourceState extends State<XeroxRasterResource> {
  ArtworkPipeline get _pipeline => widget.pipeline ?? ArtworkPipeline.instance;

  XeroxRasterLease? _lease;
  XeroxRasterTask? _task;
  Timer? _requestTimer;
  XeroxRasterKey? _scheduledKey;
  XeroxRasterKey? _failedKey;
  Object? _error;
  int _generation = 0;

  @override
  void didUpdateWidget(XeroxRasterResource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.key != widget.request.key ||
        oldWidget.pipeline != widget.pipeline) {
      _generation++;
      _requestTimer?.cancel();
      _task?.cancel();
      _task = null;
      _scheduledKey = null;
      _lease?.release();
      _lease = null;
      _failedKey = null;
      _error = null;
    }
  }

  void _scheduleAcquire(
    XeroxRasterRequest request, {
    required bool sameArtwork,
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
      final hasSameArtwork = _lease?.key.sameArtwork(request.key) ?? false;
      final task = _pipeline.requestXerox(
        request,
        exactOnly: hasSameArtwork,
      );
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

    if (!sameArtwork) {
      unawaited(acquire());
    } else {
      _requestTimer = Timer(
        const Duration(milliseconds: 120),
        () => unawaited(acquire()),
      );
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
  Widget build(BuildContext context) {
    final request = widget.request;
    var currentLease = _lease;
    if (currentLease == null) {
      currentLease = _pipeline.tryAcquireXerox(request);
      if (currentLease != null) _lease = currentLease;
    }

    final sameArtwork = currentLease?.key.sameArtwork(request.key) ?? false;
    final exactRequest = currentLease?.key == request.key;
    if (!exactRequest) {
      _scheduleAcquire(request, sameArtwork: sameArtwork);
    } else if (_scheduledKey != null) {
      _requestTimer?.cancel();
      _task?.cancel();
      _task = null;
      _requestTimer = null;
      _generation++;
      _scheduledKey = null;
    }

    return widget.builder(
      sameArtwork ? currentLease!.image : null,
      _error,
    );
  }
}
