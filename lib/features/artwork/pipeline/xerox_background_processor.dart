// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:async';

import '../xerox/xerox_raster_cache.dart';
import '../xerox/xerox_raster_request.dart';

/// 封装或定义Xerox后台处理器相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxBackgroundProcessor {
  XeroxBackgroundProcessor({XeroxRasterCache? cache})
    : _cache = cache ?? XeroxRasterCache.instance;

  static final instance = XeroxBackgroundProcessor();

  final XeroxRasterCache _cache;
  final Set<XeroxRasterKey> _pending = {};

  /// 执行当前模块中的pendingcount操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  int get pendingCount => _pending.length;

  /// 准备并调度后续任务，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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
      // 后台预处理失败不能影响原图的正常显示。
    } finally {
      _pending.remove(key);
    }
  }
}
