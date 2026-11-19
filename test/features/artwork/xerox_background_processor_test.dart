import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/artwork/pipeline/xerox_background_processor.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_cache.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_request.dart';
import 'package:musaic/features/artwork/xerox/xerox_rasterizer.dart';
import 'package:musaic/features/artwork/xerox/xerox_disk_cache.dart';

class _Rasterizer extends XeroxRasterizer {
  int calls = 0;

  @override
  Future<ui.Image> rasterize(XeroxRasterRequest request) async {
    calls++;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(
      const ui.Color(0xff111111),
      ui.BlendMode.src,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(request.resolution, request.resolution);
    } finally {
      picture.dispose();
    }
  }
}

class _NoopStore implements XeroxRasterDiskStore {
  @override
  Future<ui.Image?> read(XeroxRasterKey key) async => null;

  @override
  Future<void> write(XeroxRasterKey key, ui.Image image) async {}
}

void main() {
  test('background processing deduplicates the same artwork request', () async {
    final rasterizer = _Rasterizer();
    final cache = XeroxRasterCache(
      rasterizer: rasterizer,
      diskStore: _NoopStore(),
    );
    final processor = XeroxBackgroundProcessor(cache: cache);
    final request = XeroxRasterRequest(
      identity: 'asset:cover',
      sourceKey: 'asset:cover',
      image: AssetImage('assets/cover.png'),
      resolution: 128,
    );

    processor.enqueue(request);
    processor.enqueue(request);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(rasterizer.calls, 1);
    expect(processor.pendingCount, 0);
    expect(cache.cachedEntries, 1);
  });
}
