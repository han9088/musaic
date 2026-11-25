// 文件职责：在 Pipeline 内申请、持有并释放 Xerox 光栅资源。

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'artwork_pipeline.dart';
import '../xerox/xerox_raster_cache.dart';
import '../xerox/xerox_raster_request.dart';

typedef XeroxRasterResourceBuilder = Widget Function(
  ui.Image? image,
  Object? error,
);

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
  XeroxRasterTask? _priorityTask;
  Timer? _requestTimer;
  XeroxRasterKey? _scheduledKey;
  XeroxRasterKey? _failedKey;
  Object? _error;
  int _generation = 0;
  int _queueRetryDelayMs = 120;

  @override
  void didUpdateWidget(XeroxRasterResource oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pipelineChanged = oldWidget.pipeline != widget.pipeline;
    final requestChanged = oldWidget.request.key != widget.request.key;
    final sameArtwork = oldWidget.request.key.sameArtwork(widget.request.key);

    if (pipelineChanged || (requestChanged && !sameArtwork)) {
      _resetRequest(releaseLease: true);
    } else if (requestChanged) {
      // LOD 档位变化时保留同一封面的旧 Raster，直到新档位准备好。
      _resetRequest(releaseLease: false);
    }

    if (!requestChanged &&
        !pipelineChanged &&
        oldWidget.request.priority.index < widget.request.priority.index) {
      _upgradePriority(widget.request);
    }
  }

  void _resetRequest({required bool releaseLease}) {
    _generation++;
    _requestTimer?.cancel();
    _requestTimer = null;
    _task?.cancel();
    _priorityTask?.cancel();
    _task = null;
    _priorityTask = null;
    _scheduledKey = null;
    _failedKey = null;
    _error = null;
    _queueRetryDelayMs = 120;
    if (releaseLease) {
      _lease?.release();
      _lease = null;
    }
  }

  void _upgradePriority(XeroxRasterRequest request) {
    final task = _pipeline.requestXerox(request, exactOnly: true);
    _priorityTask = task;
    unawaited(_releasePriorityLease(task));
  }

  Future<void> _releasePriorityLease(XeroxRasterTask task) async {
    try {
      final lease = await task.future;
      lease.release();
    } catch (_) {
      // 优先级提升只影响排队顺序，不应影响当前图片显示。
    } finally {
      if (identical(_priorityTask, task)) _priorityTask = null;
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
      final task = _pipeline.requestXerox(request, exactOnly: hasSameArtwork);
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
          _queueRetryDelayMs = 120;
        });
        if (previous != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            previous.release();
          });
        }
      } catch (error) {
        if (!mounted || generation != _generation) return;
        if (error is XeroxRasterQueueFull || error is XeroxRasterCancelled) {
          // 保留 scheduledKey，重建不能绕过拥塞退避。
          _requestTimer = Timer(Duration(milliseconds: _queueRetryDelayMs), () {
            if (!mounted || generation != _generation) return;
            setState(() {
              _requestTimer = null;
              _scheduledKey = null;
            });
          });
          if (_queueRetryDelayMs < 960) _queueRetryDelayMs *= 2;
        } else {
          setState(() {
            _error = error;
            _failedKey = request.key;
          });
        }
      } finally {
        if (identical(_task, task)) _task = null;
        if (generation == _generation &&
            _scheduledKey == request.key &&
            _requestTimer == null) {
          _scheduledKey = null;
        }
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
    _priorityTask?.cancel();
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

    return widget.builder(sameArtwork ? currentLease!.image : null, _error);
  }
}
