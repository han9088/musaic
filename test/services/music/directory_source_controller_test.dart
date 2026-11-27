import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/services/music/directory_music_library.dart';
import 'package:musaic/services/music/music_provider.dart';
import 'package:musaic/services/music/music_source_controller.dart';
import 'package:musaic/storage/music/music_index.dart';
import 'package:musaic_query/musaic_query.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_audio_directories.dart';

class DelayedDirectories extends FakeDirectories {
  Completer<void>? restoreGate;
  bool cancelPick = false;
  final mediaPaths = <String, String>{};
  @override
  Future<Object?> invoke(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    if (method == 'restore') await restoreGate?.future;
    if (method == 'pick' && cancelPick) {
      picks++;
      return null;
    }
    if (method == 'mediaPaths') return mediaPaths;
    return super.invoke(method, args);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('only a confirmed file identity removes a folder track', () async {
    final index = await MusicIndex.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final native = DelayedDirectories();
    const document =
        'content://com.android.externalstorage.documents/document/a';
    native.mediaPaths[document] = '/a';
    native.folders['root'] = [
      entry('a', name: 'Same title.mp3'),
      entry('b', name: 'Same title.mp3'),
      {...entry('c', name: 'Same title.mp3'), 'uri': document},
    ];
    final library = DirectoryMusicLibrary(
      index: index,
      directories: AudioDirectories(native),
    );
    addTearDown(library.dispose);
    await index.saveSource(root);
    await library.refresh();
    const systemTrack = (
      reference: (
        provider: 'local',
        id: 'system-id',
        kind: MusicKind.song,
        source: MusicSource.library,
        storefront: null,
      ),
      title: 'Same title.mp3',
      artist: null,
      artworkUrl: null,
      duration: Duration(minutes: 1),
      playable: true,
    );
    const ProviderAlbum systemAlbum = (
      reference: (
        provider: 'local',
        id: 'album-id',
        kind: MusicKind.album,
        source: MusicSource.library,
        storefront: null,
      ),
      title: 'Album',
      artist: null,
      artworkUrl: null,
      trackCount: 1,
      tracks: [systemTrack],
    );
    final combined = await library.combineWithSystemAlbums([
      systemAlbum,
    ], (_) => '/a');
    expect(combined.first, systemAlbum);
    expect(combined.last.trackCount, 1);
    expect(combined.last.tracks!.single.reference.id, 'b');
    expect(library.albums.value.single.trackCount, 3);
  });

  test(
    'restores the saved folder catalog before the post-frame folder refresh',
    () async {
      final index = await MusicIndex.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final native = DelayedDirectories();
      final library = DirectoryMusicLibrary(
        index: index,
        directories: AudioDirectories(native),
      );
      var systemScans = 0;
      final controller = MusicSourceController(
        createLocal: () {
          systemScans++;
          throw StateError('Unexpected system library access');
        },
      );
      await index.saveSource(root);
      await library.refresh();
      await index.setSelected(true);
      await library.loadCached();
      native.restoreGate = Completer();
      await controller.attachDirectories(library);
      expect(controller.localSelected.value, true);
      expect(controller.catalog.value!.single.trackCount, 2);
      expect(controller.provider, isNotNull);
      expect(
        controller.catalog.value!.single.tracks!.every(
          (track) => track.playable,
        ),
        isTrue,
      );
      expect(native.playbackOpened, isEmpty);
      expect(native.closes, 1);
      expect(systemScans, 0);
      expect(native.restoreGate!.isCompleted, false);
      native.restoreGate!.complete();
      await library.refresh();
      await controller.dispose();
      await library.dispose();
    },
  );
  test(
    'background result cannot replace a newly selected mock source',
    () async {
      final index = await MusicIndex.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final native = DelayedDirectories();
      final library = DirectoryMusicLibrary(
        index: index,
        directories: AudioDirectories(native),
      );
      final controller = MusicSourceController();
      await index.saveSource(root);
      await library.refresh();
      await index.setSelected(true);
      native.restoreGate = Completer();
      await controller.attachDirectories(library);
      final scanning = library.refresh();
      await controller.selectMock();
      native.restoreGate!.complete();
      await scanning;
      expect(controller.catalog.value, isNull);
      expect(controller.localSelected.value, false);
      await controller.dispose();
      await library.dispose();
    },
  );
  test(
    'cancelled picker does not change selected source or persisted setting',
    () async {
      final index = await MusicIndex.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final native = DelayedDirectories()..cancelPick = true;
      final library = DirectoryMusicLibrary(
        index: index,
        directories: AudioDirectories(native),
      );
      final controller = MusicSourceController();
      await library.loadCached();
      await controller.attachDirectories(library);
      await controller.selectLocal();
      final catalog = controller.catalog.value;
      expect(catalog, isEmpty);
      expect(controller.localSelected.value, true);
      expect(await index.isSelected(), false);
      await controller.selectDirectories(add: true);
      expect(native.picks, 1);
      expect(controller.catalog.value, same(catalog));
      expect(controller.localSelected.value, true);
      expect(await index.isSelected(), false);
      await controller.dispose();
      await library.dispose();
    },
  );

  test(
    'desktop local music selects and rescans folders without a system provider',
    () async {
      final index = await MusicIndex.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final native = DelayedDirectories();
      final library = DirectoryMusicLibrary(
        index: index,
        directories: AudioDirectories(native),
      );
      final controller = MusicSourceController(
        systemLibraryEnabled: false,
        createLocal: () => throw StateError('Unexpected system library access'),
      );
      addTearDown(() async {
        await controller.dispose();
        await library.dispose();
      });
      await library.loadCached();
      await controller.attachDirectories(library);
      await controller.selectLocal();
      expect(controller.localSelected.value, isTrue);
      expect(controller.catalog.value, isEmpty);
      expect(controller.problem.value, isNull);

      await controller.selectDirectories(add: true);
      await controller.rescanLocal();
      expect(native.picks, 1);
      expect(controller.catalog.value!.single.trackCount, 2);
      expect(controller.problem.value, isNull);
      expect(await index.isSelected(), isTrue);
    },
  );
}
