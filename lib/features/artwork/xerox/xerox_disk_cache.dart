// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'xerox_disk_cache_stub.dart'
    if (dart.library.io) 'xerox_disk_cache_io.dart'
    as platform;

/// 封装或定义Xerox磁盘缓存相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxDiskCache implements XeroxDiskCacheStore {
  XeroxDiskCache() : _store = platform.createXeroxDiskCacheStore();

  static final instance = XeroxDiskCache();

  final XeroxDiskCacheStore _store;

  @override
  Future<ui.Image?> read(String key) => _store.read(key);

  @override
  Future<void> write(String key, Uint8List bytes) => _store.write(key, bytes);

  @override
  Future<void> remove(String key) => _store.remove(key);
}

/// 封装或定义Xerox磁盘缓存存储相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
abstract interface class XeroxDiskCacheStore {
  /// 读取并恢复所需数据或资源，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<ui.Image?> read(String key);

  /// 保存数据或持久化当前状态，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<void> write(String key, Uint8List bytes);

  /// 移除、清理或重置相关状态与资源，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<void> remove(String key);
}
