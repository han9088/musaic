// 文件职责：在原图成功显示后，低优先级地预生成对应的 Xerox 位图。

import 'dart:async';

import '../xerox/xerox_raster_cache.dart';
import '../xerox/xerox_raster_request.dart';

/// 负责提交普通浏览过程中的后台处理任务，不管理位图缓存或渲染资源。
class XeroxBackgroundProcessor {
  XeroxBackgroundProcessor({XeroxRasterCache? cache})
    : _cache = cache ?? XeroxRasterCache.instance;

  static final instance = XeroxBackgroundProcessor();

  final XeroxRasterCache _cache;
  final Set<XeroxRasterKey> _pending = {};

  int get pendingCount => _pending.length;

  /// 相同请求只入队一次；默认后台优先级不会挤占当前可视区域的准备任务。
  void enqueue(XeroxRasterRequest request) {
    if (_cache.refreshIfCached(request.key) || !_pending.add(request.key))
      return;
    final task = _cache.request(request);
    unawaited(_consume(task, request.key));
  }

  /// 无论任务成功或失败，都及时释放 Lease，避免后台任务长期固定图片。
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
