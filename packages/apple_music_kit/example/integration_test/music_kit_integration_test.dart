/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
///
/// Integration tests against REAL Apple Music infrastructure.
///
/// ⚠️ These tests are NOT run in CI and have NOT been executed in this
/// repository. They require:
///   - a valid developer token served at TOKEN_ENDPOINT (see
///     lib/token_source.dart),
///   - an Apple ID with an active Apple Music subscription on the device,
///   - MusicKit entitlement on the iOS App ID,
///   - a physical device (iOS playback does not work in the simulator).
///
/// Run on device:
///   flutter test integration_test/music_kit_integration_test.dart \
///     --dart-define=TOKEN_ENDPOINT=https://your-server/token \
///     --dart-define=USE_MOCK=false
library;

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:apple_music_kit_example/token_source.dart' as token_source;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppleMusicClient client;

  setUpAll(() async {
    client = AppleMusicClient(
      config: AppleMusicConfig(
        appName: 'integration-test',
        developerTokenProvider: token_source.ExampleTokenProvider(),
      ),
    );
    await client.initialize();
  });

  tearDownAll(() async {
    await client.dispose();
  });

  group('authorization', () {
    testWidgets('request returns a terminal status', (tester) async {
      final status = await client.authorization.request();
      expect(
        status,
        anyOf(
          MusicAuthorizationStatus.authorized,
          MusicAuthorizationStatus.denied,
          MusicAuthorizationStatus.restricted,
        ),
      );
    });
  });

  group('catalog', () {
    testWidgets('search finds a known song', (tester) async {
      final result = await client.catalog.search(
        'Never Gonna Give You Up Rick Astley',
        types: {MusicResourceType.song},
        limit: 5,
      );
      expect(result.songs, isNotNull);
      expect(result.songs!.items, isNotEmpty);
      final song = result.songs!.items.first;
      expect(song.id, isNotEmpty);
      expect(song.title, isNotEmpty);
    });

    testWidgets('getSong returns the resource', (tester) async {
      final search = await client.catalog.search(
        'Never Gonna Give You Up Rick Astley',
        types: {MusicResourceType.song},
        limit: 1,
      );
      final id = search.songs!.items.first.id;
      final song = await client.catalog.getSong(id);
      expect(song.id, id);
    });

    testWidgets('charts return songs', (tester) async {
      final charts = await client.catalog.getCharts(MusicChartKind.songs, limit: 5);
      expect(charts, isNotEmpty);
      expect(charts.first.songs, isNotNull);
    });

    testWidgets('storefront resolves', (tester) async {
      final storefront = await client.catalog.getCurrentStorefront();
      expect(storefront.id, hasLength(2));
    });
  });

  group('playback (requires subscription + authorized user)', () {
    // Skipped automatically when not authorized.
    testWidgets('setQueue + play + pause roundtrip', (tester) async {
      final status = await client.authorization.getStatus();
      if (status != MusicAuthorizationStatus.authorized) {
        // ignore: avoid_print
        print('SKIPPED: not authorized ($status)');
        return;
      }
      final search = await client.catalog.search(
        'Never Gonna Give You Up Rick Astley',
        types: {MusicResourceType.song},
        limit: 1,
      );
      await client.player.setQueue([search.songs!.items.first.ref]);
      await client.player.play();
      await tester.pump(const Duration(seconds: 2));
      expect(client.player.currentState.isPlaying, isTrue);
      await client.player.pause();
      await tester.pump(const Duration(milliseconds: 300));
      expect(client.player.currentState.isPlaying, isFalse);
    });
  });
}
