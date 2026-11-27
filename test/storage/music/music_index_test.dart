import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/storage/music/music_index.dart';
import 'package:musaic_query/musaic_query.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test('Windows opens its music index through SQLite FFI', () async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
    final index = await MusicIndex.open(path: inMemoryDatabasePath);
    addTearDown(index.close);

    await index.saveSource(
      const AudioDirectory(id: 'windows', name: 'Music', token: 'folder'),
    );
    expect((await index.sources()).single.id, 'windows');
  });

  test(
    'reopening preserves records and recovers interrupted scan state',
    () async {
      final dir = await Directory.systemTemp.createTemp('musaic-index-');
      final path = '${dir.path}/index.sqlite';
      var index = await MusicIndex.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      await index.saveSource(
        const AudioDirectory(id: 'root', name: 'Music', token: 'bookmark'),
      );
      await index.writePage('root', 'first', [
        {
          'id': 'song',
          'entry': jsonEncode({
            'id': 'song',
            'uri': 'file:///song.wav',
            'name': 'song.wav',
            'parent': 'root',
            'size': 16,
            'modified': 1,
          }),
          'metadata': jsonEncode({'title': 'Saved song'}),
          'parent': 'root',
          'cover': 0,
          'verified': 1,
          'error': null,
        },
      ]);
      expect(await index.nextGeneration(), '1');
      await index.status('root', 'scanning');
      await index.setSelected(true);
      await index.close();
      index = await MusicIndex.open(factory: databaseFactoryFfi, path: path);
      expect((await index.sources()).single.token, 'bookmark');
      expect(await index.nextGeneration(), '2');
      expect((await index.sourceStates()).single['status'], 'interrupted');
      expect(await index.isSelected(), true);
      expect((await index.tracks()).single.title, 'Saved song');
      expect(await index.database.getVersion(), 1);
      await index.close();
      await dir.delete(recursive: true);
    },
  );
}
