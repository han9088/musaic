// 文件职责：音乐源、媒体库、播放及切换流程。

import 'dart:convert';

import 'package:musaic_query/musaic_query.dart';

/// 封装或定义indexedaudio相关类型与行为，负责音乐源、媒体库、播放及切换流程。
final class IndexedAudio {
  IndexedAudio(this.source, this.file, this.metadata);
  final AudioDirectory source;
  final AudioFileEntry file;
  final Map<String, Object?> metadata;
  /// 执行当前模块中的title操作，用于音乐源、媒体库、播放及切换流程。
  String get title => metadata['title'] as String? ?? file.name;
}

/// 封装或定义音乐索引rows相关类型与行为，负责音乐源、媒体库、播放及切换流程。
final class MusicIndexRows {
  MusicIndexRows(this.sources, this.files, this.memberships);
  final List<Map<String, Object?>> sources, files, memberships;

  /// 解析输入并转换为内部数据，用于音乐源、媒体库、播放及切换流程。
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

/// 解析输入并转换为内部数据，用于音乐源、媒体库、播放及切换流程。
List<IndexedAudio> decodeTracks(MusicIndexRows rows) => rows.decode().tracks;

/// 封装或定义音乐索引快照相关类型与行为，负责音乐源、媒体库、播放及切换流程。
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

  /// 执行当前模块中的summaries操作，用于音乐源、媒体库、播放及切换流程。
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
