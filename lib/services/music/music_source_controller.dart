import 'dart:async';

import 'directory_music_library.dart';

import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'local_music_provider.dart';
import 'music_provider.dart';

enum MusicSourceProblem { denied, restricted, unavailable, scanFailed }

/// Null catalog means mock. A source change is committed only after a full scan.
final class MusicSourceController {
  MusicSourceController({MusicProvider Function()? createLocal})
    : _createLocal = createLocal ?? LocalMusicProvider.new;

  final MusicProvider Function() _createLocal;
  final catalog = signal<List<ProviderAlbum>?>(null);
  final busy = signal(false);
  final problem = signal<MusicSourceProblem?>(null);
  MusicProvider? _provider;
  MusicProvider? get provider => _provider;
  bool _disposed = false;
  bool _selectionTouched = false;
  final directoryLibrary = signal<DirectoryMusicLibrary?>(null);
  DirectoryMusicLibrary? get directories => directoryLibrary.value;
  final directorySelected = signal(false);
  void Function()? _stopDirectories;

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
      _publishDirectories();
      await library.refresh();
    } catch (_) {
      if (!_disposed) problem.value = MusicSourceProblem.scanFailed;
    } finally {
      if (!_disposed) busy.value = false;
    }
  }

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

  Future<void> selectMock() async {
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
      catalog.value = null;
      problem.value = null;
    } catch (_) {
      if (!_disposed) problem.value = MusicSourceProblem.scanFailed;
    } finally {
      if (!_disposed) busy.value = false;
    }
  }

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
      busy.dispose();
      problem.dispose();
    }
  }
}
