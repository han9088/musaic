// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'xerox_disk_cache.dart';

/// 创建并组装所需对象或界面结构，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
XeroxDiskCacheStore createXeroxDiskCacheStore() =>
    _MemoryXeroxDiskCacheStore();

/// 封装或定义memoryXerox磁盘缓存存储相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class _MemoryXeroxDiskCacheStore implements XeroxDiskCacheStore {
  static const _maxBytes = 32 * 1024 * 1024;

  final _entries = LinkedHashMap<String, Uint8List>();
  int _bytes = 0;

  @override
  Future<ui.Image?> read(String key) async {
    final bytes = _entries.remove(key);
    if (bytes == null) return null;
    _entries[key] = bytes;
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final previous = _entries.remove(key);
    if (previous != null) _bytes -= previous.lengthInBytes;
    final copy = Uint8List.fromList(bytes);
    _entries[key] = copy;
    _bytes += copy.lengthInBytes;
    while (_bytes > _maxBytes && _entries.isNotEmpty) {
      final oldest = _entries.keys.first;
      _bytes -= _entries.remove(oldest)!.lengthInBytes;
    }
  }

  @override
  Future<void> remove(String key) async {
    final removed = _entries.remove(key);
    if (removed != null) _bytes -= removed.lengthInBytes;
  }
}
