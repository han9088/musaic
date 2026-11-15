import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

class MockAlbumCache {
  static const _warmupLimit = 32;
  Future<List<Map<String, dynamic>>>? _catalog;
  Future<void>? _warming;
  int _generation = 0;

  Future<List<Map<String, dynamic>>> load() => _catalog ??= rootBundle
      .loadString('assets/albums/catalog.json')
      .then(
        (value) => (jsonDecode(value) as List).cast<Map<String, dynamic>>(),
      );

  Future<void> warmImages(Future<void> Function(ImageProvider) precache) {
    return _warming ??= _warmImages(precache, _generation);
  }

  Future<void> _warmImages(
    Future<void> Function(ImageProvider) precache,
    int generation,
  ) async {
    final warmed = <String>{};
    // The image cache loads the remaining covers on demand as they enter view.
    for (final album in (await load()).take(_warmupLimit)) {
      if (generation != _generation) return;
      final asset = album['asset'] as String;
      if (warmed.add(asset)) await precache(AssetImage(asset));
    }
  }

  /// Evicts decoded mock covers; bundled originals remain available for reload.
  Future<void> clear() async {
    _generation++;
    await _warming;
    _warming = null;
    for (final album in await load()) {
      await AssetImage(album['asset'] as String).evict();
    }
  }
}
