import 'dart:typed_data';
import 'dart:ui' as ui;

import 'xerox_disk_cache_stub.dart'
    if (dart.library.io) 'xerox_disk_cache_io.dart' as platform;

/// Platform-aware persistent cache for processed Xerox PNGs.
///
/// Native platforms use a dedicated CacheManager directory. Web falls back to
/// an in-memory store because flutter_cache_manager does not provide browser
/// disk persistence.
class XeroxDiskCache implements XeroxDiskCacheStore {
  XeroxDiskCache() : _store = platform.createXeroxDiskCacheStore();

  static final instance = XeroxDiskCache();

  final XeroxDiskCacheStore _store;

  @override
  Future<ui.Image?> read(String key) => _store.read(key);

  @override
  Future<void> write(String key, Uint8List bytes) =>
      _store.write(key, bytes);

  @override
  Future<void> remove(String key) => _store.remove(key);
}

abstract interface class XeroxDiskCacheStore {
  Future<ui.Image?> read(String key);
  Future<void> write(String key, Uint8List bytes);
  Future<void> remove(String key);
}
