// 文件职责：音乐源、媒体库、播放及切换流程。

import 'dart:async';

import 'package:audius_sdk/audius_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../config/env.dart';
import '../../storage/music/music_index.dart';
import '../diagnostics/diagnostic_log.dart';
import 'audius_account.dart';
import 'audius_music_provider.dart';
import 'directory_music_library.dart';
import 'local_music_provider.dart';
import 'music_provider.dart';

/// 封装或定义音乐来源问题相关类型与行为，负责音乐源、媒体库、播放及切换流程。
enum MusicSourceProblem {
  denied,
  restricted,
  unavailable,
  scanFailed,
  audiusUnavailable,
  audiusRateLimited,
  audiusEmpty,
}

enum MusicSourceStartup {
  checkingSavedSelection,
  loadingAudius,
  loadingLocal,
  ready,
}

/// 封装或定义音乐来源控制器相关类型与行为，负责音乐源、媒体库、播放及切换流程。
final class MusicSourceController {
  MusicSourceController({
    this._createLocal,
    MusicProvider Function()? createAudius,
    this.systemLibraryEnabled = true,
    this.audiusAccount,
    bool restoreOnStartup = false,
  }) : _createAudius = createAudius ?? _defaultAudius,
       startup = signal(
         restoreOnStartup
             ? MusicSourceStartup.checkingSavedSelection
             : MusicSourceStartup.ready,
       ) {
    audiusAccount?.addListener(_accountChanged);
  }

  static MusicProvider _defaultAudius() =>
      AudiusMusicProvider(sdk: AudiusSdk(apiKey: Env.audiusApiKey));

  final MusicProvider Function()? _createLocal;
  final MusicProvider Function() _createAudius;
  final bool systemLibraryEnabled;
  final AudiusAccount? audiusAccount;
  final Signal<MusicSourceStartup> startup;
  final catalog = signal<List<ProviderAlbum>?>(null);
  final mock2Selected = signal(false);
  final busy = signal(false);
  final audiusLoading = signal(false);
  final problem = signal<MusicSourceProblem?>(null);
  MusicProvider? _provider;
  MusicProvider? _pendingAudius;
  List<ProviderAlbum>? _audiusTrending;

  /// 获取当前选中的音乐源提供器。
  MusicProvider? get provider => _provider;
  bool get audiusSelected => _provider?.id == AudiusMusicProvider.providerId;

  // The catalog signal tracks provider selection for the settings tabs.
  String? get selectedProviderId =>
      catalog.value == null ? null : _provider?.id;
  bool get showingAudiusFavorites =>
      audiusSelected && !identical(catalog.value, _audiusTrending);

  void _accountChanged() {
    if (audiusAccount?.user == null) showAudiusTrending();
  }

  void showAudiusTrending() {
    if (!_disposed && showingAudiusFavorites) catalog.value = _audiusTrending;
  }

  Future<void> showAudiusFavorites() async {
    final provider = _provider;
    final userId = audiusAccount?.user?.id;
    if (provider is! AudiusMusicProvider || userId == null || _disposed) return;
    final albums = <String, ProviderAlbum>{};
    String? cursor;
    do {
      final previousCount = albums.length;
      final page = await provider.favoriteAlbums(userId, cursor: cursor);
      if (_disposed ||
          !identical(provider, _provider) ||
          audiusAccount?.user?.id != userId) {
        return;
      }
      for (final album in page.items) {
        albums[album.reference.id] = album;
      }
      cursor = page.nextCursor;
      if (cursor != null && albums.length == previousCount) break;
    } while (cursor != null);
    catalog.value = List.unmodifiable(albums.values);
  }

  bool _disposed = false;
  bool _selectionTouched = false;
  final directoryLibrary = signal<DirectoryMusicLibrary?>(null);

  /// 获取当前本地音乐目录媒体库。
  DirectoryMusicLibrary? get directories => directoryLibrary.value;
  final localSelected = signal(false);
  List<ProviderAlbum> _systemAlbums = const [];
  int _localCatalogRevision = 0;

  /// 用于取消本地媒体库曲目变化订阅的回调。
  void Function()? _stopDirectories;

