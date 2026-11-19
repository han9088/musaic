import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'xerox_disk_cache.dart';
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
  _PendingRaster(this.request, this.priority, this.sequence);

  final XeroxRasterRequest request;
  final waiters = <_RasterWaiter>{};
  int priority;
  final int sequence;
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

  factory XeroxRasterTask.failed(Object error) =>
      XeroxRasterTask._(Future.error(error, StackTrace.current), () {});

  final Future<XeroxRasterLease> future;
  final void Function() _cancel;
  bool _cancelled = false;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancel();
  }
}

class XeroxRasterQueueFull implements Exception {
  const XeroxRasterQueueFull();

  @override
  String toString() => 'Xerox raster queue is full.';
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
    this.maxQueuedJobs = 128,
    XeroxRasterizer? rasterizer,
    XeroxRasterDiskStore? diskStore,
  }) : _rasterizer = rasterizer ?? XeroxRasterizer(),
       _diskStore = diskStore ?? XeroxDiskCache.instance {
    if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes');
    if (maxConcurrentJobs <= 0) {
      throw ArgumentError.value(maxConcurrentJobs, 'maxConcurrentJobs');
    }
    if (maxQueuedJobs <= 0) {
      throw ArgumentError.value(maxQueuedJobs, 'maxQueuedJobs');
    }
  }

  static final instance = XeroxRasterCache();

  final int maxBytes;
  final int maxConcurrentJobs;
  final int maxQueuedJobs;
  final XeroxRasterizer _rasterizer;
  final XeroxRasterDiskStore _diskStore;
  final LinkedHashMap<XeroxRasterKey, _RasterEntry> _entries =
      LinkedHashMap<XeroxRasterKey, _RasterEntry>();
  final Map<XeroxRasterKey, _PendingRaster> _pending = {};
  final List<_PendingRaster> _queue = [];

  int _bytes = 0;
  int _activeJobs = 0;
  int _nextSequence = 0;

  int get cachedBytes => _bytes;
  int get cachedEntries => _entries.length;
  int get activeJobs => _activeJobs;
  int get queuedJobs => _queue.length;

  /// Synchronously pins the best cached raster, if one is already available.
  XeroxRasterLease? tryAcquireBest(XeroxRasterRequest request) {
    final best = _findBest(request);
    if (best == null) return null;
    final (key, entry) = best;
    entry.references++;
    _touch(key, entry);
    return _lease(key, entry, key.resolution);
  }

  XeroxRasterTask requestBest(
    XeroxRasterRequest request, {
    int priority = 100,
  }) {
    final lease = tryAcquireBest(request);
    return lease == null
        ? this.request(request, priority: priority)
        : XeroxRasterTask.completed(lease);
  }

  Future<XeroxRasterLease> acquireBest(XeroxRasterRequest request) =>
      requestBest(request).future;

  XeroxRasterTask request(
    XeroxRasterRequest request, {
    int priority = 0,
  }) {
    final key = request.key;
    final hit = _entries.remove(key);
    if (hit != null) {
      hit.references++;
      _entries[key] = hit;
      return XeroxRasterTask.completed(_lease(key, hit, request.resolution));
    }

    var pending = _pending[key];
    if (pending == null) {
      if (_queue.length >= maxQueuedJobs) {
        final lowest = _queue.last;
        if (priority <= lowest.priority) {
          return XeroxRasterTask.failed(const XeroxRasterQueueFull());
        }
        _discardQueued(lowest, const XeroxRasterQueueFull());
      }
      pending = _PendingRaster(request, priority, _nextSequence++);
      _pending[key] = pending;
      _queue.add(pending);
      _sortQueue();
    } else if (!pending.started && priority > pending.priority) {
      pending.priority = priority;
      _sortQueue();
    }
    final waiter = _RasterWaiter();
    pending.waiters.add(waiter);
    _pump();

    return XeroxRasterTask._(
      waiter.completer.future,
      () => _cancelWaiter(key, pending, waiter),
    );
  }

  Future<XeroxRasterLease> acquire(
    XeroxRasterRequest request, {
    int priority = 0,
  }) => this.request(request, priority: priority).future;

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

  void _sortQueue() {
    _queue.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      return byPriority != 0 ? byPriority : a.sequence.compareTo(b.sequence);
    });
  }

  void _discardQueued(_PendingRaster pending, Object reason) {
    _queue.remove(pending);
    _pending.remove(pending.request.key);
    for (final waiter in pending.waiters) {
      if (waiter.cancelled || waiter.completed) continue;
      waiter.completed = true;
      waiter.completer.completeError(reason, StackTrace.current);
    }
    pending.waiters.clear();
  }

  void _pump() {
    while (_activeJobs < maxConcurrentJobs && _queue.isNotEmpty) {
      final pending = _queue.removeAt(0);
      if (pending.waiters.isEmpty) {
        _pending.remove(pending.request.key);
        continue;
      }
      pending.started = true;
      _activeJobs++;
      unawaited(_rasterize(pending));
    }
  }

  Future<(XeroxRasterKey, ui.Image)> _rasterizeWithRetry(
    XeroxRasterRequest request,
  ) async {
    try {
      final cached = await _diskStore.readBest(request.key);
      if (cached != null) return cached;
    } catch (_) {
      // A disk-cache failure is treated as a miss; the original remains valid.
    }

    Object? lastError;
    StackTrace? lastStack;
    // One retry covers transient decode/GPU failures without allowing an
    // unavailable source to keep the mode switch spinning indefinitely.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final image = await _rasterizer.rasterize(request);
        unawaited(
          _diskStore.write(request.key, image).catchError((Object _) {}),
        );
        return (request.key, image);
      } catch (error, stack) {
        lastError = error;
        lastStack = stack;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }

  Future<void> _rasterize(_PendingRaster pending) async {
    final key = pending.request.key;
    try {
      final (resolvedKey, image) = await _rasterizeWithRetry(pending.request);
      final activeWaiters = pending.waiters
          .where((waiter) => !waiter.cancelled)
          .toList(growable: false);

      if (activeWaiters.isEmpty) {
        image.dispose();
        return;
      }

      // Reserve all leases before completing any waiter. The cache may exceed
      // its budget while images are pinned, but cannot dispose a live texture.
      var entry = _entries[resolvedKey];
      if (entry != null) {
        // Another LOD request may have decoded the same persistent raster
        // concurrently. Reuse the existing texture instead of storing a
        // duplicate entry under the same key.
        image.dispose();
        entry.references += activeWaiters.length;
        _touch(resolvedKey, entry);
      } else {
        entry = _RasterEntry(image)
          ..references = activeWaiters.length;
        _entries[resolvedKey] = entry;
        _bytes += entry.bytes;
      }

      for (final waiter in activeWaiters) {
        waiter.completed = true;
        waiter.completer.complete(
          _lease(resolvedKey, entry, resolvedKey.resolution),
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
