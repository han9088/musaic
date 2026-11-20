import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/model/artwork_request.dart';
import 'package:musaic/features/artwork/model/artwork_resource.dart';
import 'package:musaic/features/artwork/pipeline/artwork_pipeline.dart';
import 'package:musaic/features/artwork/presentation/artwork_source_view.dart';
import 'package:musaic/features/artwork/presentation/xerox_palette.dart';
import 'package:musaic/features/artwork/source/artwork_resolver.dart';
import 'package:musaic/features/artwork/xerox/xerox_disk_cache.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_cache.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_request.dart';
import 'package:musaic/features/artwork/xerox/xerox_rasterizer.dart';
import 'package:musaic/services/music/directory_music_library.dart';

class _Resolver extends ArtworkResolver {
  _Resolver(this.resource);
  final ArtworkResource resource;

  @override
  Future<ArtworkResource?> resolveRequest(
    ArtworkRequest request, {
    required DirectoryMusicLibrary? directories,
  }) async => resource;
}

class _NoDisk implements XeroxDiskCacheStore {
  int writes = 0;

  @override
  Future<ui.Image?> read(String key) async => null;
  @override
  Future<void> write(String key, Uint8List bytes) async {
    writes++;
  }

  @override
  Future<void> remove(String key) async {}
}

class _Rasterizer extends XeroxRasterizer {
  final resolutions = <int>[];

  @override
  Future<ui.Image> rasterize(XeroxRasterRequest request) async {
    resolutions.add(request.originalDecodeResolution);
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xffffffff), ui.BlendMode.src)
      ..drawRect(
        Rect.fromLTWH(
          0,
          0,
          request.resolution / 2,
          request.resolution.toDouble(),
        ),
        ui.Paint()..color = const Color(0xff000000),
      );
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(request.resolution, request.resolution);
    } finally {
      picture.dispose();
    }
  }
}

void main() {
  testWidgets('changing Xerox paper and ink reuses the same cached bitmap', (
    tester,
  ) async {
    final resource = ArtworkResource(
      identity: 'album',
      sourceKey: 'source',
      image: const AssetImage('unused'),
    );
    final rasterizer = _Rasterizer();
    final disk = _NoDisk();
    final cache = XeroxRasterCache(rasterizer: rasterizer, diskCache: disk);
    final pipeline = ArtworkPipeline(
      resolver: _Resolver(resource),
      rasterCache: cache,
    );
    final prepared = pipeline.createDisplayPlan(
      resource: resource,
      targetSize: const Size.square(64),
      devicePixelRatio: 1,
    );
    final lease = (await tester.runAsync(() async {
      final lease = await cache.acquire(prepared.xeroxRequest);
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (disk.writes == 0 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return lease;
    }))!;
    final selection = ValueNotifier(XeroxPalette.original);
    final boundaryKey = GlobalKey();
    addTearDown(selection.dispose);
    addTearDown(lease.release);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 1),
          child: Center(
            child: XeroxPaletteScope(
              notifier: selection,
              child: RepaintBoundary(
                key: boundaryKey,
                child: ArtworkSourceView(
                  request: const ArtworkRequest(source: 'test'),
                  placeholder: const SizedBox.shrink(),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  xerox: true,
                  pipeline: pipeline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final palette in [
      XeroxPalette.original,
      XeroxPalette.ivory,
      XeroxPalette.sage,
      XeroxPalette.original,
    ]) {
      selection.value = palette;
      await tester.pump();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final rendered = boundary.toImageSync();
      final pixels = (await tester.runAsync(
        () => rendered.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
      ))!;
      rendered.dispose();
      List<int> rgbAt(int x) => [
        for (var channel = 0; channel < 3; channel++)
          pixels.getUint8((32 * 64 + x) * 4 + channel),
      ];
      List<int> rgb(Color color) => [
        color.r,
        color.g,
        color.b,
      ].map((value) => (value * 255).round()).toList();
      expect(rgbAt(16), rgb(palette.ink));
      expect(rgbAt(48), rgb(palette.paper));
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image,
        same(lease.image),
      );
    }
    expect(rasterizer.resolutions, [256]);
    expect(cache.cachedEntries, 1);
    expect(disk.writes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
