import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:musaic_query/musaic_query.dart';
import 'package:sqflite/sqflite.dart';

/// App-owned catalog. Grants and file locations never leave this database.
final class MusicIndex {
  MusicIndex(this.database);
  final Database database;

  static Future<MusicIndex> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final location =
        path ?? '${await dbFactory.getDatabasesPath()}/music_index.sqlite';
    final db = await dbFactory.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE sources (id TEXT PRIMARY KEY, name TEXT NOT NULL, token TEXT NOT NULL, status TEXT NOT NULL DEFAULT \'idle\', error TEXT)',
          );
          await db.execute(
            'CREATE TABLE files (id TEXT PRIMARY KEY, entry TEXT NOT NULL, metadata TEXT, parent TEXT NOT NULL, cover INTEGER NOT NULL, verified INTEGER, error TEXT)',
          );
          await db.execute('CREATE INDEX files_parent ON files(parent, cover)');
          await db.execute(
            'CREATE TABLE memberships (source TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE, file TEXT NOT NULL REFERENCES files(id) ON DELETE CASCADE, generation TEXT NOT NULL, PRIMARY KEY(source, file))',
          );
          await db.execute(
            'CREATE INDEX memberships_file ON memberships(file)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
        onOpen: (db) => db.update(
          'sources',
          {'status': 'interrupted'},
          where: 'status = ?',
          whereArgs: ['scanning'],
        ),
      ),
    );
    return MusicIndex(db);
  }

  Future<void> saveSource(AudioDirectory source) async {
    await database.rawInsert(
      'INSERT INTO sources(id,name,token) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,token=excluded.token',
      [source.id, source.name, source.token],
    );
  }

  Future<List<AudioDirectory>> sources() async => [
    for (final row in await database.query('sources'))
      AudioDirectory.fromMap(row),
  ];
  Future<String> nextGeneration() => database.transaction((txn) async {
    final rows = await txn.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['scanGeneration'],
    );
    final previous = rows.isEmpty
        ? 0
        : int.parse(rows.single['value'] as String);
    final generation = '${previous + 1}';
    await txn.insert('settings', {
      'key': 'scanGeneration',
      'value': generation,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return generation;
  });

  Future<void> status(String id, String state, [Object? error]) async {
    await database.update(
      'sources',
      {'status': state, 'error': error?.toString()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> sourceStates() =>
      database.query('sources');
  Future<Map<String, Map<String, Object?>>> lookup(
    List<AudioFileEntry> entries,
  ) async {
    if (entries.isEmpty) return {};
    final rows = await database.query(
      'files',
      where: 'id IN (${List.filled(entries.length, '?').join(',')})',
      whereArgs: [for (final e in entries) e.id],
    );
    return {for (final row in rows) row['id'] as String: row};
  }

  Future<void> writePage(
    String source,
    String generation,
    List<Map<String, Object?>> rows, {
    Iterable<String>? seenIds,
  }) async {
    final batch = database.batch();
    for (final row in rows) {
      batch.rawInsert(
        'INSERT INTO files(id,entry,metadata,parent,cover,verified,error) VALUES(?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET entry=excluded.entry,metadata=excluded.metadata,parent=excluded.parent,cover=excluded.cover,verified=excluded.verified,error=excluded.error',
        [
          row['id'],
          row['entry'],
          row['metadata'],
          row['parent'],
          row['cover'],
          row['verified'],
          row['error'],
        ],
      );
    }
    for (final id in seenIds ?? rows.map((row) => row['id'] as String)) {
      batch.rawInsert(
        'INSERT INTO memberships(source,file,generation) VALUES(?,?,?) ON CONFLICT(source,file) DO UPDATE SET generation=excluded.generation',
        [source, id, generation],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> finish(String source, String generation) =>
      database.transaction((txn) async {
        await txn.delete(
          'memberships',
          where: 'source = ? AND generation != ?',
          whereArgs: [source, generation],
        );
        final removed =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM files WHERE cover=0 AND NOT EXISTS (SELECT 1 FROM memberships WHERE memberships.file=files.id)',
              ),
            ) ??
            0;
        await txn.execute(
          'DELETE FROM files WHERE NOT EXISTS (SELECT 1 FROM memberships WHERE memberships.file = files.id)',
        );
        await txn.update(
          'sources',
          {'status': 'complete', 'error': null},
          where: 'id = ?',
          whereArgs: [source],
        );
        return removed;
      });
  Future<void> removeSource(String id) => database.transaction((txn) async {
    await txn.delete('sources', where: 'id = ?', whereArgs: [id]);
    await txn.execute(
      'DELETE FROM files WHERE NOT EXISTS (SELECT 1 FROM memberships WHERE memberships.file = files.id)',
    );
  });

  /// One consistent read, independent of the number of directory sources.
  Future<MusicIndexRows> readSnapshot() => database.transaction(
    (txn) async => MusicIndexRows(
      await txn.query('sources', orderBy: 'id'),
      await txn.query('files', orderBy: 'id'),
      await txn.query('memberships'),
    ),
  );

  Future<List<IndexedAudio>> tracks() async =>
      await compute(_decodeTracks, await readSnapshot());

  Future<AudioFileEntry?> cover(String parent) async {
    final entries = [
      for (final row in await database.query(
        'files',
        where: 'parent = ? AND cover = 1',
        whereArgs: [parent],
      ))
        AudioFileEntry(jsonDecode(row['entry'] as String) as Map),
    ];
    entries.sort((a, b) {
      final rank = a.coverPriority!.compareTo(b.coverPriority!);
      return rank != 0 ? rank : a.id.compareTo(b.id);
    });
    return entries.firstOrNull;
  }

  Future<void> setSelected(bool selected) async {
    await database.insert('settings', {
      'key': 'directoriesSelected',
      'value': selected ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> isSelected() async =>
      (await database.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['directoriesSelected'],
      )).firstOrNull?['value'] ==
      '1';
  Future<List<AudioFolderSummary>> summaries({
    bool recursive = false,
    AudioFilter filter = const AudioFilter(),
  }) async {
    final rows = await readSnapshot();
    return compute(
      (MusicIndexRows rows) =>
          rows.decode().summaries(recursive: recursive, filter: filter),
      rows,
    );
  }

  Future<void> close() => database.close();
}

final class IndexedAudio {
  IndexedAudio(this.source, this.file, this.metadata);
  final AudioDirectory source;
  final AudioFileEntry file;
  final Map<String, Object?> metadata;
  String get title => metadata['title'] as String? ?? file.name;
}

/// Only plain database values cross the worker boundary, never a connection.
final class MusicIndexRows {
  MusicIndexRows(this.sources, this.files, this.memberships);
  final List<Map<String, Object?>> sources, files, memberships;

  MusicIndexSnapshot decode() {
    final roots = {
      for (final row in sources)
        row['id'] as String: AudioDirectory.fromMap(row),
    };
    final complete = {
      for (final row in sources)
        if (row['status'] == 'complete') row['id'] as String,
    };
    final entries = <String, AudioFileEntry>{};
    final metadata = <String, Map<String, Object?>>{};
    for (final row in files) {
      final id = row['id'] as String;
      entries[id] = AudioFileEntry(jsonDecode(row['entry'] as String) as Map);
      if (row['metadata'] != null) {
        metadata[id] = Map<String, Object?>.from(
          jsonDecode(row['metadata'] as String) as Map,
        );
      }
    }
    final preferred = <String, String>{};
    final members = <String, List<String>>{};
    for (final row in memberships) {
      final source = row['source'] as String;
      final file = row['file'] as String;
      members.putIfAbsent(source, () => []).add(file);
      final old = preferred[file];
      if (old == null ||
          (complete.contains(source) && !complete.contains(old)) ||
          (complete.contains(source) == complete.contains(old) &&
              source.compareTo(old) < 0)) {
        preferred[file] = source;
      }
    }
    return MusicIndexSnapshot(roots, complete, entries, metadata, members, [
      for (final row in files)
        if (row['cover'] == 0 &&
            metadata.containsKey(row['id']) &&
            preferred.containsKey(row['id']))
          IndexedAudio(
            roots[preferred[row['id']]]!,
            entries[row['id']]!,
            metadata[row['id']]!,
          ),
    ]);
  }
}

List<IndexedAudio> _decodeTracks(MusicIndexRows rows) => rows.decode().tracks;

final class MusicIndexSnapshot {
  MusicIndexSnapshot(
    this.sources,
    this.complete,
    this.entries,
    this.metadata,
    this.members,
    this.tracks,
  );
  final Map<String, AudioDirectory> sources;
  final Set<String> complete;
  final Map<String, AudioFileEntry> entries;
  final Map<String, Map<String, Object?>> metadata;
  final Map<String, List<String>> members;
  final List<IndexedAudio> tracks;

  List<AudioFolderSummary> summaries({
    bool recursive = false,
    AudioFilter filter = const AudioFilter(),
  }) {
    filter.validate();
    final result = <AudioFolderSummary>[];
    for (final root in sources.values) {
      final accumulator = AudioFolderSummaries(root);
      final grouped = <String, List<AudioFileEntry>>{root.id: []};
      for (final id in members[root.id] ?? const <String>[]) {
        final entry = entries[id]!;
        if (!entry.isDirectory &&
            entry.isAudio &&
            !filter.matches(
              extension: entry.extension,
              size: entry.size,
              durationMs: metadata[id]?['durationMs'] as int?,
            )) {
          continue;
        }
        grouped.putIfAbsent(entry.parent, () => []).add(entry);
        if (entry.isDirectory) grouped.putIfAbsent(entry.id, () => []);
      }
      for (final group in grouped.entries) {
        accumulator.add(
          AudioDirectoryPage(
            group.key,
            group.value,
            directoryComplete: complete.contains(root.id),
          ),
        );
      }
      result.addAll(accumulator.snapshot(recursive: recursive));
    }
    return result;
  }
}
