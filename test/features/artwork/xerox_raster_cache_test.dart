import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/artwork/xerox/xerox_artwork.dart';
import 'package:musaic/features/artwork/xerox/xerox_job_scheduler.dart';
import 'package:musaic/features/artwork/xerox/xerox_disk_cache.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_cache.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_request.dart';
import 'package:musaic/features/artwork/xerox/xerox_rasterizer.dart';
import 'package:musaic/features/artwork/artwork_image_provider.dart';

class _MemoryXeroxDiskCache implements XeroxDiskCacheStore {
  final values = <String, Uint8List>{};

  @override
  Future<ui.Image?> read(String key) async {
    final bytes = values[key];
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
    values[key] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

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

class _FailOnceRasterizer extends _FakeRasterizer {
  int failuresRemaining = 1;

  @override
  Future<ui.Image> rasterize(XeroxRasterRequest request) {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      calls++;
      return Future.error(StateError('Temporary decode failure.'));
    }
    return super.rasterize(request);
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
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Artwork resolver keeps Demo assets local and routes URLs to disk cache', () {
    final asset = ArtworkImageResolver.resolve('assets/albums/cover.png');
    final network = ArtworkImageResolver.resolve(
      'https://example.com/artwork/album-1.jpg',
    );

    expect(asset, isA<AssetImage>());
    expect(network, isA<CachedNetworkImageProvider>());
  });

  test('Xerox PNG disk cache survives a new in-memory cache instance', () async {
    final disk = _MemoryXeroxDiskCache();
    final firstRasterizer = _FakeRasterizer();
    final firstCache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      rasterizer: firstRasterizer,
      diskCache: disk,
    );
    final request = _request('persistent');
    final first = await firstCache.acquire(request);
    first.release();

    expect(disk.values, contains(request.key.diskCacheKey));
    expect(firstRasterizer.calls, 1);

    final secondRasterizer = _FakeRasterizer();
    final secondCache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      rasterizer: secondRasterizer,
      diskCache: disk,
    );
    final restored = await secondCache.acquire(request);

    expect(secondRasterizer.calls, 0);
    expect(restored.image.width, request.resolution);
    restored.release();
  });

  test('a cache miss rasterizes the source and retries one transient failure', () async {
    final rasterizer = _FailOnceRasterizer();
    final cache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      rasterizer: rasterizer,
      diskCache: _MemoryXeroxDiskCache(),
    );
    final lease = await cache.acquire(_request('fallback'));

    expect(rasterizer.calls, 2);
    expect(lease.image.width, 4);
    lease.release();
  });

  test('a permanently failing raster is bounded to two attempts', () async {
    final rasterizer = _FailOnceRasterizer()..failuresRemaining = 2;
    final cache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      rasterizer: rasterizer,
      diskCache: _MemoryXeroxDiskCache(),
    );

    await expectLater(
      cache.acquire(_request('unavailable')),
      throwsA(isA<StateError>()),
    );
    expect(rasterizer.calls, 2);
    expect(cache.queuedJobs, 0);
  });

  test('identical requests share one in-flight raster job', () async {
    final rasterizer = _FakeRasterizer(
      delay: const Duration(milliseconds: 5),
    );
    final cache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      maxConcurrentJobs: 2,
      rasterizer: rasterizer,
      diskCache: _MemoryXeroxDiskCache(),
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

  test('cancelling the last queued waiter prevents stale raster work', () async {
    final rasterizer = _FakeRasterizer(
      delay: const Duration(milliseconds: 5),
    );
    final cache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      maxConcurrentJobs: 1,
      rasterizer: rasterizer,
      diskCache: _MemoryXeroxDiskCache(),
    );
    final active = cache.request(_request('active'));
    final queued = cache.request(_request('queued'));
    final cancelled = expectLater(
      queued.future,
      throwsA(isA<XeroxRasterCancelled>()),
    );

    queued.cancel();
    final lease = await active.future;
    await cancelled;

    expect(rasterizer.calls, 1);
    expect(cache.queuedJobs, 0);
    lease.release();
  });

  test('pinned images survive the budget and are evicted after release', () async {
    final cache = XeroxRasterCache(
      maxBytes: 64,
      rasterizer: _FakeRasterizer(),
      diskCache: _MemoryXeroxDiskCache(),
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
      diskCache: _MemoryXeroxDiskCache(),
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
      diskCache: _MemoryXeroxDiskCache(),
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
      diskCache: _MemoryXeroxDiskCache(),
    );
    final provider = AssetImage('assets/prepared.png');
    final prepared = await tester.runAsync(
      () => cache.acquire(
        XeroxRasterRequest(
          identity: 'prepared',
          image: provider,
          resolution: 64,
          fit: BoxFit.cover,
          devicePixelRatio: 1,
        ),
      ),
    );
    expect(prepared, isNotNull);

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
    // A prepared cache hit is acquired synchronously in the first build,
    // so the entrance animation never flies in a temporary placeholder.
    expect(find.byType(RawImage), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(
      find.descendant(
        of: find.byType(XeroxArtwork),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    prepared!.release();
  });
}
