import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'xerox_raster_request.dart';
import 'xerox_resolution.dart';

abstract interface class XeroxRasterDiskStore {
  Future<ui.Image?> read(XeroxRasterKey key);

  Future<(XeroxRasterKey, ui.Image)?> readBest(XeroxRasterKey key);

  Future<void> write(XeroxRasterKey key, ui.Image image);
}

/// Persistent PNG storage for processed artwork.
///
/// The file cache is deliberately separate from the original network artwork
/// cache. Its object-count and expiry policy are independent. Web currently
/// relies on the in-memory raster cache and browser image caching.
class XeroxDiskCache implements XeroxRasterDiskStore {
  XeroxDiskCache({CacheManager? manager})
    : _manager = manager ?? _createManager();

  static const cacheKey = 'musaic_xerox_rasters_v1';
  static const maxCachedObjects = 800;
  static const cacheLifetime = Duration(days: 90);

  static final instance = XeroxDiskCache();

  final CacheManager _manager;

  static CacheManager _createManager() => CacheManager(
    Config(
      cacheKey,
      stalePeriod: cacheLifetime,
      maxNrOfCacheObjects: maxCachedObjects,
    ),
  );

  @override
  Future<ui.Image?> read(XeroxRasterKey key) async {
    if (kIsWeb) return null;

    try {
      final cached = await _manager.getFileFromCache(key.cacheKey);
      if (cached == null) return null;

      final bytes = await cached.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        return frame.image;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // A truncated or stale raster is a cache miss, not a mode failure.
      await _removeQuietly(key.cacheKey);
      return null;
    }
  }

  @override
  Future<(XeroxRasterKey, ui.Image)?> readBest(XeroxRasterKey key) async {
    final candidates = [...xeroxResolutions]..sort((a, b) {
      final aLower = a <= key.resolution;
      final bLower = b <= key.resolution;
      if (aLower != bLower) return aLower ? -1 : 1;
      return aLower ? b.compareTo(a) : a.compareTo(b);
    });

    for (final resolution in candidates) {
      final candidateKey = key.withResolution(resolution);
      final image = await read(candidateKey);
      if (image != null) return (candidateKey, image);
    }
    return null;
  }

  @override
  Future<void> write(XeroxRasterKey key, ui.Image image) async {
    if (kIsWeb) return;

    // Clone before the first await. The memory LRU may evict its own handle
    // while PNG encoding is still in progress.
    final retained = image.clone();
    try {
      final data = await retained.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await _manager.putFile(
        'https://musaic.invalid/xerox/${key.cacheKey}.png',
        Uint8List.fromList(bytes),
        key: key.cacheKey,
        maxAge: cacheLifetime,
        fileExtension: 'png',
      );
    } finally {
      retained.dispose();
    }
  }

  Future<void> _removeQuietly(String key) async {
    try {
      await _manager.removeFile(key);
    } catch (_) {
      // The next cache lookup will retry the source rasterization.
    }
  }
}
