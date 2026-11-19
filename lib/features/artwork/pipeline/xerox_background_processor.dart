import 'dart:async';

import '../xerox/xerox_raster_cache.dart';
import '../xerox/xerox_raster_request.dart';

/// Opportunistically prepares Xerox rasters after an original image is shown.
/// Deduplicates opportunistic Xerox work triggered by successfully shown originals.
/// It deliberately does not own rendering state; the raster cache owns the jobs.
class XeroxBackgroundProcessor {
  XeroxBackgroundProcessor({XeroxRasterCache? cache})
    : _cache = cache ?? XeroxRasterCache.instance;

  static final instance = XeroxBackgroundProcessor();

  final XeroxRasterCache _cache;
  final Set<XeroxRasterKey> _pending = {};

  int get pendingCount => _pending.length;

  /// Enqueues one background raster unless the same key is already pending.
  void enqueue(XeroxRasterRequest request) {
    if (!_pending.add(request.key)) return;
    final task = _cache.request(request);
    unawaited(_consume(task, request.key));
  }

  /// Releases the cache lease regardless of success so background work never pins images.
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
