import 'dart:async';
import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final class ControlledPlatform extends MusicKitPlatform {
  final initialization = Completer<void>();
  final playback = Completer<void>();
  final calls = <String>[];
  @override
  Stream<MusicPlayerState> get playerStates => const Stream.empty();
  @override
  Future<void> initialize(MusicKitPlatformConfig config) =>
      initialization.future;
  @override
  Future<void> play() async {
    calls.add('play');
    await playback.future;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> dispose({bool stopPlayback = false}) async {
    calls.add('dispose');
  }
}

void main() {
  test('initialization must finish before commands can run', () async {
    final platform = ControlledPlatform();
    final client =
        AppleMusicClient(config: const AppleMusicConfig(), platform: platform);
    final initialization = client.initialize();
    expect(() => client.player.play(), throwsA(isA<MusicKitException>()));
    final disposal = client.dispose();
    expect(identical(disposal, client.dispose()), isTrue);
    expect(platform.calls, isEmpty);
    platform.initialization.complete();
    await initialization;
    await disposal;
    expect(platform.calls, ['dispose']);
    expect(await client.isInitialized, isFalse);
  });
  test('dispose drains in-flight command but rejects queued commands',
      () async {
    final platform = ControlledPlatform()..initialization.complete();
    final client =
        AppleMusicClient(config: const AppleMusicConfig(), platform: platform);
    await client.initialize();
    final play = client.player.play();
    await Future<void>.delayed(Duration.zero);
    final pause = client.player.pause();
    final rejected = expectLater(
        pause,
        throwsA(isA<MusicKitException>()
            .having((e) => e.code, 'code', MusicKitErrorCode.alreadyDisposed)));
    final disposal = client.dispose();
    platform.playback.complete();
    await Future.wait([play, rejected, disposal]);
    expect(platform.calls, ['play', 'dispose']);
  });
}
