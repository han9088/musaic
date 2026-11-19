import 'dart:async';

import '../xerox/xerox_raster_cache.dart';
import '../xerox/xerox_raster_request.dart';

/// Opportunistically prepares Xerox rasters after an original image is shown.
class XeroxBackgroundProcessor {
  XeroxBackgroundProcessor({XeroxRasterCache? cache})
    : _cache = cache ?? XeroxRasterCache.instance;

  static final instance = XeroxBackgroundProcessor();

  final XeroxRasterCache _cache;
  final Set<XeroxRasterKey> _pending = {};

  int get pendingCount => _pending.length;

  void enqueue(XeroxRasterRequest request) {
    if (!_pending.add(request.key)) return;
    final task = _cache.request(request);
    unawaited(_consume(task, request.key));
  }

  Future<void> _consume(XeroxRasterTask task, XeroxRasterKey key) async {
    try {
      final lease = await task.future;
      lease.release();
    } catch (_) {
      // Background work must never break original-image rendering.
    } finally {
      _pending.remove(key);
    }
  }
}