  /// 连接本地音乐媒体库，并订阅曲目变化以同步专辑目录。
  Future<void> attachDirectories(DirectoryMusicLibrary library) async {
    if (_disposed) return;
    directoryLibrary.value = library;
    _stopDirectories = library.tracks.subscribe((_) {
      if (!_disposed && localSelected.value && !busy.value) {
        unawaited(_publishLocalCatalog());
      }
    });
    final source = await library.index.selectedSource();
    if (_disposed) return;
    if (_selectionTouched) {
      if (localSelected.value) await _publishLocalCatalog();
      return;
    }
    if (source == MusicIndexSource.audius) {
      startup.value = MusicSourceStartup.loadingAudius;
      await selectAudius(restoreSavedSelection: true);
      return;
    }
    if (source == MusicIndexSource.demo2) {
      batch(() {
        mock2Selected.value = true;
        startup.value = MusicSourceStartup.ready;
      });
      return;
    }
    if (systemLibraryEnabled &&
        (source == MusicIndexSource.systemLibrary ||
            source == MusicIndexSource.systemAndDirectories)) {
      startup.value = MusicSourceStartup.loadingLocal;
      await _scanSystemLibrary(restoring: true);
      if (source == MusicIndexSource.systemAndDirectories) {
        _refreshRestoredDirectories(library);
      }
      return;
    }
    if (source == MusicIndexSource.directories) {
      await library.loadCached();
      if (_disposed || _selectionTouched) return;
      batch(() {
        _provider = LocalMusicProvider.folderOnly(library);
        localSelected.value = true;
        catalog.value = library.albums.value;
        startup.value = MusicSourceStartup.ready;
      });
      _refreshRestoredDirectories(library);
    }
  }

