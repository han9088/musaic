// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'xerox_disk_cache.dart';

/// 创建并组装所需对象或界面结构，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
XeroxDiskCacheStore createXeroxDiskCacheStore() => _IoXeroxDiskCacheStore();

/// 封装或定义ioXerox磁盘缓存存储相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class _IoXeroxDiskCacheStore implements XeroxDiskCacheStore {
  static final CacheManager _manager = CacheManager(
    Config(
      'musaic_xerox_rasters_v2',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 1200,
    ),
  );

  @override
  Future<ui.Image?> read(String key) async {
    final info = await _manager.getFileFromCache(key);
    if (info == null) return null;
    final bytes = await info.file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    await _manager.putFile(
      key,
      bytes,
      fileExtension: 'png',
      maxAge: const Duration(days: 365),
    );
  }

  @override
  Future<void> remove(String key) => _manager.removeFile(key);
}
