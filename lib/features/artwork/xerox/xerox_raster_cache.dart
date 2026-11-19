import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'xerox_raster_request.dart';
import 'xerox_rasterizer.dart';

class _RasterEntry {
  _RasterEntry(this.image)
    : bytes = image.width * image.height * 4;

  final ui.Image image;
  final int bytes;
  int references = 0;
}

class _PendingRaster {
  _PendingRaster(this.request);

  final XeroxRasterRequest request;
  final completer = Completer<_RasterEntry>();
  int waiters = 0;
}

/// A bounded, deduplicating LRU for GPU-backed Xerox bitmaps.
///
/// Entries held by a [XeroxRasterLease] are pinned and cannot be evicted.
class XeroxRasterCache {
  XeroxRasterCache({
    this.maxBytes = 96 * 1024 * 1024,
    this.maxConcurrentJobs = 2,
    XeroxRasterizer? rasterizer,
  }) : _rasterizer = rasterizer ?? XeroxRasterizer();

  static final instance = XeroxRasterCache();

  final int maxBytes;
  final int maxConcurrentJobs;
  final XeroxRasterizer _rasterizer;
  final LinkedHashMap<XeroxRasterKey, _RasterEntry> _entries =
      LinkedHashMap<XeroxRasterKey, _RasterEntry>();
  final Map<XeroxRasterKey, _PendingRaster> _pending = {};
  final Queue<_PendingRaster> _queue = Queue<_PendingRaster>();

  int _bytes = 0;
  int _activeJobs = 0;

  int get cachedBytes => _bytes;
  int get cachedEntries => _entries.length;
  int get activeJobs => _activeJobs;

  Future<XeroxRasterLease> acquireBest(XeroxRasterRequest request) {
    _RasterEntry? best;
    XeroxRasterKey? bestKey;
    var bestDistance = 1 << 30;
    for (final item in _entries.entries) {
      if (!item.key.sameArtwork(request.key)) continue;
      final distance = (item.key.resolution - request.resolution).abs();
      if (distance < bestDistance) {
        best = item.value;
        bestKey = item.key;
        bestDistance = distance;
      }
    }
    if (best != null && bestKey != null) {
      best.references++;
      _touch(bestKey, best);
      return Future.value(_lease(bestKey, best, bestKey.resolution));
    }
    return acquire(request);
  }

  Future<XeroxRasterLease> acquire(XeroxRasterRequest request) {
    final key = request.key;
    final hit = _entries.remove(key);
    if (hit != null) {
      hit.references++;
      _entries[key] = hit;
      return Future.value(_lease(key, hit, request.resolution));
    }

    var pending = _pending[key];
    if (pending == null) {
      pending = _PendingRaster(request)..waiters = 1;
      _pending[key] = pending;
      _queue.addLast(pending);
      _pump();
    } else {
      pending.waiters++;
    }
    return _awaitLease(key, pending, request.resolution);
  }

  Future<XeroxRasterLease> _awaitLease(
    XeroxRasterKey key,
    _PendingRaster pending,
    int resolution,
  ) async {
    try {
      final entry = await pending.completer.future;
      entry.references++;
      _touch(key, entry);
      return _lease(key, entry, resolution);
    } finally {
      pending.waiters--;
      if (pending.waiters == 0 && pending.completer.isCompleted) {
        _pending.remove(key);
      }
      _evict();
    }
  }

  XeroxRasterLease _lease(
    XeroxRasterKey key,
    _RasterEntry entry,
    int resolution,
  ) => XeroxRasterLease._(
    image: entry.image,
    resolution: resolution,
    key: key,
    release: () => _release(key, entry),
  );

  void _touch(XeroxRasterKey key, _RasterEntry entry) {
    _entries.remove(key);
    _entries[key] = entry;
  }

  void _release(XeroxRasterKey key, _RasterEntry entry) {
    if (entry.references > 0) entry.references--;
    _touch(key, entry);
    _evict();
  }

  /// Returns the best cached image for this artwork without taking ownership.
  /// A caller should acquire a lease immediately if it needs to keep the image.
  ui.Image? peekBest(XeroxRasterRequest request) {
    _RasterEntry? best;
    XeroxRasterKey? bestKey;
    var bestDistance = 1 << 30;
    for (final item in _entries.entries) {
      if (!item.key.sameArtwork(request.key)) continue;
      final distance = (item.key.resolution - request.resolution).abs();
      if (distance < bestDistance) {
        best = item.value;
        bestKey = item.key;
        bestDistance = distance;
      }
    }
    if (best == null || bestKey == null) return null;
    _touch(bestKey, best);
    return best.image;
  }

  void _pump() {
    while (_activeJobs < maxConcurrentJobs && _queue.isNotEmpty) {
      final pending = _queue.removeFirst();
      if (pending.waiters == 0) {
        _pending.remove(pending.request.key);
        continue;
      }
      _activeJobs++;
      unawaited(_rasterize(pending));
    }
  }

  Future<void> _rasterize(_PendingRaster pending) async {
    final key = pending.request.key;
    try {
      final image = await _rasterizer.rasterize(pending.request);
      final entry = _RasterEntry(image);
      _entries[key] = entry;
      _bytes += entry.bytes;
      pending.completer.complete(entry);
    } catch (error, stack) {
      pending.completer.completeError(error, stack);
    } finally {
      _activeJobs--;
      if (pending.waiters == 0) _pending.remove(key);
      _evict();
      _pump();
    }
  }

  void _evict() {
    while (_bytes > maxBytes) {
      XeroxRasterKey? victimKey;
      _RasterEntry? victim;
      for (final item in _entries.entries) {
        if (item.value.references == 0 && !_pending.containsKey(item.key)) {
          victimKey = item.key;
          victim = item.value;
          break;
        }
      }
      if (victimKey == null || victim == null) return;
      _entries.remove(victimKey);
      _bytes -= victim.bytes;
      victim.image.dispose();
    }
  }
}

class XeroxRasterLease {
  XeroxRasterLease._({
    required this.image,
    required this.resolution,
    required this.key,
    required void Function() release,
  }) : _release = release;

  final ui.Image image;
  final int resolution;
  final XeroxRasterKey key;
  final void Function() _release;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}
