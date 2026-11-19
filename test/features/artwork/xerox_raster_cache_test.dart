import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/artwork/xerox/xerox_artwork.dart';
import 'package:musaic/features/artwork/xerox/xerox_job_scheduler.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_cache.dart';
import 'package:musaic/features/artwork/xerox/xerox_disk_cache.dart';
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

class _OrderedRasterizer extends _FakeRasterizer {
  _OrderedRasterizer(this.order);

  final List<String> order;

  @override
  Future<ui.Image> rasterize(XeroxRasterRequest request) async {
    order.add(request.identity);
    return super.rasterize(request);
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

class _NoopDiskStore implements XeroxRasterDiskStore {
  @override
  Future<ui.Image?> read(XeroxRasterKey key) async => null;

  @override
  Future<(XeroxRasterKey, ui.Image)?> readBest(XeroxRasterKey key) async =>
      null;

  @override
  Future<void> write(XeroxRasterKey key, ui.Image image) async {}
}

class _MemoryDiskStore implements XeroxRasterDiskStore {
  final Map<String, ui.Image> _images = {};
  final Map<String, XeroxRasterKey> _keys = {};

  @override
  Future<ui.Image?> read(XeroxRasterKey key) async =>
      _images[key.cacheKey]?.clone();

  @override
  Future<(XeroxRasterKey, ui.Image)?> readBest(XeroxRasterKey key) async {
    final candidates = _images.entries
        .where((entry) {
          final candidate = _keys[entry.key];
          return candidate != null && candidate.sameArtwork(key);
        })
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final aKey = _keys[a.key]!;
      final bKey = _keys[b.key]!;
      final aLower = aKey.resolution <= key.resolution;
      final bLower = bKey.resolution <= key.resolution;
      if (aLower != bLower) return aLower ? -1 : 1;
      return aLower
          ? bKey.resolution.compareTo(aKey.resolution)
          : aKey.resolution.compareTo(bKey.resolution);
    });
    final selected = candidates.first;
    final selectedKey = _keys[selected.key]!;
    return (selectedKey, selected.value.clone());
  }

  @override
  Future<void> write(XeroxRasterKey key, ui.Image image) async {
    _images.remove(key.cacheKey)?.dispose();
    _images[key.cacheKey] = image.clone();
    _keys[key.cacheKey] = key;
  }

  void dispose() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _keys.clear();
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
  test('visible raster requests overtake queued background work', () async {
    final order = <String>[];
    final rasterizer = _OrderedRasterizer(order);
    final cache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      maxConcurrentJobs: 1,
      maxQueuedJobs: 4,
      rasterizer: rasterizer,
      diskStore: _NoopDiskStore(),
    );

    final active = cache.request(_request('active'), priority: 0);
    await Future<void>.delayed(Duration.zero);
    final background = cache.request(_request('background'), priority: 10);
    final visible = cache.request(_request('visible'), priority: 100);

    final leases = await Future.wait([
      active.future,
      background.future,
      visible.future,
    ]);
    expect(order, ['active', 'visible', 'background']);
    for (final lease in leases) {
      lease.release();
    }
  });

  test('the queue rejects excess background jobs without growing unbounded', () async {
    final rasterizer = _FakeRasterizer(
      delay: const Duration(milliseconds: 5),
    );
    final cache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      maxConcurrentJobs: 1,
      maxQueuedJobs: 1,
      rasterizer: rasterizer,
      diskStore: _NoopDiskStore(),
    );

    final active = cache.request(_request('active'));
    await Future<void>.delayed(Duration.zero);
    final queued = cache.request(_request('queued'), priority: 1);
    final rejected = cache.request(_request('rejected'), priority: 0);
    await expectLater(
      rejected.future,
      throwsA(isA<XeroxRasterQueueFull>()),
    );

    final activeLease = await active.future;
    final queuedLease = await queued.future;
    expect(cache.queuedJobs, 0);
    activeLease.release();
    queuedLease.release();
  });

  test('disk cache reuses a higher LOD when the requested LOD is missing', () async {
    final diskStore = _MemoryDiskStore();
    final highRequest = _request('lod-fallback', resolution: 512);
    final firstCache = XeroxRasterCache(
      maxBytes: 1024 * 1024 * 8,
      rasterizer: _FakeRasterizer(),
      diskStore: diskStore,
    );
    final highLease = await firstCache.acquire(highRequest);
    highLease.release();
    await Future<void>.delayed(Duration.zero);

    final secondRasterizer = _FakeRasterizer();
    final secondCache = XeroxRasterCache(
      maxBytes: 1024 * 1024 * 8,
      rasterizer: secondRasterizer,
      diskStore: diskStore,
    );
    final lowLease = await secondCache.acquire(
      _request('lod-fallback', resolution: 256),
    );

    expect(secondRasterizer.calls, 0);
    expect(lowLease.resolution, 512);
    lowLease.release();
    diskStore.dispose();
  });

  test('processed rasters survive cache recreation through the disk store', () async {
    final diskStore = _MemoryDiskStore();
    final firstRasterizer = _FakeRasterizer();
    final request = _request('persistent');

    final firstCache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      rasterizer: firstRasterizer,
      diskStore: diskStore,
    );
    final firstLease = await firstCache.acquire(request);
    firstLease.release();
    await Future<void>.delayed(Duration.zero);

    final secondRasterizer = _FakeRasterizer();
    final secondCache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      rasterizer: secondRasterizer,
      diskStore: diskStore,
    );
    final secondLease = await secondCache.acquire(request);

    expect(firstRasterizer.calls, 1);
    expect(secondRasterizer.calls, 0);
    expect(secondLease.image.width, request.resolution);
    secondLease.release();
    diskStore.dispose();
  });

  test('persistent keys are stable and include source, algorithm and LOD', () {
    final first = _request('same', resolution: 64).key;
    final same = _request('same', resolution: 64).key;
    final otherSource = XeroxRasterRequest(
      identity: 'same',
      sourceKey: 'new-source-version',
      image: AssetImage('assets/same.png'),
      resolution: 64,
    ).key;
    final otherLod = _request('same', resolution: 128).key;
    final otherAlgorithm = XeroxRasterRequest(
      identity: 'same',
      image: AssetImage('assets/same.png'),
      resolution: 64,
      algorithmVersion: 'xerox-v2',
    ).key;

    expect(first.cacheKey, same.cacheKey);
    expect(first.cacheKey, isNot(otherSource.cacheKey));
    expect(first.cacheKey, isNot(otherLod.cacheKey));
    expect(first.cacheKey, isNot(otherAlgorithm.cacheKey));
  });

  test('a cache miss rasterizes the source and retries one transient failure', () async {
    final rasterizer = _FailOnceRasterizer();
    final cache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      rasterizer: rasterizer,
      diskStore: _NoopDiskStore(),
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
      diskStore: _NoopDiskStore(),
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
      diskStore: _NoopDiskStore(),
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
      diskStore: _NoopDiskStore(),
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
      diskStore: _NoopDiskStore(),
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
      diskStore: _NoopDiskStore(),
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
      diskStore: _NoopDiskStore(),
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
      diskStore: _NoopDiskStore(),
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
