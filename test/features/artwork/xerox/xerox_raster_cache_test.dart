import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/artwork/pipeline/artwork_pipeline.dart';
import 'package:musaic/features/artwork/pipeline/xerox_raster_resource.dart';
import 'package:musaic/features/artwork/xerox/xerox_job_scheduler.dart';
import 'package:musaic/features/artwork/xerox/xerox_disk_cache.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_cache.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_request.dart';
import 'package:musaic/features/artwork/xerox/xerox_rasterizer.dart';
import 'package:musaic/features/artwork/source/artwork_resolver.dart';
import 'package:musaic/features/artwork/model/artwork_source.dart';
import 'package:musaic/features/artwork/model/artwork_request.dart';
import 'package:musaic/features/artwork/cache/artwork_memory_policy.dart';

class _MemoryXeroxDiskCache implements XeroxDiskCacheStore {
  final values = <String, Uint8List>{};
  final _written = <String, Completer<void>>{};

  Future<void> written(String key) {
    if (values.containsKey(key)) return Future.value();
    return _written.putIfAbsent(key, Completer<void>.new).future;
  }

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
    _written.remove(key)?.complete();
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class _SlowDiskCache extends _MemoryXeroxDiskCache {
  final started = Completer<void>();
  final resume = Completer<void>();
  int active = 0;
  int peakActive = 0;

  @override
  Future<void> write(String key, Uint8List bytes) async {
    active++;
    if (active > peakActive) peakActive = active;
    if (!started.isCompleted) started.complete();
    try {
      await resume.future;
      await super.write(key, bytes);
    } finally {
      active--;
    }
  }
}

class _CongestedPipeline extends ArtworkPipeline {
  _CongestedPipeline(this.lease, {this.error = const XeroxRasterQueueFull()});

  final XeroxRasterLease lease;
  final Object error;
  int attempts = 0;

  @override
  XeroxRasterLease? tryAcquireXerox(XeroxRasterRequest request) => null;

  @override
  XeroxRasterTask requestXerox(
    XeroxRasterRequest request, {
    bool exactOnly = false,
  }) {
    attempts++;
    return attempts == 1
        ? XeroxRasterTask.failed(error)
        : XeroxRasterTask.completed(lease);
  }
}

class _SelectiveFailureRasterizer extends _FakeRasterizer {
  @override
  Future<ui.Image> rasterize(XeroxRasterRequest request) =>
      request.identity == 'broken'
      ? Future.error(StateError('Broken artwork'))
      : super.rasterize(request);
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
      ui.Canvas(recorder)
          .drawColor(const ui.Color(0xff111111), ui.BlendMode.src);
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(request.resolution, request.resolution);
      } finally {
        picture.dispose();
      }
    } finally {
      active--;
    }
  }
}

class _RecordingRasterizer extends _FakeRasterizer {
  _RecordingRasterizer({super.delay});

  final order = <String>[];

