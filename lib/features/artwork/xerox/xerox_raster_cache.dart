// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import '../cache/artwork_memory_policy.dart';
import 'xerox_disk_cache.dart';
import 'xerox_raster_request.dart';
import 'xerox_rasterizer.dart';

/// 封装或定义光栅entry相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class _RasterEntry {
  _RasterEntry(this.image) : bytes = image.width * image.height * 4;

  final ui.Image image;
  final int bytes;
  int references = 0;
}

/// 封装或定义光栅waiter相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class _RasterWaiter {
  final completer = Completer<XeroxRasterLease>();
  bool cancelled = false;
  bool completed = false;
}

/// 封装或定义pending光栅相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class _PendingRaster {
  _PendingRaster(this.request, this.sequence) : priority = request.priority;

  final XeroxRasterRequest request;
  final int sequence;
  final waiters = <_RasterWaiter>{};
  XeroxRasterPriority priority;
  bool started = false;
}

/// 封装或定义Xerox光栅task相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxRasterTask {
  XeroxRasterTask._(this.future, this._cancel);

  factory XeroxRasterTask.completed(XeroxRasterLease lease) =>
      XeroxRasterTask._(Future.value(lease), () {});

  factory XeroxRasterTask.failed(Object error) =>
      XeroxRasterTask._(Future<XeroxRasterLease>.error(error), () {});

  final Future<XeroxRasterLease> future;
  final void Function() _cancel;
  bool _cancelled = false;

  /// 判断当前状态是否满足指定条件，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancel();
  }
}

/// 封装或定义Xerox光栅cancelled相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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

