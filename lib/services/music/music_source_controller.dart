// 文件职责：音乐源、媒体库、播放及切换流程。

import 'dart:async';

import 'directory_music_library.dart';

import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'local_music_provider.dart';
import 'music_provider.dart';

/// 封装或定义音乐来源问题相关类型与行为，负责音乐源、媒体库、播放及切换流程。
enum MusicSourceProblem { denied, restricted, unavailable, scanFailed }

/// 封装或定义音乐来源控制器相关类型与行为，负责音乐源、媒体库、播放及切换流程。
final class MusicSourceController {
  MusicSourceController({MusicProvider Function()? createLocal})
    : _createLocal = createLocal ?? LocalMusicProvider.new;

  final MusicProvider Function() _createLocal;
  final catalog = signal<List<ProviderAlbum>?>(null);
  final mock2Selected = signal(false);
  final busy = signal(false);
  final problem = signal<MusicSourceProblem?>(null);
  MusicProvider? _provider;
  /// 获取当前选中的音乐源提供器。
  MusicProvider? get provider => _provider;
  bool _disposed = false;
  bool _selectionTouched = false;
  final directoryLibrary = signal<DirectoryMusicLibrary?>(null);
  /// 获取当前本地音乐目录媒体库。
  DirectoryMusicLibrary? get directories => directoryLibrary.value;
  final directorySelected = signal(false);
  /// 用于取消本地媒体库曲目变化订阅的回调。
  void Function()? _stopDirectories;

  /// 连接本地音乐媒体库，并订阅曲目变化以同步专辑目录。
  Future<void> attachDirectories(DirectoryMusicLibrary library) async {
    if (_disposed) return;
    directoryLibrary.value = library;
    _stopDirectories = library.tracks.subscribe((_) {
      if (!_disposed && directorySelected.value) _publishDirectories();
    });
    if (await library.index.isSelected() && !_disposed && !_selectionTouched) {
      await library.loadCached();
      if (_disposed || _selectionTouched) return;
      directorySelected.value = true;
      _publishDirectories();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && directorySelected.value) {
          unawaited(library.refresh());
        }
      });
    }
  }

  void _publishDirectories() {
    catalog.value = directories!.albums.value;
  }

  /// 应用选择并更新对应状态，用于音乐源、媒体库、播放及切换流程。
  Future<void> selectDirectories({bool add = false}) async {
    final library = directories;
    if (library == null || _disposed || busy.value) return;
    _selectionTouched = true;
    busy.value = true;
    try {
      if (add && !await library.addDirectory()) return;
      await library.loadCached();
      if (_disposed) return;
      await _provider?.dispose();
      _provider = null;
      if (_disposed) return;
      directorySelected.value = true;
      await library.index.setSelected(true);
      if (_disposed) return;
      mock2Selected.value = false;
      _publishDirectories();
      await library.refresh();
    } catch (_) {
      if (!_disposed) problem.value = MusicSourceProblem.scanFailed;
    } finally {
      if (!_disposed) busy.value = false;
    }
  }

  /// 应用选择并更新对应状态，用于音乐源、媒体库、播放及切换流程。
  Future<void> selectLocal() async {
    if (_disposed || busy.value) return;
    _selectionTouched = true;
    busy.value = true;
    problem.value = null;
    MusicProvider? candidate;
    try {
      candidate = _createLocal();
      await candidate.initialize();
      var access = await candidate.authorizationStatus();
      if (access == MusicAccess.notDetermined || access == MusicAccess.denied) {
        access = await candidate.requestAuthorization();
      }
      if (_disposed) return;
      if (access != MusicAccess.authorized) {
        problem.value = switch (access) {
          MusicAccess.restricted => MusicSourceProblem.restricted,
          MusicAccess.unavailable => MusicSourceProblem.unavailable,
          _ => MusicSourceProblem.denied,
        };
        return;
      }
      final albums = <ProviderAlbum>[];
      final cursors = <String>{};
      String? cursor;
      do {
        final page = await candidate.libraryAlbums(limit: 100, cursor: cursor);
        if (_disposed) return;
        albums.addAll(page.items);
        cursor = page.nextCursor;
        if (cursor != null && !cursors.add(cursor)) {
          throw StateError('Repeated library cursor');
        }
      } while (cursor != null);
      await _provider?.dispose();
      if (_disposed) return;
      directorySelected.value = false;
      await directories?.index.setSelected(false);
      if (_disposed) return;
      mock2Selected.value = false;
      _provider = candidate;
      candidate = null;
      catalog.value = List<ProviderAlbum>.unmodifiable(albums);
    } catch (_) {
      if (!_disposed) problem.value = MusicSourceProblem.scanFailed;
    } finally {
      try {
        await candidate?.dispose();
      } catch (_) {
        /* Preserve the original scan result. */
      }
      if (!_disposed) busy.value = false;
    }
  }

  /// 应用选择并更新对应状态，用于音乐源、媒体库、播放及切换流程。
  Future<void> selectMock() => _selectMock(mock2: false);

  /// 应用选择并更新对应状态，用于音乐源、媒体库、播放及切换流程。
  Future<void> selectMock2() => _selectMock(mock2: true);

  /// 应用选择并更新对应状态，用于音乐源、媒体库、播放及切换流程。
  Future<void> _selectMock({required bool mock2}) async {
    if (_disposed || busy.value) return;
    _selectionTouched = true;
    busy.value = true;
    try {
      await _provider?.dispose();
      _provider = null;
      if (_disposed) return;
      directorySelected.value = false;
      await directories?.index.setSelected(false);
      if (_disposed) return;
      mock2Selected.value = mock2;
      catalog.value = null;
      problem.value = null;
    } catch (_) {
      if (!_disposed) problem.value = MusicSourceProblem.scanFailed;
    } finally {
      if (!_disposed) busy.value = false;
    }
  }

  /// 释放控制器、订阅、动画及其他持有资源，用于音乐源、媒体库、播放及切换流程。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopDirectories?.call();
    directories?.cancel();
    directorySelected.dispose();
    directoryLibrary.dispose();
    try {
      await _provider?.dispose();
    } finally {
      catalog.dispose();
      mock2Selected.dispose();
      busy.dispose();
      problem.dispose();
    }
  }
}