  void _refreshRestoredDirectories(DirectoryMusicLibrary library) {
    final provider = _provider;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed &&
          identical(_provider, provider) &&
          localSelected.value &&
          !busy.value) {
        unawaited(library.refresh());
      }
    });
  }

  void finishStartupCheck() {
    if (!_disposed &&
        startup.value == MusicSourceStartup.checkingSavedSelection) {
      startup.value = MusicSourceStartup.ready;
    }
  }

  Future<List<ProviderAlbum>> _combinedLocalCatalog(
    List<ProviderAlbum> systemAlbums,
    MusicProvider? provider,
  ) async =>
      await directories?.combineWithSystemAlbums(
        systemAlbums,
        provider is LocalMusicProvider ? provider.filePath : null,
      ) ??
      systemAlbums;

  Future<void> _publishLocalCatalog() async {
    final revision = ++_localCatalogRevision;
    final albums = await _combinedLocalCatalog(_systemAlbums, _provider);
    if (!_disposed &&
        revision == _localCatalogRevision &&
        localSelected.value) {
      batch(() {
        catalog.value = albums;
        startup.value = MusicSourceStartup.ready;
      });
    }
  }

  /// 应用选择并更新对应状态，用于音乐源、媒体库、播放及切换流程。
  Future<void> selectDirectories({
    bool add = false,
    bool refresh = false,
  }) async {
    final library = directories;
    final updating = add || refresh;
    if (library == null ||
        _disposed ||
        busy.value ||
        (updating && !localSelected.value)) {
      return;
    }
    _selectionTouched = true;
    busy.value = true;
    problem.value = null;
    var operation = DiagnosticOperation.addDirectory;
    try {
      final added = add ? await library.addDirectory() : null;
      if (add && added == null) return;
      if (!updating) {
        operation = DiagnosticOperation.loadDirectoryCache;
        await library.loadCached();
      }
      if (_disposed) return;
      operation = DiagnosticOperation.saveDirectorySelection;
      final provider = _provider;
      final hasFolders = library.sources.value.isNotEmpty;
      if (updating &&
          provider != null &&
          (provider is! LocalMusicProvider || provider.systemLibraryEnabled)) {
        await library.index.setSystemLibrarySelected(
          includesDirectories: hasFolders,
        );
      } else {
        await library.index.setSelected(hasFolders);
      }
      if (_disposed) return;
      if (updating) {
        operation = DiagnosticOperation.scanDirectory;
        await library.refresh(source: added);
        operation = DiagnosticOperation.publishDirectoryCatalog;
        if (!_disposed) await _publishLocalCatalog();
        return;
      }
      final old = _provider;
      _provider = LocalMusicProvider.folderOnly(library);
      batch(() {
        localSelected.value = true;
        mock2Selected.value = false;
      });
      operation = DiagnosticOperation.publishDirectoryCatalog;
      await _publishLocalCatalog();
      await _disposeProvider(old);
      diagnosticLog.record(DiagnosticEvent.directorySourceSelected);
    } catch (error, stack) {
      diagnosticLog.record(
        DiagnosticEvent.directorySourceFailed,
        operation: operation,
        error: error,
        stack: stack,
      );
      if (!_disposed) problem.value = MusicSourceProblem.scanFailed;
    } finally {
      if (!_disposed) busy.value = false;
    }
  }

  /// 应用选择并更新对应状态，用于音乐源、媒体库、播放及切换流程。
  Future<void> selectLocal() async {
    if (systemLibraryEnabled) await _scanSystemLibrary();
    if (!_disposed && !localSelected.value && directories != null) {
      await selectDirectories();
    }
  }

  Future<void> rescanLocal() async {
    if (_disposed || busy.value || !localSelected.value) return;
    final library = directories;
    if (library != null && library.sources.value.isNotEmpty) {
      await selectDirectories(refresh: true);
      final provider = _provider;
      if (provider == null ||
          (provider is LocalMusicProvider && !provider.systemLibraryEnabled) ||
          library.state.value == DirectoryScanState.cancelled) {
        return;
      }
    }
    if (systemLibraryEnabled && localSelected.value) await _scanSystemLibrary();
  }

  Future<void> _scanSystemLibrary({bool restoring = false}) async {
    if (_disposed || busy.value) return;
    _selectionTouched = true;
    busy.value = true;
    problem.value = null;
    diagnosticLog.record(DiagnosticEvent.localLibrarySelected);
    MusicProvider? candidate;
    try {
      candidate =
          _createLocal?.call() ?? LocalMusicProvider(directories: directories);
      await candidate.initialize();
      var access = await candidate.authorizationStatus();
      if (!restoring &&
          (access == MusicAccess.notDetermined ||
              access == MusicAccess.denied)) {
        access = await candidate.requestAuthorization();
      }
      if (_disposed) return;
      if (access != MusicAccess.authorized) {
        final (issue, event) = switch (access) {
          MusicAccess.restricted => (
            MusicSourceProblem.restricted,
            DiagnosticEvent.localAccessRestricted,
          ),
          MusicAccess.unavailable => (
            MusicSourceProblem.unavailable,
            DiagnosticEvent.localAccessUnavailable,
          ),
          _ => (MusicSourceProblem.denied, DiagnosticEvent.localAccessDenied),
        };
        diagnosticLog.record(event);
        problem.value = issue;
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
      final systemAlbums = List<ProviderAlbum>.unmodifiable(albums);
      await directories?.loadCached();
      if (_disposed) return;
      final combined = await _combinedLocalCatalog(systemAlbums, candidate);
      if (_disposed) return;
      final index = directories?.index;
      if (!restoring && index != null) {
        final keepFolderRefresh =
            localSelected.value && await index.isSelected();
        if (_disposed) return;
        await index.setSystemLibrarySelected(
          includesDirectories: keepFolderRefresh,
        );
      }
      if (_disposed) return;
      final old = _provider;
      final next = candidate;
      candidate = null;
      ++_localCatalogRevision;
      _systemAlbums = systemAlbums;
      batch(() {
        _provider = next;
        localSelected.value = true;
        mock2Selected.value = false;
        catalog.value = combined;
        startup.value = MusicSourceStartup.ready;
      });
      if (!identical(old, next)) await _disposeProvider(old);
      diagnosticLog.record(
        DiagnosticEvent.localLibraryLoaded,
        count: albums.length,
      );
    } catch (error, stack) {
      diagnosticLog.record(
        DiagnosticEvent.localLibraryFailed,
        error: error,
        stack: stack,
      );
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

  /// Load a bounded page before dismissing the picker and switching the canvas.
  Future<void> selectAudius({
    Future<void> Function(List<ProviderAlbum>)? prepareArtwork,
    Future<void> Function(Future<void> Function())? transition,
    bool restoreSavedSelection = false,
  }) async {
    if (_disposed || busy.value || audiusSelected) return;
    busy.value = true;
    audiusLoading.value = true;
    problem.value = null;
    try {
      final next = _pendingAudius = _createAudius();
      await next.initialize();
      if (_disposed) return;
      final index = directories?.index;
      if (restoreSavedSelection && index != null) {
        final cached = await _readAudiusCache(index);
        if (_disposed) return;
        if (cached.isNotEmpty) {
          final old = _activateAudius(next, cached);
          unawaited(_refreshRestoredAudius(next, index));
          await _disposeProvider(old);
          return;
        }
      }
      final trending = await _fetchAudiusTrending(next);
      if (_disposed) return;
      if (trending.isEmpty) {
        problem.value = MusicSourceProblem.audiusEmpty;
        return;
      }
      if (prepareArtwork != null) {
        await prepareArtwork(trending);
        if (_disposed) return;
      }

      Future<void> activate() async {
        if (_disposed || _pendingAudius != next) return;
        // Keep the current provider and its catalog until the candidate is ready.
        _selectionTouched = true;
        if (index != null) {
          await _saveAudiusCache(index, trending);
          if (_disposed) return;
          await index.setAudiusSelected();
        }
        if (_disposed) return;
        await _disposeProvider(_activateAudius(next, trending));
      }

      if (transition == null) {
        await activate();
      } else {
        await transition(activate);
      }
    } catch (error) {
      diagnosticLog.record(
        DiagnosticEvent.musicSourceSwitchFailed,
        error: error,
      );
      if (!_disposed) {
        problem.value = error is AudiusApiException && error.statusCode == 429
            ? MusicSourceProblem.audiusRateLimited
            : MusicSourceProblem.audiusUnavailable;
      }
    } finally {
      final candidate = _pendingAudius;
      _pendingAudius = null;
      await _disposeProvider(candidate);
      if (!_disposed) {
        audiusLoading.value = false;
        busy.value = false;
      }
    }
  }

  MusicProvider? _activateAudius(
    MusicProvider next,
    List<ProviderAlbum> albums,
  ) {
    final old = _provider;
    _selectionTouched = true;
    batch(() {
      _provider = next;
      _pendingAudius = null;
      localSelected.value = false;
      _systemAlbums = const [];
      mock2Selected.value = false;
      _audiusTrending = albums;
      catalog.value = albums;
      startup.value = MusicSourceStartup.ready;
    });
    return old;
  }

  Future<List<ProviderAlbum>> _fetchAudiusTrending(
    MusicProvider provider,
  ) async {
    const limit = MusicIndex.audiusCatalogLimit;
    final albums = <String, ProviderAlbum>{};
    String? cursor;
    // Some servers return mixed playlist types even with the album filter.
    for (var page = 0; page < 2 && albums.length < limit; page++) {
      final result = await provider.libraryAlbums(limit: limit, cursor: cursor);
      if (_disposed || (_provider != provider && _pendingAudius != provider)) {
        return const [];
      }
      for (final album in result.items) {
        albums[album.reference.id] = album;
      }
      if (result.nextCursor == null || result.nextCursor == cursor) break;
      cursor = result.nextCursor;
    }
    return List.unmodifiable(albums.values.take(limit));
  }

  Future<void> _refreshRestoredAudius(
    MusicProvider provider,
    MusicIndex index,
  ) async {
    try {
      final fresh = await _fetchAudiusTrending(provider);
      if (_disposed || _provider != provider || fresh.isEmpty) return;
      if (listEquals(_audiusTrending, fresh)) return;
      final showingTrending = !showingAudiusFavorites;
      _audiusTrending = fresh;
      if (showingTrending) catalog.value = fresh;
      await _saveAudiusCache(index, fresh);
    } catch (error) {
      if (_disposed || _provider != provider) return;
      diagnosticLog.record(DiagnosticEvent.musicRestoreFailed, error: error);
    }
  }

  Future<List<ProviderAlbum>> _readAudiusCache(MusicIndex index) async {
    try {
      return await index.readAudiusCatalog();
    } catch (error) {
      diagnosticLog.record(DiagnosticEvent.musicRestoreFailed, error: error);
      return const [];
    }
  }

  Future<void> _saveAudiusCache(
    MusicIndex index,
    List<ProviderAlbum> albums,
  ) async {
    try {
      await index.saveAudiusCatalog(albums);
    } catch (error) {
      diagnosticLog.record(DiagnosticEvent.musicRestoreFailed, error: error);
    }
  }

  Future<void> _disposeProvider(MusicProvider? provider) async {
    try {
      await provider?.dispose();
    } catch (error, stack) {
      diagnosticLog.record(
        DiagnosticEvent.musicSourceSwitchFailed,
        operation: DiagnosticOperation.disposePreviousSource,
        error: error,
        stack: stack,
      );
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
      localSelected.value = false;
      _systemAlbums = const [];
      final index = directories?.index;
      if (mock2) {
        await index?.setDemo2Selected();
      } else {
        await index?.setSelected(false);
      }
      if (_disposed) return;
      mock2Selected.value = mock2;
      catalog.value = null;
      problem.value = null;
      startup.value = MusicSourceStartup.ready;
      diagnosticLog.record(
        mock2
            ? DiagnosticEvent.secondDemoSourceSelected
            : DiagnosticEvent.demoSourceSelected,
      );
    } catch (error) {
      diagnosticLog.record(
        DiagnosticEvent.musicSourceSwitchFailed,
        error: error,
      );
      if (!_disposed) problem.value = MusicSourceProblem.scanFailed;
    } finally {
      if (!_disposed) busy.value = false;
    }
  }

  /// 释放控制器、订阅、动画及其他持有资源，用于音乐源、媒体库、播放及切换流程。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    audiusAccount?.removeListener(_accountChanged);
    _stopDirectories?.call();
    directories?.cancel();
    localSelected.dispose();
    directoryLibrary.dispose();
    final candidate = _pendingAudius;
    _pendingAudius = null;
    try {
      await _disposeProvider(candidate);
      await _provider?.dispose();
    } finally {
      catalog.dispose();
      mock2Selected.dispose();
      busy.dispose();
      audiusLoading.dispose();
      problem.dispose();
      startup.dispose();
    }
  }
}
