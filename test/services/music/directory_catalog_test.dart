import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/services/music/directory_catalog.dart';
import 'package:musaic/storage/music/music_index.dart';

import 'fake_audio_directories.dart';

({DirectoryCatalog catalog, String? isolate}) buildAndReport(
  MusicIndexRows rows,
) => (catalog: buildDirectoryCatalog(rows), isolate: Isolate.current.debugName);

void main() {
  test('large snapshot builds on a worker while main event loop remains live', () async {
    const count = 32768;
    final rows = MusicIndexRows(
      [
        {...root.toMap(), 'status': 'complete'},
      ],
      List.generate(
        count,
        (i) => {
          'id': 'track$i',
          'entry': jsonEncode(entry('track$i')),
          'metadata': jsonEncode({
            'album': 'Album ${i % 256}',
            'durationMs': 60000,
          }),
          'cover': 0,
        },
      ),
      List.generate(count, (i) => {'source': root.id, 'file': 'track$i'}),
    );
    var ticks = 0;
    final heartbeat = Timer.periodic(
      const Duration(milliseconds: 1),
      (_) => ticks++,
    );
    final rssBefore = ProcessInfo.currentRss;
    final watch = Stopwatch()..start();
    final result = await compute(
      buildAndReport,
      rows,
      debugLabel: 'directory-catalog-test',
    );
    heartbeat.cancel();
    expect(result.isolate, 'directory-catalog-test');
    expect(ticks, greaterThan(0));
    expect(result.catalog.tracks.length, count);
    expect(result.catalog.tracksById['track0']!.title, 'track0.mp3');
    expect(result.catalog.albums.length, 256);
    expect(
      result.catalog.albums.every((album) => album.trackCount == 128),
      true,
    );
    expect(result.catalog.folders.single.count, count);
    expect(result.catalog.folders.single.bytes, count * 100);
    // Observations from a host test, not device frame-time or peak memory claims.
    // ignore: avoid_print
    print(
      '32768 rows: worker ${watch.elapsedMilliseconds}ms; main heartbeat $ticks; RSS delta ${ProcessInfo.currentRss - rssBefore} bytes',
    );
  });
}
