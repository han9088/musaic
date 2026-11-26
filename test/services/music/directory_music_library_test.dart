import 'dart:async';
import 'dart:io';

import 'fake_audio_directories.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:musaic_query/musaic_query.dart';
import 'package:musaic/services/music/directory_music_library.dart';
import 'package:musaic/storage/music/music_index.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late MusicIndex index;
  late DirectoryMusicLibrary library;
  late FakeDirectories native;
  setUp(() async {
    index = await MusicIndex.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    native = FakeDirectories();
    library = DirectoryMusicLibrary(
      index: index,
      directories: AudioDirectories(native),
    );
    await index.saveSource(root);
  });
  tearDown(() => library.dispose());

  test(
    'unchanged files parse zero times; one modification parses one',
    () async {
      await library.refresh();
      expect(native.parsed, ['a', 'b']);
      native.parsed.clear();
      await library.refresh();
      expect(native.parsed, isEmpty);
      native.folders['root']![0] = entry('a', modified: 2);
      await library.refresh();
      expect(native.parsed, ['a']);
      expect(library.tracks.value.length, 2);
      expect(library.counts.value.skipped, 1);
    },
  );
  test(
    'unchanged scan writes no file rows but renews every membership',
    () async {
      await library.refresh();
      await index.database.execute('CREATE TABLE writes (id TEXT)');
      await index.database.execute(
        'CREATE TRIGGER count_file_updates AFTER UPDATE ON files BEGIN INSERT INTO writes VALUES(NEW.id); END',
      );
      final before = await index.database.query('memberships');
      native.parsed.clear();
      await library.refresh();
      expect(await index.database.query('writes'), isEmpty);
      expect(native.parsed, isEmpty);
      final after = await index.database.query('memberships');
      expect(after.length, 2);
      expect(after.first['generation'], isNot(before.first['generation']));
      native.folders['root']![0] = entry('a', modified: 2);
      await library.refresh();
      expect(await index.database.query('writes'), [
        {'id': 'a'},
      ]);
      expect(native.parsed, ['a']);
      expect(library.track('a'), same(library.tracks.value.first));
    },
  );
  test('stable identity rename updates locator without reading tags', () async {
    await library.refresh();
    native.parsed.clear();
    native.folders['root']![0] = entry('a', name: 'renamed.mp3');
    await library.refresh();
    expect(native.parsed, isEmpty);
    expect(library.track('a')!.file.name, 'renamed.mp3');
    expect(library.counts.value.deleted, 0);
    expect(library.tracks.value.length, 2);
  });
  test(
    'snapshot summaries include empty directories and support filters',
    () async {
      native.folders['root']!.addAll([
        entry('sub', directory: true),
        entry('empty', directory: true),
      ]);
      native.folders['sub'] = [
        entry('child', parent: 'sub', size: 200),
        entry('cover', parent: 'sub', name: 'cover.jpg'),
      ];
      native.folders['empty'] = [];
      await library.refresh();
      final recursive = library.folders.value;
      expect(recursive.singleWhere((f) => f.id == 'root').count, 3);
      expect(recursive.singleWhere((f) => f.id == 'root').bytes, 400);
      expect(recursive.singleWhere((f) => f.id == 'empty').count, 0);
      expect(recursive.every((f) => f.complete), true);
      final direct = await library.summaries();
      expect(direct.singleWhere((f) => f.id == 'root').count, 2);
      final filtered = await library.summaries(
        recursive: true,
        filter: const AudioFilter(minSize: 200),
      );
      expect(filtered.singleWhere((f) => f.id == 'root').count, 1);
      expect(library.tracks.value.length, 3);
      await library.loadCached();
      expect(library.folders.value.singleWhere((f) => f.id == 'root').count, 3);
    },
  );
  test('cache load and disposal cannot publish a stale snapshot', () async {
    await library.refresh();
    native.folders['root'] = [entry('new')];
    final cached = library.loadCached();
    final refresh = library.refresh();
    await Future.wait([cached, refresh]);
    expect(library.tracks.value.single.file.id, 'new');
    final loading = library.loadCached();
    await library.dispose();
    await loading;
  });
  test('adds and deletes reconcile only after complete enumeration', () async {
    await library.refresh();
    native.folders['root'] = [entry('b'), entry('c')];
    await library.refresh();
    expect(library.tracks.value.map((t) => t.file.id), ['b', 'c']);
    expect(library.counts.value.deleted, 1);
    native.folders['root'] = [];
    native.restoreFails = true;
    await library.refresh();
    expect(library.tracks.value.length, 2);
    expect(library.state.value, DirectoryScanState.failed);
  });
  test('partial directory failure preserves unseen cached files', () async {
    native.folders['root']!.add(entry('sub', directory: true));
    native.folders['sub'] = [entry('child', parent: 'sub')];
    await library.refresh();
    native.folders['root'] = [entry('sub', directory: true)];
    native.failures.add('sub');
    await library.refresh();
    expect(library.tracks.value.length, 3);
    expect(library.counts.value.deleted, 0);
  });
  test(
    'cancellation prevents in-flight metadata from committing or deleting',
    () async {
      await library.refresh();
      native.folders['root'] = [entry('new')];
      native.gate = Completer();
      final task = library.refresh();
      while (!native.parsed.contains('new')) {
        await Future<void>.delayed(Duration.zero);
      }
      library.cancel();
      native.gate!.complete();
      await task;
      expect(library.state.value, DirectoryScanState.cancelled);
      expect(library.tracks.value.map((t) => t.file.id), ['a', 'b']);
      expect(native.closes, 2);
    },
  );
  test('refresh coalesces and force refresh revalidates every file', () async {
    native.gate = Completer();
    final first = library.refresh();
    final second = library.refresh();
    expect(identical(first, second), true);
    native.gate!.complete();
    await first;
    native.parsed.clear();
    await library.refresh(force: true);
    expect(native.parsed, ['a', 'b']);
  });
  test('damaged files do not abort siblings and are retried', () async {
    native.damaged.add('a');
    await library.refresh();
    expect(library.tracks.value.length, 1);
    native.damaged.clear();
    native.parsed.clear();
    await library.refresh();
    expect(native.parsed, ['a']);
    expect(library.tracks.value.length, 2);
  });
  test('unknown timestamps revalidate after one day', () async {
    await library.dispose();
    index = await MusicIndex.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await index.saveSource(root);
    var now = DateTime(2026);
    library = DirectoryMusicLibrary(
      index: index,
      directories: AudioDirectories(native),
      now: () => now,
    );
    native.folders['root'] = [entry('a', modified: null)];
    await library.refresh();
    native.parsed.clear();
    await library.refresh();
    expect(native.parsed, isEmpty);
    now = now.add(const Duration(days: 2));
    await library.refresh();
    expect(native.parsed, ['a']);
  });
  test(
    'cover selection is deterministic and independent of audio tags',
    () async {
      native.folders['root']!.addAll([
        entry('front', name: 'FRONT.PNG'),
        entry('cover', name: 'cover.jpg'),
      ]);
      await library.refresh();
      expect((await index.cover('root'))!.id, 'cover');
      native.parsed.clear();
      native.folders['root']!.removeWhere((e) => e['id'] == 'cover');
      await library.refresh();
      expect(native.parsed, isEmpty);
      expect((await index.cover('root'))!.id, 'front');
      expect(library.tracks.value.length, 2);
      final a = library.tracks.value.first;
      await Future.wait([library.artwork(a), library.artwork(a)]);
      expect(native.artworkCalls, 1);
    },
  );
  test('cached catalog is visible without native authorization', () async {
    await library.refresh();
    native.restoreFails = true;
    native.parsed.clear();
    await library.loadCached();
    expect(library.tracks.value.length, 2);
    expect(native.parsed, isEmpty);
  });
  test(
    'overlapping sources share file identity without duplicate tracks',
    () async {
      const second = AudioDirectory(id: 'other', name: 'Other', token: 'other');
      await index.saveSource(second);
      native.folders['other'] = [entry('a'), entry('b')];
      await library.refresh();
      expect(native.parsed.length, 2);
      expect(library.tracks.value.length, 2);
      await index.saveSource(root);
      expect((await index.sources()).length, 2);
      native.deniedSources.add(root.id);
      await library.refresh();
      expect(
        library.tracks.value.every((track) => track.source.id == 'other'),
        true,
      );
      await library.remove(root);
      expect(library.tracks.value.length, 2);
    },
  );
  test('adding a source waits until its old grant has been released', () async {
    await library.refresh();
    native.releaseGate = Completer();
    final removing = library.remove(root);
    while (native.releases == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    final adding = library.addDirectory();
    final picksBeforeRelease = native.picks;
    native.releaseGate!.complete();
    await removing;
    expect((await adding)?.id, root.id);
    expect(picksBeforeRelease, 0);
    expect((await index.sources()).single.id, root.id);
  });
  test(
    'dispose waits for source mutations and skips queued additions',
    () async {
      native.releaseGate = Completer();
      final removing = library.remove(root);
      while (native.releases == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final adding = library.addDirectory();
      var disposed = false;
      final disposal = library.dispose();
      expect(identical(library.dispose(), disposal), true);
      final closing = disposal.then((_) => disposed = true);
      await Future<void>.delayed(Duration.zero);
      expect(disposed, false);
      native.releaseGate!.complete();
      await Future.wait([removing, closing]);
      expect(await adding, isNull);
      expect(native.picks, 0);
    },
  );
  test(
    'a queued refresh can be cancelled before touching the source',
    () async {
      native.releaseGate = Completer();
      final removing = library.remove(root);
      while (native.releases == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final scanning = library.refresh();
      library.cancel();
      native.releaseGate!.complete();
      await Future.wait([removing, scanning]);
      expect(library.state.value, DirectoryScanState.cancelled);
      expect(native.parsed, isEmpty);
    },
  );
  test(
    'old artwork failures cannot evict a newer request after clearing',
    () async {
      await library.refresh();
      final oldGate = Completer<String?>();
      final newGate = Completer<String?>();
      native.artworkGates.addAll([oldGate, newGate]);
      final track = library.tracks.value.first;
      final old = library.artwork(track);
      final oldFailure = expectLater(old, throwsStateError);
      while (native.artworkCalls < 1) {
        await Future<void>.delayed(Duration.zero);
      }
      await library.clearArtworkCache();
      final current = library.artwork(track);
      while (native.artworkCalls < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      oldGate.completeError(StateError('old request failed'));
      await oldFailure;
      newGate.complete('file:///new-cover.jpg');
      expect(await current, 'file:///new-cover.jpg');
      expect(await library.artwork(track), 'file:///new-cover.jpg');
      expect(native.artworkCalls, 2);
    },
  );
  test('artwork cache hits at capacity retain request coalescing', () async {
    await library.refresh();
    final track = library.tracks.value.first;
    for (var size = 1; size <= 128; size++) {
      await library.artwork(track, size: size);
    }
    expect(native.artworkCalls, 128);
    await library.artwork(track, size: 1);
    expect(native.artworkCalls, 128);
  });
  test(
    'artwork requests from distinct grants never share a cached result',
    () async {
      await library.refresh();
      final track = library.tracks.value.first;
      await library.artwork(track);
      final renewed = IndexedAudio(
        const AudioDirectory(id: 'root', name: 'Music', token: 'renewed-grant'),
        track.file,
        track.metadata,
      );
      await library.artwork(renewed);
      expect(native.artworkCalls, 2);
    },
  );
  test('a new scan clears previous counters before its first page', () async {
    await library.refresh();
    expect(library.counts.value.added, 2);
    native.gate = Completer();
    native.parsed.clear();
    final refreshing = library.refresh(force: true);
    while (native.parsed.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(library.counts.value.added, 0);
    native.gate!.complete();
    await refreshing;
  });
  test(
    'a rejected authorization does not poison subsequent queued work',
    () async {
      const other = AudioDirectory(id: 'other', name: 'Other', token: 'other');
      await expectLater(library.reauthorize(other), throwsArgumentError);
      await library.refresh();
      expect(library.state.value, DirectoryScanState.complete);
      expect(library.tracks.value.length, 2);
    },
  );
  test(
    'partial pages commit healthy files without deleting unseen records',
    () async {
      await library.refresh();
      native.folders['root'] = [entry('new')];
      native.partialFailures.add('root');
      await library.refresh();
      expect(library.tracks.value.map((track) => track.file.id), [
        'a',
        'b',
        'new',
      ]);
      expect(library.state.value, DirectoryScanState.failed);
      expect(library.counts.value.added, 1);
      expect(library.counts.value.deleted, 0);
      expect(library.folders.value.single.complete, false);
    },
  );
  test('disposing waits for an already requested folder summary', () async {
    await library.refresh();
    final summary = library.summaries();
    final closing = library.dispose();
    expect((await summary).single.count, 2);
    await closing;
  });
  test('large catalog remains paged and incremental', () async {
    native.folders['root'] = List.generate(4096, (i) => entry('track$i'));
    final rssBefore = ProcessInfo.currentRss;
    final timer = Stopwatch()..start();
    await library.refresh();
    expect(library.tracks.value.length, 4096);
    expect(native.parsed.length, 4096);
    native.parsed.clear();
    await library.refresh();
    expect(native.parsed, isEmpty);
    expect(library.counts.value.skipped, 4096);
    // A reproducible throughput observation, not a real-device benchmark.
    // ignore: avoid_print
    print(
      '4096 files: initial + incremental ${timer.elapsedMilliseconds}ms; page <=128; RSS delta ${ProcessInfo.currentRss - rssBefore} bytes',
    );
  });
}
