import 'dart:typed_data';
import 'dart:ui' as ui;

import 'xerox_disk_cache.dart';

XeroxDiskCacheStore createXeroxDiskCacheStore() =>
    _MemoryXeroxDiskCacheStore();

class _MemoryXeroxDiskCacheStore implements XeroxDiskCacheStore {
  final _entries = <String, Uint8List>{};

  @override
  Future<ui.Image?> read(String key) async {
    final bytes = _entries[key];
    if (bytes == null) return null;
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    _entries[key] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> remove(String key) async {
    _entries.remove(key);
  }
}
