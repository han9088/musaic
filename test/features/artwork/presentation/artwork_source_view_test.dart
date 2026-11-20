import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/mode/artwork_mode_transition.dart';
import 'package:musaic/features/artwork/model/artwork_request.dart';
import 'package:musaic/features/artwork/model/artwork_resource.dart';
import 'package:musaic/features/artwork/pipeline/artwork_pipeline.dart';
import 'package:musaic/features/artwork/pipeline/xerox_background_processor.dart';
import 'package:musaic/features/artwork/presentation/artwork_renderer.dart';
import 'package:musaic/features/artwork/presentation/artwork_source_view.dart';
import 'package:musaic/features/artwork/presentation/xerox_palette.dart';
import 'package:musaic/features/artwork/source/artwork_resolver.dart';
import 'package:musaic/features/artwork/xerox/xerox_disk_cache.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_cache.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_request.dart';
import 'package:musaic/features/artwork/xerox/xerox_rasterizer.dart';
import 'package:musaic/services/music/directory_music_library.dart';
import 'package:musaic/ui/transitions/source_tile_motion.dart';

class _Resolver extends ArtworkResolver {
  _Resolver(this.resource);
  final ArtworkResource resource;

  @override
  Future<ArtworkResource?> resolveRequest(
    ArtworkRequest request, {
    required DirectoryMusicLibrary? directories,
  }) async => resource;
}

class _NoBackgroundProcessing extends XeroxBackgroundProcessor {
  @override
  void enqueue(XeroxRasterRequest request) {}
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

Future<MemoryImage> _wideImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(512, 256);
  picture.dispose();
  try {
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return MemoryImage(png.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}

void main() {
  testWidgets(
    'a resolved cover stays mounted at both ends of the mode animation',
    (tester) async {
      const viewport = Size(300, 600);
      const cells = [(row: 0, column: 0, rect: Rect.fromLTWH(0, 0, 100, 100))];
      const loading = ValueKey('cover-loading');
      final pipeline = ArtworkPipeline(
        resolver: _Resolver(
          const ArtworkResource(
            identity: 'album',
            sourceKey: 'asset',
            image: AssetImage('assets/albums/0.jpg'),
          ),
        ),
        backgroundProcessor: _NoBackgroundProcessing(),
      );
      late StateSetter rebuild;
      final transition = ArtworkModeTransition(
        vsync: tester,
        isMounted: () => true,
        notifyChanged: () => rebuild(() {}),
        onMotionChanged: () {},
      );
      addTearDown(transition.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 1),
            child: StatefulBuilder(
              builder: (_, setState) {
                rebuild = setState;
                return transition.animateTile(
                  0,
                  0,
                  ArtworkSourceView(
                    request: const ArtworkRequest(source: 'test'),
                    width: 100,
                    height: 100,
                    placeholder: const SizedBox(key: loading),
                    pipeline: pipeline,
                  ),
                  scale: () => 1,
                  viewport: (_) => viewport,
                  tileSize: 100,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      final cover = tester.element(find.byType(ArtworkSourceView));
      expect(find.byKey(loading), findsNothing);

      final done = transition.start(
        exit: SourceTileMotion.exit(cells, viewport),
        enter: SourceTileMotion.enter(cells),
        onHandoff: () {},
      );
      final flashes = <String>[];
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find.byKey(loading).evaluate().isNotEmpty) {
          flashes.add('frame $frame (${transition.phase})');
        }
      }
      await done;
      expect(flashes, isEmpty);
      expect(tester.element(find.byType(ArtworkSourceView)), same(cover));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
    final artwork = find.byWidgetPredicate((widget) => widget is RawImage);
    final renderObject = tester.renderObject(artwork);

    for (final palette in [
      XeroxPalette.original,
      XeroxPalette.ivory,
      XeroxPalette.sage,
      XeroxPalette.original,
    ]) {
      selection.value = palette;
      await tester.pump();
      expect(tester.renderObject(artwork), same(renderObject));
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
      expect(tester.widget<RawImage>(artwork).image, same(lease.image));
    }
    expect(rasterizer.resolutions, [256]);
    expect(cache.cachedEntries, 1);
    expect(disk.writes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mode handoff uses the prewarmed LOD after a zoom', (
    tester,
  ) async {
    final image = (await tester.runAsync(_wideImage))!;
    final resource = ArtworkResource(
      identity: 'album',
      sourceKey: 'source',
      image: image,
    );
    final rasterizer = _Rasterizer();
    final cache = XeroxRasterCache(
      rasterizer: rasterizer,
      diskCache: _NoDisk(),
    );
    final pipeline = ArtworkPipeline(
      resolver: _Resolver(resource),
      rasterCache: cache,
      backgroundProcessor: _NoBackgroundProcessing(),
    );
    final prepared = pipeline.createDisplayPlan(
      resource: resource,
      targetSize: const Size.square(300),
      devicePixelRatio: 1,
    );
    final lease = (await tester.runAsync(
      () => cache.acquire(prepared.xeroxRequest),
    ))!;

    Widget view(double size, {bool xerox = false}) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1),
        child: Center(
          child: SizedBox.square(
            dimension: size,
            child: ArtworkSourceView(
              request: const ArtworkRequest(source: 'test'),
              placeholder: const SizedBox.shrink(),
              xerox: xerox,
              fit: BoxFit.cover,
              pipeline: pipeline,
            ),
          ),
        ),
      ),
    );
    ArtworkRenderer renderer() =>
        tester.widget<ArtworkRenderer>(find.byType(ArtworkRenderer));
    await tester.pumpWidget(view(200));
    await tester.pump();
    await tester.pumpWidget(view(300));
    expect(renderer().plan.originalDecodeResolution, 256);
    await tester.pumpWidget(view(300, xerox: true));
    expect(renderer().plan.originalDecodeResolution, 512);
    expect(renderer().processedImage, same(lease.image));
    expect(rasterizer.resolutions, [512]);
    await tester.pumpWidget(const SizedBox.shrink());
    lease.release();
  });

  testWidgets('original decoding preserves the source aspect ratio', (
    tester,
  ) async {
    final image = (await tester.runAsync(_wideImage))!;
    final resource = ArtworkResource(
      identity: 'wide',
      sourceKey: 'wide',
      image: image,
    );
    final plan = ArtworkPipeline.instance.createDisplayPlan(
      resource: resource,
      targetSize: const Size.square(200),
      devicePixelRatio: 1,
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ArtworkRenderer(
          resource: resource,
          plan: plan,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          semanticLabel: null,
          excludeFromSemantics: false,
          xerox: false,
          placeholder: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.runAsync(() async {
      final provider = tester.widget<Image>(find.byType(Image)).image;
      await precacheImage(provider, tester.element(find.byType(Image)));
    });
    await tester.pump();
    final decoded = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect(decoded.width / decoded.height, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
