import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Persistent, versioned PNG cache for processed Xerox artwork.
class XeroxDiskCache implements XeroxDiskCacheStore {
  XeroxDiskCache({CacheManager? manager})
    : _manager = manager ?? _defaultManager;

  static final CacheManager _defaultManager = CacheManager(
    Config(
      'musaic_xerox_rasters_v1',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 1200,
    ),
  );

  static final instance = XeroxDiskCache();

  final CacheManager _manager;

  Future<ui.Image?> read(String key) async {
    final info = await _manager.getFileFromCache(key);
    if (info == null) return null;
    final bytes = await info.file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> write(String key, Uint8List bytes) async {
    await _manager.putFile(
      key,
      bytes,
      fileExtension: 'png',
      maxAge: const Duration(days: 365),
    );
  }

  Future<void> remove(String key) => _manager.removeFile(key);
}

/// Test seam for deterministic, in-memory raster-cache tests.
abstract interface class XeroxDiskCacheStore {
  Future<ui.Image?> read(String key);
  Future<void> write(String key, Uint8List bytes);
  Future<void> remove(String key);
}