  @override
  Future<ui.Image> rasterize(XeroxRasterRequest request) {
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

XeroxRasterRequest _request(
  String identity, {
  int resolution = 4,
  XeroxRasterPriority priority = XeroxRasterPriority.background,
}) =>
    XeroxRasterRequest(
      identity: identity,
      image: AssetImage('assets/$identity.png'),
      resolution: resolution,
      fit: BoxFit.cover,
      devicePixelRatio: 1,
      priority: priority,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Artwork resolver resolves assets and identifies network sources',
    () async {
      const resolver = ArtworkResolver();
      const assetReference = 'assets/albums/cover.png';
      const networkReference = 'https://example.com/artwork/album-1.jpg';
      final asset = await resolver.resolveRequest(
        const ArtworkRequest(source: assetReference),
        directories: null,
      );
      final network = ArtworkSource.parse(networkReference);

      expect(asset?.image, isA<AssetImage>());
      expect(network.type, ArtworkSourceType.network);
      expect(network.identity, networkReference);
    },
  );

  test('platform memory policy provides a non-zero default budget', () {
    expect(ArtworkMemoryPolicy.defaultXeroxRasterBytes, greaterThan(0));
  });

  test(
    'Xerox display can borrow a raster from a different decode LOD',
    () async {
      final cache = XeroxRasterCache(
        rasterizer: _FakeRasterizer(),
        diskCache: _MemoryXeroxDiskCache(),
      );
      final pipeline = ArtworkPipeline(rasterCache: cache);
      final request = _request('layout-handoff');
      final previous = await cache.acquire(request);
      addTearDown(previous.release);
      final target = XeroxRasterRequest(
        identity: request.identity,
        image: request.image,
        resolution: request.resolution,
        originalDecodeResolution: request.originalDecodeResolution * 2,
      );

      expect(cache.tryAcquireBest(target), isNull);
      final fallback = pipeline.tryAcquireXerox(target);
      expect(fallback?.image, same(previous.image));
      addTearDown(fallback!.release);

      final upgraded = await pipeline
          .requestXerox(target, exactOnly: true)
          .future;
      expect(upgraded.key, target.key);
      expect(upgraded.image, isNot(same(previous.image)));
      upgraded.release();
    },
  );

  test(
    'Xerox PNG disk cache survives a new in-memory cache instance',
    () async {
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
      await disk.written(request.key.diskCacheKey);

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
    },
  );

  test(
    'a cache miss rasterizes the source and retries one transient failure',
    () async {
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
    },
  );

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
    final rasterizer = _FakeRasterizer(delay: const Duration(milliseconds: 5));
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

  test(
    'cancelling the last queued waiter prevents stale raster work',
    () async {
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
    },
  );

  test(
    'pinned images survive the budget and are evicted after release',
    () async {
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
    },
  );

  test(
    'an oversized result stays pinned until its lease is released',
    () async {
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
    },
  );

  test('visible and selected jobs overtake queued background raster work', () async {
    final rasterizer = _RecordingRasterizer(
      delay: const Duration(milliseconds: 5),
    );
    final cache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      maxConcurrentJobs: 1,
      rasterizer: rasterizer,
      diskCache: _MemoryXeroxDiskCache(),
    );

    final active = cache.request(_request('active'));
    final background = cache.request(_request('background'));
    final visible = cache.request(
      _request('visible', priority: XeroxRasterPriority.visible),
    );
    final selected = cache.request(
      _request('selected', priority: XeroxRasterPriority.selected),
    );

    final leases = await Future.wait([
      active.future,
      background.future,
      visible.future,
      selected.future,
    ]);
    expect(rasterizer.order, ['active', 'selected', 'visible', 'background']);
    for (final lease in leases) {
      lease.release();
    }
  });

