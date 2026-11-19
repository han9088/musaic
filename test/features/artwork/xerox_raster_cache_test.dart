import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/artwork/xerox/xerox_artwork.dart';
import 'package:musaic/features/artwork/xerox/xerox_job_scheduler.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_cache.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_request.dart';
import 'package:musaic/features/artwork/xerox/xerox_rasterizer.dart';

class _FakeRasterizer extends XeroxRasterizer {
  _FakeRasterizer({this.delay = Duration.zero});

  final Duration delay;
  int calls = 0;
  int active = 0;
  int peakActive = 0;

  @override
  Future<ui.Image> rasterize(XeroxRasterRequest request) async {
    calls++;
    active++;
    if (active > peakActive) peakActive = active;
    try {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(
        const ui.Color(0xff111111),
        ui.BlendMode.src,
      );
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(
          request.resolution,
          request.resolution,
        );
      } finally {
        picture.dispose();
      }
    } finally {
      active--;
    }
  }
}

XeroxRasterRequest _request(String identity, {int resolution = 4}) =>
    XeroxRasterRequest(
      identity: identity,
      image: AssetImage('assets/$identity.png'),
      resolution: resolution,
      fit: BoxFit.cover,
      devicePixelRatio: 1,
    );

void main() {
  test('identical requests share one in-flight raster job', () async {
    final rasterizer = _FakeRasterizer(
      delay: const Duration(milliseconds: 5),
    );
    final cache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      maxConcurrentJobs: 2,
      rasterizer: rasterizer,
    );
    final request = _request('same');
    final leases = await Future.wait([
      cache.acquire(request),
      cache.acquire(request),
    ]);

    expect(rasterizer.calls, 1);
    expect(identical(leases[0].image, leases[1].image), isTrue);
    leases[0].release();
    leases[1].release();
  });

  test('pinned images survive the budget and are evicted after release', () async {
    final cache = XeroxRasterCache(
      maxBytes: 64,
      rasterizer: _FakeRasterizer(),
    );
    final first = await cache.acquire(_request('first'));
    final second = await cache.acquire(_request('second'));

    expect(cache.cachedBytes, 128);
    first.release();
    expect(cache.cachedBytes, 64);
    expect(second.image.width, 4);
    second.release();
  });

  test('an oversized result stays pinned until its lease is released', () async {
    final cache = XeroxRasterCache(
      maxBytes: 1,
      rasterizer: _FakeRasterizer(),
    );
    final lease = await cache.acquire(_request('oversized'));

    expect(lease.image.width, 4);
    expect(cache.cachedBytes, 64);
    lease.release();
    expect(cache.cachedBytes, 0);
  });

  test('the raster cache limits concurrent GPU jobs', () async {
    final rasterizer = _FakeRasterizer(
      delay: const Duration(milliseconds: 5),
    );
    final cache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      maxConcurrentJobs: 2,
      rasterizer: rasterizer,
    );
    final scheduler = XeroxJobScheduler(
      maxConcurrentRequests: 6,
      cache: cache,
    );
    final leases = await scheduler.prepare([
      for (var i = 0; i < 9; i++) _request('cover-$i'),
    ]);

    expect(leases, hasLength(9));
    expect(rasterizer.peakActive, lessThanOrEqualTo(2));
    for (final lease in leases) {
      lease.release();
    }
  });

  testWidgets('XeroxArtwork displays the cached bitmap without an Image layer', (
    tester,
  ) async {
    final cache = XeroxRasterCache(
      rasterizer: _FakeRasterizer(),
    );
    final provider = AssetImage('assets/prepared.png');
    final prepared = await cache.acquire(
      XeroxRasterRequest(
        identity: 'prepared',
        image: provider,
        resolution: 64,
        fit: BoxFit.cover,
        devicePixelRatio: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 64,
            child: XeroxArtwork(
              identity: 'prepared',
              image: provider,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              cache: cache,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(RawImage), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(CustomPaint), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    prepared.release();
  });
}
