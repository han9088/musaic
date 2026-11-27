import 'package:audius_sdk/audius_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:musaic/services/music/audius_music_provider.dart';
import 'package:musaic/services/music/music_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Audius public streams advance in the native queue', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final provider = AudiusMusicProvider(
        sdk: AudiusSdk(apiKey: const String.fromEnvironment('AUDIUS_API_KEY')),
      );
      addTearDown(provider.dispose);
      final items = <MusicReference>[
        for (final id in ['Jpr6KYY', 'M2l69g9'])
          (
            provider: AudiusMusicProvider.providerId,
            id: id,
            kind: MusicKind.song,
            source: MusicSource.catalog,
            storefront: null,
          ),
      ];
      final events = <MusicPlayback>[];
      final subscription = provider.playback.listen(events.add);
      addTearDown(subscription.cancel);

      Future<MusicPlayback> playing(int index, Duration after) => provider
          .playback
          .firstWhere(
            (event) =>
                event.currentItem == items[index] &&
                event.status == MusicPlaybackStatus.playing &&
                event.duration != null &&
                event.position >= after,
          )
          .timeout(const Duration(seconds: 30));

      await provider.play(items);
      final first = await playing(0, const Duration(milliseconds: 500));
      final nearEnd = first.duration! - const Duration(seconds: 8);
      expect(nearEnd, greaterThan(Duration.zero));
      await provider.seek(nearEnd);
      await playing(0, nearEnd + const Duration(seconds: 1));
      final transitionStart = events.length;
      final second = await playing(1, Duration.zero);
      expect(second.position, lessThan(const Duration(seconds: 1)));
      final transition = events.skip(transitionStart);
      expect(transition, isNotEmpty);
      expect(
        transition.every(
          (event) => event.status == MusicPlaybackStatus.playing,
        ),
        isTrue,
        reason: transition
            .map((event) => (event.status, event.position))
            .join(', '),
      );
      await playing(1, const Duration(milliseconds: 500));
      final previousStart = events.length;
      final elapsed = Stopwatch()..start();
      await provider.previous();
      await playing(0, const Duration(milliseconds: 100));
      final previous = events.skip(previousStart);
      expect(
        previous.any((event) => event.status == MusicPlaybackStatus.loading),
        isFalse,
      );
      expect(elapsed.elapsed, lessThan(const Duration(seconds: 1)));
    });
  }, skip: !const bool.fromEnvironment('MUSAIC_TEST_AUDIUS_LIVE'));
}
