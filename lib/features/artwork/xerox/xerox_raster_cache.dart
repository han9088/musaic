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

class _RasterWaiter {
  final completer = Completer<XeroxRasterLease>();
  bool cancelled = false;
  bool completed = false;
}

class _PendingRaster {
  _PendingRaster(this.request);

  final XeroxRasterRequest request;
  final waiters = <_RasterWaiter>{};
  bool started = false;
}

/// A cancellable request for a shared raster job.
///
/// Cancelling one waiter does not affect other widgets requesting the same
/// artwork. A queued job is removed when its last waiter leaves.
class XeroxRasterTask {
  XeroxRasterTask._(this.future, this._cancel);

  factory XeroxRasterTask.completed(XeroxRasterLease lease) =>
      XeroxRasterTask._(Future.value(lease), () {});

  final Future<XeroxRasterLease> future;
  final void Function() _cancel;
  bool _cancelled = false;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancel();
  }
}

class XeroxRasterCancelled implements Exception {
  const XeroxRasterCancelled();

  @override
  String toString() => 'Xerox raster request was cancelled.';
}

/// A bounded, deduplicating LRU for GPU-backed Xerox bitmaps.
///
/// Images held by [XeroxRasterLease] are pinned and cannot be evicted.
class XeroxRasterCache {
  XeroxRasterCache({
    this.maxBytes = 96 * 1024 * 1024,
    this.maxConcurrentJobs = 2,
    XeroxRasterizer? rasterizer,
  }) : _rasterizer = rasterizer ?? XeroxRasterizer() {
    if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes');
    if (maxConcurrentJobs <= 0) {
      throw ArgumentError.value(maxConcurrentJobs, 'maxConcurrentJobs');
    }
  }

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
  int get queuedJobs => _queue.length;

  XeroxRasterTask requestBest(XeroxRasterRequest request) {
    final best = _findBest(request);
    if (best != null) {
      final (key, entry) = best;
      entry.references++;
      _touch(key, entry);
      return XeroxRasterTask.completed(
        _lease(key, entry, key.resolution),
      );
    }
    return this.request(request);
  }

  Future<XeroxRasterLease> acquireBest(XeroxRasterRequest request) =>
      requestBest(request).future;

  XeroxRasterTask request(XeroxRasterRequest request) {
    final key = request.key;
    final hit = _entries.remove(key);
    if (hit != null) {
      hit.references++;
      _entries[key] = hit;
      return XeroxRasterTask.completed(_lease(key, hit, request.resolution));
    }

    final pending = _pending.putIfAbsent(key, () {
      final created = _PendingRaster(request);
      _queue.addLast(created);
      return created;
    });
    final waiter = _RasterWaiter();
    pending.waiters.add(waiter);
    _pump();

    return XeroxRasterTask._(
      waiter.completer.future,
      () => _cancelWaiter(key, pending, waiter),
    );
  }

  Future<XeroxRasterLease> acquire(XeroxRasterRequest request) =>
      this.request(request).future;

  (XeroxRasterKey, _RasterEntry)? _findBest(
    XeroxRasterRequest request,
  ) {
    XeroxRasterKey? bestKey;
    _RasterEntry? bestEntry;
    var bestLowerResolution = 0;
    var bestHigherResolution = 1 << 30;

    for (final item in _entries.entries) {
      if (!item.key.sameArtwork(request.key)) continue;
      final resolution = item.key.resolution;
      if (resolution <= request.resolution &&
          resolution > bestLowerResolution) {
        bestKey = item.key;
        bestEntry = item.value;
        bestLowerResolution = resolution;
      } else if (bestLowerResolution == 0 &&
          resolution > request.resolution &&
          resolution < bestHigherResolution) {
        bestKey = item.key;
        bestEntry = item.value;
        bestHigherResolution = resolution;
      }
    }

    if (bestKey == null || bestEntry == null) return null;
    return (bestKey, bestEntry);
  }

  void _cancelWaiter(
    XeroxRasterKey key,
    _PendingRaster pending,
    _RasterWaiter waiter,
  ) {
    if (waiter.cancelled || waiter.completed) return;
    waiter.cancelled = true;
    pending.waiters.remove(waiter);
    waiter.completer.completeError(
      const XeroxRasterCancelled(),
      StackTrace.current,
    );

    if (!pending.started && pending.waiters.isEmpty) {
      _queue.remove(pending);
      _pending.remove(key);
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

  void _pump() {
    while (_activeJobs < maxConcurrentJobs && _queue.isNotEmpty) {
      final pending = _queue.removeFirst();
      if (pending.waiters.isEmpty) {
        _pending.remove(pending.request.key);
        continue;
      }
      pending.started = true;
      _activeJobs++;
      unawaited(_rasterize(pending));
    }
  }

  Future<void> _rasterize(_PendingRaster pending) async {
    final key = pending.request.key;
    try {
      final image = await _rasterizer.rasterize(pending.request);
      final activeWaiters = pending.waiters
          .where((waiter) => !waiter.cancelled)
          .toList(growable: false);

      if (activeWaiters.isEmpty) {
        image.dispose();
        return;
      }

      // Reserve all leases before completing any waiter. The cache may exceed
      // its budget while images are pinned, but cannot dispose a live texture.
      final entry = _RasterEntry(image)
        ..references = activeWaiters.length;
      _entries[key] = entry;
      _bytes += entry.bytes;

      for (final waiter in activeWaiters) {
        waiter.completed = true;
        waiter.completer.complete(
          _lease(key, entry, pending.request.resolution),
        );
      }
      pending.waiters.clear();
    } catch (error, stack) {
      for (final waiter in pending.waiters.toList()) {
        if (waiter.cancelled) continue;
        waiter.completed = true;
        waiter.completer.completeError(error, stack);
      }
      pending.waiters.clear();
    } finally {
      _pending.remove(key);
      _activeJobs--;
      _evict();
      _pump();
    }
  }

  void _evict() {
    while (_bytes > maxBytes) {
      XeroxRasterKey? victimKey;
      _RasterEntry? victim;
      for (final item in _entries.entries) {
        if (item.value.references == 0) {
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
