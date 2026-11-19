// 文件职责：音乐源、媒体库、播放及切换流程。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:musaic_query/musaic_query.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../storage/music/music_index.dart';
import 'directory_catalog.dart';
import 'music_provider.dart';

/// 封装或定义本地目录scan状态相关类型与行为，负责音乐源、媒体库、播放及切换流程。
enum DirectoryScanState { idle, loading, scanning, complete, cancelled, failed }

/// 封装或定义scancounts相关类型与行为，负责音乐源、媒体库、播放及切换流程。
final class ScanCounts {
  int added = 0, updated = 0, deleted = 0, skipped = 0, failed = 0;
  /// 执行当前模块中的copy操作，用于音乐源、媒体库、播放及切换流程。
  ScanCounts copy() => ScanCounts()
    ..added = added
    ..updated = updated
    ..deleted = deleted
    ..skipped = skipped
    ..failed = failed;
}

/// 封装或定义本地目录音乐媒体库相关类型与行为，负责音乐源、媒体库、播放及切换流程。
final class DirectoryMusicLibrary {
  DirectoryMusicLibrary({
    required this.index,
    required this.directories,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final MusicIndex index;
  final AudioDirectories directories;
  final DateTime Function() _now;
  final albums = signal<List<ProviderAlbum>>(const []);
  final tracks = signal<List<IndexedAudio>>(const []);
  final sources = signal<List<AudioDirectory>>(const []);
  final folders = signal<List<AudioFolderSummary>>(const []);
  final state = signal(DirectoryScanState.idle);
  final counts = signal(ScanCounts());
  final error = signal<Object?>(null);
  Future<void> _work = Future.value();
  Future<void>? _refresh;
  Future<void>? _cacheLoad;
  Future<void>? _closing;
  AudioScanCancellation? _cancellation;
  bool _disposed = false;
  bool _cacheLoaded = false;
  int _artworkRevision = 0;
  Map<String, IndexedAudio> _tracksById = const {};
  /// 执行当前模块中的track操作，用于音乐源、媒体库、播放及切换流程。
  IndexedAudio? track(String id) => _tracksById[id];
  final _artwork = <String, Future<String?>>{};
  final _covers = <String, Future<AudioFileEntry?>>{};

  /// 读取并恢复所需数据或资源，用于音乐源、媒体库、播放及切换流程。
  Future<void> loadCached() {
    if (_disposed || _cacheLoaded) return Future.value();
    if (_refresh != null) return _refresh!;
    return _cacheLoad ??= _exclusive(_loadCached)
        .whenComplete(() => _cacheLoad = null);
  }

  /// 读取并恢复所需数据或资源，用于音乐源、媒体库、播放及切换流程。
  Future<void> _loadCached() async {
    if (_disposed) return;
    state.value = DirectoryScanState.loading;
    final cached = await compute(
      buildDirectoryCatalog,
      await index.readSnapshot(),
      debugLabel: 'directory-catalog',
    );
    if (_disposed) return;
    _invalidateArtwork();
    _cacheLoaded = true;
    _publish(cached);
    state.value = DirectoryScanState.idle;
  }

  // 媒体源变更与扫描任务共用同一队列；单次失败不能影响后续任务执行。
  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _work.then((_) => action());
    _work = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> addDirectory() => _exclusive(() async {
    if (_disposed) return false;
    final source = await directories.pick();
    if (source == null || _disposed) return false;
    await index.saveSource(source);
    final roots = await index.sources();
    if (!_disposed) sources.value = roots;
    return !_disposed;
  });

  /// 执行当前模块中的reauthorize操作，用于音乐源、媒体库、播放及切换流程。
  Future<void> reauthorize(AudioDirectory old) async {
    var changed = false;
    await _exclusive(() async {
      if (_disposed) return;
      final replacement = await directories.pick();
      if (replacement == null || _disposed) return;
      if (replacement.id != old.id) {
        throw ArgumentError('Select the same directory to restore access');
      }
      await index.saveSource(replacement);
      final roots = await index.sources();
      if (!_disposed) sources.value = roots;
      changed = true;
    });
    if (changed) await refresh();
  }

  /// 移除、清理或重置相关状态与资源，用于音乐源、媒体库、播放及切换流程。
  Future<void> remove(AudioDirectory source) {
    cancel();
    return _exclusive(() async {
      if (_disposed) return;
      await index.removeSource(source.id);
      try {
        await directories.release(source);
      } catch (_) {
        /* Already revoked; removing the index must still succeed. */
      }
      await _loadCached();
    });
  }

  /// 更新相关状态并同步依赖方，用于音乐源、媒体库、播放及切换流程。
  Future<void> refresh({bool force = false}) {
    if (_disposed) return Future.value();
    if (_refresh != null) return _refresh!;
    final cancellation = _cancellation = AudioScanCancellation();
    return _refresh = _exclusive(() => _scan(force, cancellation))
        .whenComplete(() {
          _refresh = null;
          _cancellation = null;
        });
  }

  /// 判断当前状态是否满足指定条件，用于音乐源、媒体库、播放及切换流程。
  void cancel() => _cancellation?.cancel();
  Future<void> _scan(bool force, AudioScanCancellation cancellation) async {
    if (_disposed) return;
    final totals = ScanCounts();
    batch(() {
      counts.value = totals.copy();
      state.value = cancellation.isCancelled
          ? DirectoryScanState.cancelled
          : DirectoryScanState.scanning;
      error.value = null;
    });
    if (cancellation.isCancelled) return;
    var failed = false;
    try {
      final generation = await index.nextGeneration();
      if (force) await directories.clearArtworkCache();
      for (final original in await index.sources()) {
        if (cancellation.isCancelled) break;
        var complete = true;
        await index.status(original.id, 'scanning');
        try {
          final source = await directories.restore(original);
          if (source.id != original.id) {
            throw StateError('Directory moved; add the new source explicitly');
          }
          await index.saveSource(source);
          await for (final page in directories.scan(
            source,
            cancellation: cancellation,
          )) {
            if (cancellation.isCancelled) break;
            if (page.error != null) {
              complete = false;
              failed = true;
              totals.failed++;
              if (!_disposed) error.value = page.error;
            }
            if (page.entries.isEmpty) continue;
            final entries = page.entries;
            final previous = await index.lookup(entries);
            final rows = <Map<String, Object?>>[];
            final pageCounts = ScanCounts();
            for (final file in entries) {
              if (cancellation.isCancelled) break;
              final old = previous[file.id];
              final oldFile = old == null
                  ? null
                  : AudioFileEntry(jsonDecode(old['entry'] as String) as Map);
              final cover = file.coverPriority != null;
              final directory = file.isDirectory;
              String? metadata = old?['metadata'] as String?;
              Object? fileError;
              final known =
                  file.modified != null &&
                  file.size != null &&
                  file.data['reliable'] == true;
              final verified = old?['verified'] as int?;
              // 对于无法提供可靠时间戳的媒体源，至少每天重新校验一次。
              final freshUnknown =
                  !known &&
                  verified != null &&
                  _now().millisecondsSinceEpoch >= verified &&
                  _now().millisecondsSinceEpoch - verified <
                      const Duration(days: 1).inMilliseconds;
              final unchanged =
                  oldFile != null &&
                  file.size == oldFile.size &&
                  file.modified == oldFile.modified &&
                  (known || freshUnknown);
              var verification = verified;
              if (!cover &&
                  !directory &&
                  (force ||
                      !unchanged ||
                      metadata == null ||
                      old?['error'] != null)) {
                try {
                  metadata = jsonEncode(
                    await directories.metadata(source, file),
                  );
                  verification = _now().millisecondsSinceEpoch;
                  if (old == null) {
                    pageCounts.added++;
                  } else {
                    pageCounts.updated++;
                  }
                } catch (e) {
                  fileError = e;
                  pageCounts.failed++;
                  failed = true;
                }
              } else if (!cover && !directory) {
                pageCounts.skipped++;
              }
              final row = <String, Object?>{
                'id': file.id,
                'entry': mapEquals(file.data, oldFile?.data)
                    ? old!['entry']
                    : jsonEncode(file.data),
                'metadata': metadata,
                'parent': file.parent,
                'cover': directory
                    ? 2
                    : cover
                    ? 1
                    : 0,
                'verified': verification,
                'error': fileError?.toString(),
              };
              if (old == null || !mapEquals(old, row)) rows.add(row);
            }
            if (cancellation.isCancelled) break;
            await index.writePage(
              source.id,
              generation,
              rows,
              seenIds: entries.map((entry) => entry.id),
            );
            totals.added += pageCounts.added;
            totals.updated += pageCounts.updated;
            totals.failed += pageCounts.failed;
            totals.skipped += pageCounts.skipped;
            if (!_disposed) counts.value = totals.copy();
          }
          if (!cancellation.isCancelled && complete) {
            totals.deleted += await index.finish(source.id, generation);
          } else {
            await index.status(
              source.id,
              cancellation.isCancelled ? 'cancelled' : 'failed',
              error.value,
            );
          }
        } catch (e) {
          failed = true;
          totals.failed++;
          await index.status(original.id, 'failed', e);
          if (!_disposed) error.value = e;
        }
      }
      final current = await compute(
        buildDirectoryCatalog,
        await index.readSnapshot(),
        debugLabel: 'directory-catalog',
      );
      if (!_disposed) {
        _invalidateArtwork();
        _cacheLoaded = true;
        _publish(current);
        counts.value = totals.copy();
        state.value = cancellation.isCancelled
            ? DirectoryScanState.cancelled
            : failed
            ? DirectoryScanState.failed
            : DirectoryScanState.complete;
      }
    } catch (e) {
      if (!_disposed) {
        error.value = e;
        state.value = DirectoryScanState.failed;
      }
    }
  }

  void _publish(DirectoryCatalog catalog) {
    _tracksById = catalog.tracksById;
    batch(() {
      sources.value = catalog.sources;
      folders.value = catalog.folders;
      albums.value = catalog.albums;
      tracks.value = catalog.tracks;
    });
  }

  void _invalidateArtwork() {
    _artworkRevision++;
    _covers.clear();
    _artwork.clear();
  }

  /// 执行当前模块中的专辑封面操作，用于音乐源、媒体库、播放及切换流程。
  Future<String?> artwork(IndexedAudio track, {int size = 512}) async {
    if (_disposed) return null;
    final revision = _artworkRevision;
    final parent = track.file.parent;
    var candidate = _covers[parent];
    if (candidate == null) {
      if (_covers.length >= 256) _covers.remove(_covers.keys.first);
      candidate = index.cover(parent);
      _covers[parent] = candidate;
    }
    AudioFileEntry? cover;
    try {
      cover = await candidate;
    } catch (_) {
      if (identical(_covers[parent], candidate)) _covers.remove(parent);
      rethrow;
    }
    if (_disposed || revision != _artworkRevision) return null;
    final key = jsonEncode([
      track.source.toMap(),
      track.file.data,
      cover?.data,
      size,
    ]);
    var request = _artwork[key];
    if (request == null) {
      if (_artwork.length >= 128) _artwork.remove(_artwork.keys.first);
      request = directories.artwork(
        track.source,
        track.file,
        cover: cover,
        size: size,
      );
      _artwork[key] = request;
    }
    try {
      return await request;
    } catch (_) {
      if (identical(_artwork[key], request)) _artwork.remove(key);
      rethrow;
    }
  }

  /// 移除、清理或重置相关状态与资源，用于音乐源、媒体库、播放及切换流程。
  Future<void> clearArtworkCache() async {
    if (_disposed) return;
    await directories.clearArtworkCache();
    _invalidateArtwork();
    if (!_disposed) tracks.value = List.of(tracks.value);
  }

  /// 执行当前模块中的summaries操作，用于音乐源、媒体库、播放及切换流程。
  Future<List<AudioFolderSummary>> summaries({
    bool recursive = false,
    AudioFilter filter = const AudioFilter(),
  }) {
    if (_disposed) return Future.error(StateError('Music library disposed'));
    return _exclusive(
      () => index.summaries(recursive: recursive, filter: filter),
    );
  }

  /// 释放控制器、订阅、动画及其他持有资源，用于音乐源、媒体库、播放及切换流程。
  Future<void> dispose() => _closing ??= _dispose();

  /// 释放控制器、订阅、动画及其他持有资源，用于音乐源、媒体库、播放及切换流程。
  Future<void> _dispose() async {
    _disposed = true;
    cancel();
    _invalidateArtwork();
    try {
      await _work;
    } finally {
      _tracksById = const {};
      albums.dispose();
      tracks.dispose();
      sources.dispose();
      folders.dispose();
      state.dispose();
      counts.dispose();
      error.dispose();
      await index.close();
    }
  }
}
