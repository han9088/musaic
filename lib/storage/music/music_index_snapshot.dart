import 'dart:convert';

import 'package:musaic_query/musaic_query.dart';

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

List<IndexedAudio> decodeTracks(MusicIndexRows rows) => rows.decode().tracks;

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