/// 封装或定义Xerox光栅缓存相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxRasterCache {
  XeroxRasterCache({
    int? maxBytes,
    this.maxConcurrentJobs = 2,
    this.maxQueuedJobs = 256,
    XeroxRasterizer? rasterizer,
    XeroxDiskCacheStore? diskCache,
  }) : maxBytes = maxBytes ?? ArtworkMemoryPolicy.defaultXeroxRasterBytes,
       _rasterizer = rasterizer ?? XeroxRasterizer(),
       _diskCache = diskCache ?? XeroxDiskCache.instance {
    if (this.maxBytes <= 0) {
      throw ArgumentError.value(this.maxBytes, 'maxBytes');
    }
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
  final XeroxDiskCacheStore _diskCache;
  final LinkedHashMap<XeroxRasterKey, _RasterEntry> _entries =
      LinkedHashMap<XeroxRasterKey, _RasterEntry>();
  final Map<XeroxRasterKey, _PendingRaster> _pending = {};
  final List<_PendingRaster> _queue = [];
  final Set<XeroxRasterKey> _diskWriteQueue = {};
  bool _writingToDisk = false;
  int _nextSequence = 0;

  int _bytes = 0;
  int _activeJobs = 0;

  /// 管理缓存写入、命中或失效过程，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  int get cachedBytes => _bytes;

  /// 管理缓存写入、命中或失效过程，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  int get cachedEntries => _entries.length;

  /// 执行当前模块中的activejobs操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  int get activeJobs => _activeJobs;

  /// 执行当前模块中的queuedjobs操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  int get queuedJobs => _queue.length;

  /// 执行当前模块中的tryacquirebest操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  XeroxRasterLease? tryAcquireBest(
    XeroxRasterRequest request, {
    bool allowDifferentDecodeResolution = false,
  }) {
    final best =
        _findBest(request) ??
        (allowDifferentDecodeResolution
            ? _findBest(request, requireSameDecodeResolution: false)
            : null);
    if (best == null) return null;
    final (key, entry) = best;
    entry.references++;
    _touch(key, entry);
    return _lease(key, entry, key.resolution);
  }

  /// 执行当前模块中的requestbest操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  XeroxRasterTask requestBest(XeroxRasterRequest request) {
    final lease = tryAcquireBest(request);
    return lease == null
        ? this.request(request)
        : XeroxRasterTask.completed(lease);
  }

  /// 管理资源的获取、持有与释放，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<XeroxRasterLease> acquireBest(XeroxRasterRequest request) =>
      requestBest(request).future;

  /// 执行当前模块中的request操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  XeroxRasterTask request(XeroxRasterRequest request) {
    final key = request.key;
    final hit = _entries.remove(key);
    if (hit != null) {
      hit.references++;
      _entries[key] = hit;
      return XeroxRasterTask.completed(_lease(key, hit, request.resolution));
    }

    final existing = _pending[key];
    late final _PendingRaster pending;
    if (existing == null) {
      if (_queue.length >= maxQueuedJobs) {
        final lowest = _queue.last;
        if (request.priority.index <= lowest.priority.index) {
          return XeroxRasterTask.failed(const XeroxRasterQueueFull());
        }
        _discardQueued(lowest);
      }
      pending = _PendingRaster(request, _nextSequence++);
      _pending[key] = pending;
      _queue.add(pending);
      _sortQueue();
    } else {
      pending = existing;
      if (!pending.started && request.priority.index > pending.priority.index) {
        // 相同 Raster 请求合并时允许升级排队优先级，但不改变缓存身份。
        pending.priority = request.priority;
        _sortQueue();
      }
    }
    final waiter = _RasterWaiter();
    pending.waiters.add(waiter);
    _pump();

    return XeroxRasterTask._(
      waiter.completer.future,
      () => _cancelWaiter(key, pending, waiter),
    );
  }

  /// 管理资源的获取、持有与释放，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<XeroxRasterLease> acquire(XeroxRasterRequest request) =>
      this.request(request).future;

  (XeroxRasterKey, _RasterEntry)? _findBest(
    XeroxRasterRequest request, {
    bool requireSameDecodeResolution = true,
  }) {
    XeroxRasterKey? bestKey;
    _RasterEntry? bestEntry;
    var bestLowerResolution = 0;
    var bestHigherResolution = 1 << 30;

    for (final item in _entries.entries) {
      if (!item.key.sameArtwork(request.key) ||
          (requireSameDecodeResolution &&
              item.key.originalDecodeResolution !=
                  request.originalDecodeResolution)) {
        continue;
      }
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

  /// 判断当前状态是否满足指定条件，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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

  /// 执行当前模块中的touch操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void _touch(XeroxRasterKey key, _RasterEntry entry) {
    _entries.remove(key);
    _entries[key] = entry;
  }

  /// 管理资源的获取、持有与释放，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void _release(XeroxRasterKey key, _RasterEntry entry) {
    if (entry.references > 0) entry.references--;
    _touch(key, entry);
    _evict();
  }

  /// 队列满时淘汰低优先级且尚未开始的任务，并通知所有等待者。
  void _discardQueued(_PendingRaster pending) {
    _queue.remove(pending);
    _pending.remove(pending.request.key);
    for (final waiter in pending.waiters.toList()) {
      if (waiter.cancelled || waiter.completed) continue;
      waiter.cancelled = true;
      waiter.completed = true;
      waiter.completer.completeError(
        const XeroxRasterCancelled(),
        StackTrace.current,
      );
    }
    pending.waiters.clear();
  }

  /// 按优先级从高到低调度；相同优先级仍按进入队列的先后顺序执行。
  void _sortQueue() {
    _queue.sort((a, b) {
      final priorityOrder = b.priority.index.compareTo(a.priority.index);
      return priorityOrder != 0
          ? priorityOrder
          : a.sequence.compareTo(b.sequence);
    });
  }

  /// 启动队列中的高优先级任务，并维持 GPU Raster 并发上限。
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

  /// 读取并恢复所需数据或资源，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<(ui.Image, bool)> _loadOrRasterize(XeroxRasterRequest request) async {
    final key = request.key.diskCacheKey;
    try {
      final cached = await _diskCache.read(key);
      if (cached != null) {
        if (cached.width == request.resolution &&
            cached.height == request.resolution) {
          return (cached, false);
        }
        cached.dispose();
        await _diskCache.remove(key);
      }
    } catch (_) {
      // 磁盘缓存损坏或版本过期时按未命中处理，不将其视为致命错误。
      try {
        await _diskCache.remove(key);
      } catch (_) {
        // 清理旧缓存失败也不能阻止从原图重新生成。
      }
    }

    return (await _rasterizeWithRetry(request), true);
  }

  void _queueDiskWrite(XeroxRasterKey key) {
    if (!_diskWriteQueue.add(key)) return;
    if (_diskWriteQueue.length > maxQueuedJobs) {
      _diskWriteQueue.remove(_diskWriteQueue.first);
    }
    if (!_writingToDisk) unawaited(_writeToDisk());
  }

  Future<void> _writeToDisk() async {
    _writingToDisk = true;
    try {
      while (_diskWriteQueue.isNotEmpty) {
        final key = _diskWriteQueue.first;
        _diskWriteQueue.remove(key);
        // 排队只保留 Key，避免写盘积压额外固定大量图片。
        final image = _entries[key]?.image.clone();
        if (image == null) continue;
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data != null) {
            await _diskCache.write(
              key.diskCacheKey,
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            );
          }
        } catch (_) {
          // 持久化失败不影响已经交付的内存位图。
        } finally {
          image.dispose();
        }
      }
    } finally {
      _writingToDisk = false;
    }
  }

  /// 执行当前模块中的rasterizewithretry操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<ui.Image> _rasterizeWithRetry(XeroxRasterRequest request) async {
    Object? lastError;
    StackTrace? lastStack;
    // 仅重试一次以覆盖短暂的解码或 GPU 故障，同时避免
    // 因图片源不可用而让模式切换无限等待。
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _rasterizer.rasterize(request);
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

  /// 执行当前模块中的rasterize操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<void> _rasterize(_PendingRaster pending) async {
    final key = pending.request.key;
    try {
      final (image, needsWrite) = await _loadOrRasterize(pending.request);
      final activeWaiters = pending.waiters
          .where((waiter) => !waiter.cancelled)
          .toList(growable: false);

      if (activeWaiters.isEmpty) {
        image.dispose();
        return;
      }

      // 在完成任何等待者之前先统一预留资源租约。缓存占用可能暂时超过
      // 预算，但仍被租约固定的图片不能被释放。
      final entry = _RasterEntry(image)..references = activeWaiters.length;
      _entries[key] = entry;
      _bytes += entry.bytes;

      for (final waiter in activeWaiters) {
        waiter.completed = true;
        waiter.completer.complete(
          _lease(key, entry, pending.request.resolution),
        );
      }
      pending.waiters.clear();
      if (needsWrite) _queueDiskWrite(key);
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

  /// 管理缓存写入、命中或失效过程，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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

/// 封装或定义Xerox光栅lease相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxRasterLease {
  XeroxRasterLease._({
    required this.image,
    required this.resolution,
    required this.key,
    required this._release,
  });

  final ui.Image image;
  final int resolution;
  final XeroxRasterKey key;
  final void Function() _release;
  bool _released = false;

  /// 管理资源的获取、持有与释放，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}
