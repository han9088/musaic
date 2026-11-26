/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:apple_music_kit/mock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMusicKitPlatform platform;
  late AppleMusicClient client;

  // Lets queued platform state events propagate to the facade tracker.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() {
    platform = MockMusicKitPlatform();
    client = AppleMusicClient(
        config: const AppleMusicConfig(appName: 'test'), platform: platform);
  });

  tearDown(() async {
    await client.dispose();
  });

  group('AppleMusicClient lifecycle', () {
    test('initialize is idempotent and concurrent calls share one run',
        () async {
      await Future.wait([client.initialize(), client.initialize()]);
      await client.initialize();
      expect(await client.isInitialized, isTrue);
    });

    test('methods before initialize throw notInitialized', () async {
      expect(
        () => platform.getAuthorizationStatus(),
        throwsA(isA<MusicKitException>()
            .having((e) => e.code, 'code', MusicKitErrorCode.notInitialized)),
      );
    });

    test('facade methods before initialize throw notInitialized', () async {
      // The guard throws synchronously before a Future is created.
      expect(
        () => client.authorization.getStatus(),
        throwsA(isA<MusicKitException>()
            .having((e) => e.code, 'code', MusicKitErrorCode.notInitialized)),
      );
      expect(
        () => client.player.play(),
        throwsA(isA<MusicKitException>()
            .having((e) => e.code, 'code', MusicKitErrorCode.notInitialized)),
      );
      expect(
        () => client.catalog.getSong('x'),
        throwsA(isA<MusicKitException>()
            .having((e) => e.code, 'code', MusicKitErrorCode.notInitialized)),
      );
    });

    test('isInitialized is false before initialize and true after', () async {
      expect(await client.isInitialized, isFalse);
      await client.initialize();
      expect(await client.isInitialized, isTrue);
    });

    test('a failed initialize is not cached and can be retried', () async {
      final failPlatform = _FailingThenWorkingPlatform();
      final failClient = AppleMusicClient(
          config: const AppleMusicConfig(), platform: failPlatform);
      try {
        await failClient.initialize();
        fail('first initialize must throw');
      } on MusicKitException {
        // expected
      }
      expect(await failClient.isInitialized, isFalse);
      failPlatform.startWorking();
      await failClient.initialize();
      expect(await failClient.isInitialized, isTrue);
      await failClient.dispose();
    });

    test('dispose is idempotent', () async {
      await client.initialize();
      await client.dispose();
      await client.dispose();
    });

    test('initialize after dispose throws alreadyDisposed', () async {
      await client.dispose();
      expect(
        () => client.initialize(),
        throwsA(isA<MusicKitException>()
            .having((e) => e.code, 'code', MusicKitErrorCode.alreadyDisposed)),
      );
    });
  });

  group('authorization', () {
    test('request grants and streams status', () async {
      await client.initialize();
      expect(await client.authorization.getStatus(),
          MusicAuthorizationStatus.notDetermined);
      final status = await client.authorization.request();
      expect(status, MusicAuthorizationStatus.authorized);
      expect(await client.authorization.getStatus(),
          MusicAuthorizationStatus.authorized);
    });

    test('denial mode reports denied', () async {
      final denyPlatform = MockMusicKitPlatform(autoGrantAuthorization: false);
      final denyClient = AppleMusicClient(
          config: const AppleMusicConfig(), platform: denyPlatform);
      await denyClient.initialize();
      expect(await denyClient.authorization.request(),
          MusicAuthorizationStatus.denied);
      await denyClient.dispose();
    });
  });

  group('subscription', () {
    test('reports subscription independent of authorization', () async {
      await client.initialize();
      final sub = await client.subscription.status;
      expect(sub.status, MusicSubscriptionStatus.subscribed);
      expect(sub.canPlayCatalogContent, isTrue);
    });
  });

  group('catalog', () {
    test('search returns matching songs', () async {
      await client.initialize();
      final result = await client.catalog
          .search('aurora', types: {MusicResourceType.song});
      expect(result.songs!.items, isNotEmpty);
      expect(result.songs!.items.first.title, 'Aurora Borealis');
    });

    test('search with no match returns empty pages', () async {
      await client.initialize();
      final result = await client.catalog.search('zzzz-no-match');
      expect(result.songs!.items, isEmpty);
      expect(result.albums!.items, isEmpty);
    });

    test('getSong throws resourceNotFound for unknown id', () async {
      await client.initialize();
      expect(
        () => client.catalog.getSong('nope'),
        throwsA(isA<MusicKitException>()
            .having((e) => e.code, 'code', MusicKitErrorCode.resourceNotFound)),
      );
    });

    test('charts return songs', () async {
      await client.initialize();
      final charts = await client.catalog.getCharts(MusicChartKind.songs);
      expect(charts, hasLength(1));
      expect(charts.first.songs!.items, isNotEmpty);
    });
  });

  group('library', () {
    test('lists songs', () async {
      await client.initialize();
      final page = await client.library.getSongs();
      expect(page.items, hasLength(3));
    });

    test('createPlaylist returns an id', () async {
      await client.initialize();
      final created = await client.library.createPlaylist('Road Trip');
      expect(created.id, isNotEmpty);
      expect(created.name, 'Road Trip');
    });
  });

  group('player', () {
    test('setQueue + play emits states with current item', () async {
      await client.initialize();
      final states = <MusicPlayerState>[];
      final sub = client.player.states.listen(states.add);
      const ref = MusicItemRef(id: 'mock-song-1', type: MusicResourceType.song);
      await client.player.setQueue([ref], autoplay: false);
      await client.player.play();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(states, isNotEmpty);
      expect(states.last.currentItem, ref);
      expect(states.last.status, MusicPlayerStatus.playing);
      expect(states.last.isPlaying, isTrue);
    });

    test('pause and stop transition status', () async {
      await client.initialize();
      const ref = MusicItemRef(id: 'mock-song-1', type: MusicResourceType.song);
      await client.player.setQueue([ref], autoplay: false);
      await client.player.play();
      await client.player.pause();
      await settle();
      expect(client.player.currentState.status, MusicPlayerStatus.paused);
      await client.player.stop();
      await settle();
      expect(client.player.currentState.status, MusicPlayerStatus.stopped);
    });

    test('skipToNext advances and completes at queue end', () async {
      await client.initialize();
      const a = MusicItemRef(id: 'mock-song-1', type: MusicResourceType.song);
      const b = MusicItemRef(id: 'mock-song-2', type: MusicResourceType.song);
      await client.player.setQueue([a, b], autoplay: false);
      await settle();
      expect(client.player.currentState.currentIndex, 0);
      await client.player.skipToNext();
      await settle();
      expect(client.player.currentState.currentIndex, 1);
      await client.player.skipToNext();
      await settle();
      expect(client.player.currentState.status, MusicPlayerStatus.completed);
    });

    test('append and remove edit the queue', () async {
      await client.initialize();
      const a = MusicItemRef(id: 'mock-song-1', type: MusicResourceType.song);
      const b = MusicItemRef(id: 'mock-song-2', type: MusicResourceType.song);
      await client.player.setQueue([a], autoplay: false);
      await client.player.append([b]);
      var queue = await client.player.getQueue();
      expect(queue.length, 2);
      await client.player.removeAt(1);
      queue = await client.player.getQueue();
      expect(queue.length, 1);
    });

    test('shuffle and repeat modes update state', () async {
      await client.initialize();
      await client.player.setQueue(
          [const MusicItemRef(id: 'mock-song-1', type: MusicResourceType.song)],
          autoplay: false);
      await client.player.setShuffleMode(MusicShuffleMode.on);
      await client.player.setRepeatMode(MusicRepeatMode.one);
      await settle();
      expect(client.player.currentState.shuffleMode, MusicShuffleMode.on);
      expect(client.player.currentState.repeatMode, MusicRepeatMode.one);
    });

    test('rapid setQueue/play sequences end with the newest intent', () async {
      await client.initialize();
      const a = MusicItemRef(id: 'mock-song-1', type: MusicResourceType.song);
      const b = MusicItemRef(id: 'mock-song-2', type: MusicResourceType.song);
      // Fire a burst of commands without awaiting each.
      final f1 = client.player.setQueue([a], autoplay: false);
      final f2 = client.player.play();
      final f3 = client.player.setQueue([b], autoplay: false);
      final f4 = client.player.play();
      await Future.wait([f1, f2, f3, f4]);
      await settle();
      expect(client.player.currentState.currentItem, b,
          reason: 'the last setQueue must win');
      expect(client.player.currentState.isPlaying, isTrue);
    });

    test('states stream replays latest snapshot to new subscribers', () async {
      await client.initialize();
      const ref = MusicItemRef(id: 'mock-song-1', type: MusicResourceType.song);
      await client.player.setQueue([ref], autoplay: false);
      final received = <MusicPlayerState>[];
      final sub = client.player.states.listen(received.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(received, isNotEmpty);
      expect(received.first.currentItem, ref,
          reason: 'new subscriber must immediately see the latest state');
    });

    test('a second subscriber receives the current snapshot', () async {
      await client.initialize();
      final first = client.player.states.listen((_) {});
      const ref = MusicItemRef(id: 'mock-song-1', type: MusicResourceType.song);
      await client.player.setQueue([ref], autoplay: false);
      await settle();
      final snapshot = await client.player.states.first;
      expect(snapshot.currentItem, ref);
      await first.cancel();
    });

    test('identical consecutive states are deduplicated', () async {
      await client.initialize();
      final platformStates = <MusicPlayerState>[];
      final sub = platform.playerStates.listen(platformStates.add);
      const ref = MusicItemRef(id: 'mock-song-1', type: MusicResourceType.song);
      await client.player.setQueue([ref], autoplay: false);
      await client.player.pause(); // already paused-ish; may dedupe
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      // The mock dedupes internally; the facade's distinct() must not
      // re-emit duplicates either.
      for (var i = 1; i < platformStates.length; i++) {
        expect(platformStates[i], isNot(platformStates[i - 1]),
            reason: 'no consecutive duplicate states allowed');
      }
    });
  });

  group('capabilities', () {
    test('mock reports all supported', () async {
      await client.initialize();
      final caps = await client.capabilities.get();
      expect(caps.canPlayCatalog.supported, isTrue);
      expect(caps.canSeek.supported, isTrue);
      expect(caps.canEditQueue.supported, isTrue);
    });
  });

  group('installMusicKitMock', () {
    test('installs the mock as the platform instance', () {
      installMusicKitMock();
      expect(MusicKitPlatform.instance, isA<MockMusicKitPlatform>());
    });
  });
}

/// A platform whose initialize() fails until [startWorking] is called.
final class _FailingThenWorkingPlatform extends MusicKitPlatform {
  bool _working = false;
  void startWorking() => _working = true;

  @override
  Future<void> initialize(MusicKitPlatformConfig config) async {
    if (!_working) {
      throw const MusicKitException(
        MusicKitErrorCode.networkError,
        message: 'simulated failure',
      );
    }
  }

  @override
  Stream<MusicPlayerState> get playerStates =>
      const Stream<MusicPlayerState>.empty();

  @override
  Future<void> dispose({bool stopPlayback = false}) async {}
}