  test('bounded queue drops stale background work for a visible request', () async {
    final rasterizer = _RecordingRasterizer(
      delay: const Duration(milliseconds: 5),
    );
    final cache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      maxConcurrentJobs: 1,
      maxQueuedJobs: 1,
      rasterizer: rasterizer,
      diskCache: _MemoryXeroxDiskCache(),
    );

    final active = cache.request(_request('active'));
    final background = cache.request(_request('background'));
    final backgroundCancelled = expectLater(
      background.future,
      throwsA(isA<XeroxRasterCancelled>()),
    );
    final visible = cache.request(
      _request('visible', priority: XeroxRasterPriority.visible),
    );

    final activeLease = await active.future;
    await backgroundCancelled;
    final visibleLease = await visible.future;

    expect(rasterizer.order, ['active', 'visible']);
    activeLease.release();
    visibleLease.release();
    expect(cache.queuedJobs, 0);
  });

  test('the raster cache limits concurrent GPU jobs', () async {
    final rasterizer = _FakeRasterizer(delay: const Duration(milliseconds: 5));
    final cache = XeroxRasterCache(
      maxBytes: 1024 * 1024,
      maxConcurrentJobs: 2,
      rasterizer: rasterizer,
      diskCache: _MemoryXeroxDiskCache(),
    );
    final scheduler = XeroxJobScheduler(maxConcurrentRequests: 6, cache: cache);
    final leases = await scheduler.prepare([
      for (var i = 0; i < 9; i++) _request('cover-$i'),
    ]);

    expect(leases, hasLength(9));
    expect(rasterizer.peakActive, lessThanOrEqualTo(2));
    for (final lease in leases) {
      lease.release();
    }
  });

  test('slow PNG writes do not block display or the next raster job', () async {
    final disk = _SlowDiskCache();
    final cache = XeroxRasterCache(
      maxBytes: 64,
      maxConcurrentJobs: 1,
      rasterizer: _FakeRasterizer(),
      diskCache: disk,
    );
    var delivered = false;
    final first = cache.acquire(_request('first')).then((lease) {
      delivered = true;
      return lease;
    });
    await disk.started.future;
    XeroxRasterLease? second;
    try {
      await Future<void>.delayed(Duration.zero);
      expect(delivered, isTrue);
      expect(cache.activeJobs, 0);
      (await first).release();
      second = await cache
          .acquire(_request('second'))
          .timeout(const Duration(seconds: 2));
      expect(cache.cachedBytes, 64);
      expect(disk.peakActive, 1);
    } finally {
      disk.resume.complete();
      (await first).release();
      second?.release();
    }
    await disk.written(_request('first').key.diskCacheKey);
    await disk.written(_request('second').key.diskCacheKey);
    expect(disk.peakActive, 1);
  });

  test('a broken overscan raster does not fail visible preparation', () async {
    final cache = XeroxRasterCache(
      rasterizer: _SelectiveFailureRasterizer(),
      diskCache: _MemoryXeroxDiskCache(),
    );
    final leases = await XeroxJobScheduler(cache: cache).prepare([
      _request('visible', priority: XeroxRasterPriority.visible),
      _request('broken', priority: XeroxRasterPriority.overscan),
    ]);
    expect(leases, hasLength(1));
    leases.single.release();
  });

  test('a broken visible raster still fails preparation', () async {
    final errors = <FlutterErrorDetails>[];
    final originalHandler = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = originalHandler);
    final cache = XeroxRasterCache(
      rasterizer: _SelectiveFailureRasterizer(),
      diskCache: _MemoryXeroxDiskCache(),
    );
    await expectLater(
      XeroxJobScheduler(cache: cache).prepare([
        _request('broken', priority: XeroxRasterPriority.visible),
      ]),
      throwsStateError,
    );
    expect(errors, hasLength(1));
  });

  testWidgets('unmounting cancels congestion recovery', (tester) async {
    final cache = XeroxRasterCache(
      rasterizer: _FakeRasterizer(),
      diskCache: _MemoryXeroxDiskCache(),
    );
    final request = _request('disposed');
    final lease = (await tester.runAsync(() => cache.acquire(request)))!;
    final pipeline = _CongestedPipeline(lease);
    await tester.pumpWidget(
      XeroxRasterResource(
        request: request,
        pipeline: pipeline,
        builder: (_, _) => const SizedBox.shrink(),
      ),
    );
    await tester.pump();
    expect(pipeline.attempts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(pipeline.attempts, 1);
    lease.release();
  });

  for (final error in [
    const XeroxRasterQueueFull(),
    const XeroxRasterCancelled(),
    StateError('Permanent decode failure'),
  ]) {
    testWidgets('resource recovers only transient failure: $error', (
      tester,
    ) async {
      final cache = XeroxRasterCache(
        rasterizer: _FakeRasterizer(),
        diskCache: _MemoryXeroxDiskCache(),
      );
      final request = _request('recovery');
      final lease = (await tester.runAsync(() => cache.acquire(request)))!;
      final pipeline = _CongestedPipeline(lease, error: error);
      Widget view() => Directionality(
        textDirection: TextDirection.ltr,
        child: XeroxRasterResource(
          request: request,
          pipeline: pipeline,
          builder: (image, _) => Text(image == null ? 'waiting' : 'ready'),
        ),
      );
      await tester.pumpWidget(view());
      await tester.pump();
      expect(find.text('waiting'), findsOneWidget);
      // Rebuilds while congested must not bypass the retry delay.
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(view());
      }
      expect(pipeline.attempts, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      final transient =
          error is XeroxRasterQueueFull || error is XeroxRasterCancelled;
      expect(pipeline.attempts, transient ? 2 : 1);
      expect(find.text(transient ? 'ready' : 'waiting'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      lease.release();
    });
  }

  testWidgets(
    'Xerox resource exposes the cached bitmap without an Image layer',
    (tester) async {
      final cache = XeroxRasterCache(
        rasterizer: _FakeRasterizer(),
        diskCache: _MemoryXeroxDiskCache(),
      );
      final request = XeroxRasterRequest(
        identity: 'prepared',
        image: AssetImage('assets/prepared.png'),
        resolution: 64,
        fit: BoxFit.cover,
        devicePixelRatio: 1,
      );
      final prepared = await tester.runAsync(() => cache.acquire(request));
      expect(prepared, isNotNull);

      final pipeline = ArtworkPipeline(rasterCache: cache);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 1),
            child: Center(
              child: SizedBox.square(
                dimension: 64,
                child: XeroxRasterResource(
                  request: request,
                  pipeline: pipeline,
                  builder: (image, _) => image == null
                      ? const SizedBox.shrink()
                      : RawImage(
                          image: image,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                ),
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
          of: find.byType(XeroxRasterResource),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      prepared!.release();
    },
  );
}
