// 文件职责：应用级服务、平台适配与辅助能力。

import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// 封装或定义模拟专辑缓存相关类型与行为，负责应用级服务、平台适配与辅助能力。
class MockAlbumCache {
  MockAlbumCache({this.catalogAsset = 'assets/albums/catalog.json'});

  static const _warmupLimit = 16;
  final String catalogAsset;
  Future<List<Map<String, dynamic>>>? _catalog;
  Future<void>? _warming;
  int _generation = 0;

  /// 读取并恢复所需数据或资源，用于应用级服务、平台适配与辅助能力。
  Future<List<Map<String, dynamic>>> load() => _catalog ??= rootBundle
      .loadString(catalogAsset)
      .then(
        (value) => (jsonDecode(value) as List).cast<Map<String, dynamic>>(),
      );

  Future<void> warmImages(Future<void> Function(ImageProvider) precache) {
    return _warming ??= _warmImages(precache, _generation);
  }

  /// 准备并调度后续任务，用于应用级服务、平台适配与辅助能力。
  Future<void> _warmImages(
    Future<void> Function(ImageProvider) precache,
    int generation,
  ) async {
    final warmed = <String>{};
    // 其余封面由图片缓存系统在进入可视区域时按需加载。
    for (final album in (await load()).take(_warmupLimit)) {
      if (generation != _generation) return;
      final asset = album['asset'] as String;
      if (warmed.add(asset)) await precache(AssetImage(asset));
    }
  }

  /// 移除、清理或重置相关状态与资源，用于应用级服务、平台适配与辅助能力。
  Future<void> clear() async {
    _generation++;
    await _warming;
    _warming = null;
    for (final album in await load()) {
      await AssetImage(album['asset'] as String).evict();
    }
  }
}
