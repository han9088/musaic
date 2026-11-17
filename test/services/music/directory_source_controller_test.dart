import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/services/music/directory_music_library.dart';
import 'package:musaic/services/music/music_source_controller.dart';
import 'package:musaic/storage/music/music_index.dart';
import 'package:musaic_query/musaic_query.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_audio_directories.dart';

class DelayedDirectories extends FakeDirectories {
  Completer<void>? restoreGate;
  bool cancelPick = false;
  @override
  Future<Object?> invoke(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    if (method == 'restore') await restoreGate?.future;
    if (method == 'pick' && cancelPick) return null;
    return super.invoke(method, args);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('restored catalog publishes before native scan completes', () async {
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
    await library.loadCached();
    native.restoreGate = Completer();
    await controller.attachDirectories(library);
    expect(controller.directorySelected.value, true);
    expect(controller.catalog.value!.single.trackCount, 2);
    expect(native.restoreGate!.isCompleted, false);
    native.restoreGate!.complete();
    await library.refresh();
    await controller.dispose();
    await library.dispose();
  });
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
      expect(controller.directorySelected.value, false);
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
      await controller.selectDirectories(add: true);
      expect(controller.catalog.value, null);
      expect(controller.directorySelected.value, false);
      expect(await index.isSelected(), false);
      await controller.dispose();
      await library.dispose();
    },
  );
}
