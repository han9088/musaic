import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:musaic/services/music/directory_music_library.dart';
import 'package:musaic/services/music/local_music_provider.dart';
import 'package:musaic/services/music/music_provider.dart';
import 'package:musaic/services/music/musaic_music_queue.dart';
import 'package:musaic/storage/music/music_index.dart';
import 'package:musaic_query/musaic_query.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native folder queue advances, seeks, and switches tracks', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final folder = await Directory.systemTemp.createTemp('musaic-gapless');
      addTearDown(() => folder.delete(recursive: true));
      for (var i = 1; i <= 4; i++) {
        await File('${folder.path}/$i.wav').writeAsBytes(_tone(220 * i));
      }
      final directories = MusaicQuery().directories;
      final index = await MusicIndex.open(path: ':memory:');
      addTearDown(index.close);
      final library = DirectoryMusicLibrary(
        index: index,
        directories: directories,
      );
      addTearDown(library.dispose);
      await index.saveSource(await directories.openPath(folder.path));
      await library.refresh();
      final songs = [for (final album in library.albums.value) ...?album.tracks]
        ..sort((a, b) => a.title.compareTo(b.title));
      expect(songs, hasLength(4));

      final provider = LocalMusicProvider.folderOnly(library);
      addTearDown(provider.dispose);
      final items = [for (final song in songs) song.reference];
      final events = <MusicPlayback>[];
      final subscription = provider.playback.listen(events.add);
      addTearDown(subscription.cancel);

      Future<MusicPlayback> waitFor(int item, MusicPlaybackStatus status) =>
          provider.playback
              .firstWhere(
                (event) =>
                    event.currentItem == items[item] && event.status == status,
              )
              .timeout(const Duration(seconds: 12));

      await provider.play(items);
      final first = await waitFor(0, MusicPlaybackStatus.playing);
      expect(first.duration, const Duration(seconds: 2));
      final second = await waitFor(1, MusicPlaybackStatus.playing);
      expect(second.position, lessThan(const Duration(milliseconds: 500)));
      final transition = events
          .skipWhile(
            (event) =>
                event.currentItem != items[0] ||
                event.status != MusicPlaybackStatus.playing ||
                event.position < const Duration(milliseconds: 100),
          )
          .takeWhile(
            (event) => event.currentItem != items[1] || !event.isPlaying,
          );
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

      await provider.pause();
      await waitFor(1, MusicPlaybackStatus.paused);
      await provider.seek(const Duration(milliseconds: 900));
      final paused = await waitFor(1, MusicPlaybackStatus.paused);
      expect(paused.position.inMilliseconds, closeTo(900, 25));
      await provider.resume();
      await waitFor(1, MusicPlaybackStatus.playing);
      await provider.next();
      await waitFor(2, MusicPlaybackStatus.playing);
      await provider.previous();
      await waitFor(1, MusicPlaybackStatus.playing);
      await provider.play(items, startIndex: 2);
      await waitFor(2, MusicPlaybackStatus.playing);
      await waitFor(3, MusicPlaybackStatus.playing);
      await waitFor(3, MusicPlaybackStatus.completed);
      await provider.pause();
      expect(
        (await provider.playback.first).status,
        MusicPlaybackStatus.completed,
      );
      await provider.resume();
      final restarted = await waitFor(3, MusicPlaybackStatus.playing);
      expect(restarted.position, lessThan(const Duration(milliseconds: 500)));
      await provider.dispose();
      expect(await provider.playback.isEmpty, isTrue);
    });
  });

  testWidgets('a slow preload does not block first play or skip a track', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final folder = await Directory.systemTemp.createTemp('musaic-preload');
      addTearDown(() => folder.delete(recursive: true));
      final file = await File('${folder.path}/tone.wav')
          .writeAsBytes(_tone(330));
      final items = <MusicReference>[
        for (final id in ['a', 'b'])
          (
            provider: 'test',
            kind: MusicKind.song,
            id: id,
            source: MusicSource.library,
            storefront: null,
          ),
      ];
      final delayed = Completer<MusicQueueSource>();
      final delayedClosed = Completer<void>();
      final closed = <String>[];
      var nextRequests = 0;
      final queue = MusaicMusicQueue((item) async {
        if (item == items[1] && ++nextRequests == 1) return delayed.future;
        return (uri: file.uri, close: () async => closed.add(item.id));
      });
      addTearDown(queue.dispose);
      Future<MusicPlayback> playing(int index) => queue.playback
          .firstWhere(
            (value) =>
                value.currentItem == items[index] &&
                value.status == MusicPlaybackStatus.playing,
          )
          .timeout(const Duration(seconds: 12));

      await queue.play(items, 0);
      await playing(0);
      expect(nextRequests, 1);
      await playing(1);
      expect(nextRequests, 2);
      await queue.dispose();
      delayed.complete((
        uri: file.uri,
        close: () async => delayedClosed.complete(),
      ));
      await delayedClosed.future.timeout(const Duration(seconds: 5));
      expect(closed, ['a', 'b']);
    });
  });

  testWidgets('a previous track switches to its cached file in the queue', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final folder = await Directory.systemTemp.createTemp(
        'musaic-audio-cache',
      );
      addTearDown(() => folder.delete(recursive: true));
      final original = await File('${folder.path}/original.wav')
          .writeAsBytes(_tone(220));
      final cached = await File('${folder.path}/cached.wav')
          .writeAsBytes(_tone(220, seconds: 4));
      final items = <MusicReference>[
        for (final id in ['a', 'b'])
          (
            provider: 'test',
            kind: MusicKind.song,
            id: id,
            source: MusicSource.catalog,
            storefront: null,
          ),
      ];
      var firstOpens = 0;
      final queue = MusaicMusicQueue((item) async {
        if (item == items[0]) firstOpens++;
        return (uri: original.uri, close: null);
      }, cachedUri: (item) async => item == items[0] ? cached.uri : null);
      addTearDown(queue.dispose);
      Future<void> playing(int index, int seconds) async {
        await queue.playback
            .firstWhere(
              (value) =>
                  value.currentItem == items[index] &&
                  value.status == MusicPlaybackStatus.playing &&
                  value.duration == Duration(seconds: seconds),
            )
            .timeout(const Duration(seconds: 12));
      }

      await queue.play(items, 0);
      await playing(0, 2);
      await playing(1, 2);
      await queue.previous();
      await playing(0, 4);
      expect(firstOpens, 1);
      await queue.next();
      await playing(1, 2);
    });
  });
}

Uint8List _tone(int frequency, {int seconds = 2}) {
  const rate = 22050;
  final samples = rate * seconds;
  final dataLength = samples * 2;
  final bytes = ByteData(44 + dataLength);
  bytes.setUint32(0, 0x52494646); // RIFF
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  bytes.setUint32(8, 0x57415645); // WAVE
  bytes.setUint32(12, 0x666D7420); // fmt
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // Mono
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  bytes.setUint32(36, 0x64617461); // data
  bytes.setUint32(40, dataLength, Endian.little);
  for (var i = 0; i < samples; i++) {
    final sample = (math.sin(2 * math.pi * frequency * i / rate) * 2400)
        .round();
    bytes.setInt16(44 + i * 2, sample, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
