/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'dart:async';

import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';
import 'package:flutter/foundation.dart';

/// An in-memory [MusicKitPlatform] for development, demos and tests.
///
/// **This is a mock.** It never touches Apple Music, never plays real
/// audio, and must never be presented as a working MusicKit integration.
/// It exists so UIs and business logic can be built and tested without
/// Apple Developer credentials, a subscription, or the Android SDK.
///
/// Install it with [installMusicKitMock] before creating the client:
///
/// ```dart
/// import 'package:apple_music_kit/apple_music_kit.dart';
/// import 'package:apple_music_kit/mock.dart';
///
/// void main() {
///   if (kDebugMode) installMusicKitMock();
///   runApp(const MyApp());
/// }
/// ```
final class MockMusicKitPlatform extends MusicKitPlatform {
  /// Creates the mock with a small built-in catalog.
  MockMusicKitPlatform({bool autoGrantAuthorization = true})
      : _autoGrant = autoGrantAuthorization;

  final bool _autoGrant;

  // ---------------- built-in fake catalog ----------------

  static const _fakeSongs = <MusicSong>[
    MusicSong(
      id: 'mock-song-1',
      title: 'Aurora Borealis',
      artistName: 'The Mocks',
      albumTitle: 'Test Signals',
      albumId: 'mock-album-1',
      duration: Duration(milliseconds: 214000),
      trackNumber: 1,
      isPlayable: true,
    ),
    MusicSong(
      id: 'mock-song-2',
      title: 'Static Bloom',
      artistName: 'The Mocks',
      albumTitle: 'Test Signals',
      albumId: 'mock-album-1',
      duration: Duration(milliseconds: 187000),
      trackNumber: 2,
      isPlayable: true,
    ),
    MusicSong(
      id: 'mock-song-3',
      title: 'Latency Lullaby',
      artistName: 'Null Safety',
      albumTitle: 'Async Dreams',
      albumId: 'mock-album-2',
      duration: Duration(milliseconds: 243000),
      trackNumber: 1,
      isPlayable: true,
    ),
  ];

  static const _fakeAlbums = <MusicAlbum>[
    MusicAlbum(
        id: 'mock-album-1',
        title: 'Test Signals',
        artistName: 'The Mocks',
        trackCount: 2),
    MusicAlbum(
        id: 'mock-album-2',
        title: 'Async Dreams',
        artistName: 'Null Safety',
        trackCount: 1),
  ];

  static const _fakeArtists = <MusicArtist>[
    MusicArtist(id: 'mock-artist-1', name: 'The Mocks'),
    MusicArtist(id: 'mock-artist-2', name: 'Null Safety'),
  ];

  static const _fakePlaylists = <MusicPlaylist>[
    MusicPlaylist(
        id: 'mock-playlist-1', name: 'Mock Favorites', curatorName: 'deskbtm'),
  ];

  // ---------------- state ----------------

  bool _initialized = false;
  bool _disposed = false;
  MusicAuthorizationStatus _authStatus = MusicAuthorizationStatus.notDetermined;
  final _authController =
      StreamController<MusicAuthorizationStatus>.broadcast();
  final _stateController =
      StreamController<MusicPlayerState>.broadcast(sync: true);
  MusicPlayerState _state = const MusicPlayerState.initial();
  List<MusicItemRef> _queue = [];
  Timer? _ticker;

  @override
  Future<void> initialize(MusicKitPlatformConfig config) async {
    if (_disposed) {
      throw MusicKitException(MusicKitErrorCode.alreadyDisposed,
          message: 'Mock platform disposed.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _initialized = true;
  }

  @override
  Future<void> dispose({bool stopPlayback = false}) async {
    _disposed = true;
    _ticker?.cancel();
    await _authController.close();
    await _stateController.close();
  }

  void _requireInit() {
    if (!_initialized) {
      throw MusicKitException(
        MusicKitErrorCode.notInitialized,
        message: 'Mock platform: call initialize() first.',
        platform: 'mock',
      );
    }
  }

  // ---------------- authorization ----------------

  @override
  Future<MusicAuthorizationStatus> getAuthorizationStatus() async {
    _requireInit();
    return _authStatus;
  }

  @override
  Future<MusicAuthorizationStatus> requestAuthorization() async {
    _requireInit();
    _authStatus = _autoGrant
        ? MusicAuthorizationStatus.authorized
        : MusicAuthorizationStatus.denied;
    _authController.add(_authStatus);
    return _authStatus;
  }

  @override
  Stream<MusicAuthorizationStatus> get onAuthorizationChanged async* {
    yield _authStatus;
    yield* _authController.stream;
  }

  @override
  Future<MusicSubscription> getSubscription() async {
    _requireInit();
    return const MusicSubscription(
      status: MusicSubscriptionStatus.subscribed,
      canPlayCatalogContent: true,
      canUseCloudLibrary: true,
      hasCloudLibraryEnabled: true,
    );
  }

  // ---------------- capabilities ----------------

  @override
  Future<MusicCapabilities> getCapabilities() async {
    _requireInit();
    const supported = MusicCapability.supported();
    return const MusicCapabilities(
      canPlayCatalog: supported,
      canAccessLibrary: supported,
      canSeek: supported,
      canSetQueue: supported,
      canEditQueue: supported,
      canShuffle: supported,
      canRepeat: supported,
      canControlVolume: supported,
      canPlayInBackground: supported,
      canCreatePlaylist: supported,
    );
  }

  // ---------------- catalog ----------------

  @override
  Future<MusicSearchResult> searchCatalog(
    String term, {
    Set<MusicResourceType> types = const {
      MusicResourceType.song,
      MusicResourceType.album,
      MusicResourceType.artist,
      MusicResourceType.playlist
    },
    int limit = 25,
    String? storefront,
  }) async {
    _requireInit();
    final t = term.toLowerCase();
    MusicPage<MusicSong>? songs;
    MusicPage<MusicAlbum>? albums;
    MusicPage<MusicArtist>? artists;
    MusicPage<MusicPlaylist>? playlists;
    if (types.contains(MusicResourceType.song)) {
      songs = MusicPage(
          items: _fakeSongs
              .where((s) => s.title.toLowerCase().contains(t))
              .toList());
    }
    if (types.contains(MusicResourceType.album)) {
      albums = MusicPage(
          items: _fakeAlbums
              .where((a) => a.title.toLowerCase().contains(t))
              .toList());
    }
    if (types.contains(MusicResourceType.artist)) {
      artists = MusicPage(
          items: _fakeArtists
              .where((a) => a.name.toLowerCase().contains(t))
              .toList());
    }
    if (types.contains(MusicResourceType.playlist)) {
      playlists = MusicPage(
          items: _fakePlaylists
              .where((p) => p.name.toLowerCase().contains(t))
              .toList());
    }
    return MusicSearchResult(
        songs: songs, albums: albums, artists: artists, playlists: playlists);
  }

  @override
  Future<MusicSong> getCatalogSong(String id, {String? storefront}) async {
    _requireInit();
    return _fakeSongs.firstWhere((s) => s.id == id,
        orElse: () => throw MusicKitException(
              MusicKitErrorCode.resourceNotFound,
              message: 'Mock song $id not found.',
              platform: 'mock',
            ));
  }

  @override
  Future<MusicAlbum> getCatalogAlbum(String id,
      {String? storefront, bool includeTracks = false}) async {
    _requireInit();
    return _fakeAlbums.firstWhere((a) => a.id == id,
        orElse: () => throw MusicKitException(
              MusicKitErrorCode.resourceNotFound,
              message: 'Mock album $id not found.',
              platform: 'mock',
            ));
  }

  @override
  Future<MusicArtist> getCatalogArtist(String id, {String? storefront}) async {
    _requireInit();
    return _fakeArtists.firstWhere((a) => a.id == id,
        orElse: () => throw MusicKitException(
              MusicKitErrorCode.resourceNotFound,
              message: 'Mock artist $id not found.',
              platform: 'mock',
            ));
  }

  @override
  Future<MusicPlaylist> getCatalogPlaylist(String id,
      {String? storefront, bool includeTracks = false}) async {
    _requireInit();
    return _fakePlaylists.firstWhere((p) => p.id == id,
        orElse: () => throw MusicKitException(
              MusicKitErrorCode.resourceNotFound,
              message: 'Mock playlist $id not found.',
              platform: 'mock',
            ));
  }

  @override
  Future<List<MusicChart>> getCharts(MusicChartKind kind,
      {String? storefront, int limit = 20}) async {
    _requireInit();
    return [
      MusicChart(
        kind: kind,
        name: 'Mock Top ${kind.name}',
        songs: kind == MusicChartKind.songs
            ? MusicPage(items: _fakeSongs.take(limit).toList())
            : null,
        albums: kind == MusicChartKind.albums
            ? MusicPage(items: _fakeAlbums.take(limit).toList())
            : null,
      ),
    ];
  }

  @override
  Future<MusicStorefront> getCurrentStorefront() async {
    _requireInit();
    return const MusicStorefront(
        id: 'US', name: 'United States', defaultLanguageTag: 'en-US');
  }

  // ---------------- library ----------------

  @override
  Future<MusicPage<MusicSong>> getLibrarySongs(
      {int limit = 25, int? offset}) async {
    _requireInit();
    return MusicPage(items: _fakeSongs.take(limit).toList());
  }

  @override
  Future<MusicPage<MusicAlbum>> getLibraryAlbums(
      {int limit = 25, int? offset}) async {
    _requireInit();
    return MusicPage(items: _fakeAlbums.take(limit).toList());
  }

  @override
  Future<MusicPage<MusicPlaylist>> getLibraryPlaylists(
      {int limit = 25, int? offset}) async {
    _requireInit();
    return MusicPage(items: _fakePlaylists.take(limit).toList());
  }

  @override
  Future<MusicSearchResult> searchLibrary(String term,
      {Set<MusicResourceType> types = const {MusicResourceType.song},
      int limit = 25}) async {
    _requireInit();
    return searchCatalog(term, types: types, limit: limit);
  }

  @override
  Future<void> addToLibrary(List<MusicItemRef> songs) async {
    _requireInit();
  }

  @override
  Future<MusicCreatedPlaylist> createPlaylist(String name,
      {String? description, List<MusicItemRef>? tracks}) async {
    _requireInit();
    return MusicCreatedPlaylist(
        id: 'mock-playlist-${DateTime.now().millisecondsSinceEpoch}',
        name: name);
  }

  @override
  Future<MusicAddToPlaylistResult> addToPlaylist(
      String playlistLibraryId, List<MusicItemRef> tracks) async {
    _requireInit();
    return MusicAddToPlaylistResult(
        playlistId: playlistLibraryId, addedRefs: tracks);
  }

  // ---------------- player ----------------

  @override
  Future<void> setQueue(List<MusicItemRef> items,
      {int startIndex = 0, bool autoplay = true}) async {
    _requireInit();
    _queue = List.of(items);
    _setState(
      MusicPlayerState(
        status: MusicPlayerStatus.ready,
        currentItem:
            items.isEmpty ? null : items[startIndex.clamp(0, items.length - 1)],
        currentIndex: items.isEmpty ? null : startIndex,
        queueLength: items.length,
      ),
    );
    if (autoplay && items.isNotEmpty) {
      await play();
    }
  }

  @override
  Future<void> play() async {
    _requireInit();
    _setState(
        _state.copyWith(status: MusicPlayerStatus.playing, isPlaying: true));
    _startTicker();
  }

  @override
  Future<void> pause() async {
    _requireInit();
    _ticker?.cancel();
    _setState(
        _state.copyWith(status: MusicPlayerStatus.paused, isPlaying: false));
  }

  @override
  Future<void> stop() async {
    _requireInit();
    _ticker?.cancel();
    _setState(_state.copyWith(
        status: MusicPlayerStatus.stopped,
        isPlaying: false,
        position: Duration.zero));
  }

  @override
  Future<void> togglePlayPause() async {
    _requireInit();
    if (_state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> seekTo(Duration position) async {
    _requireInit();
    _setState(_state.copyWith(position: position));
  }

  @override
  Future<void> skipToNext() async {
    _requireInit();
    final next = (_state.currentIndex ?? 0) + 1;
    if (next >= _queue.length) {
      _setState(_state.copyWith(
          status: MusicPlayerStatus.completed, isPlaying: false));
      return;
    }
    _setState(_state.copyWith(
      currentItem: _queue[next],
      currentIndex: next,
      position: Duration.zero,
      status: _state.isPlaying
          ? MusicPlayerStatus.playing
          : MusicPlayerStatus.ready,
    ));
  }

  @override
  Future<void> skipToPrevious() async {
    _requireInit();
    final prev = (_state.currentIndex ?? 0) - 1;
    if (prev < 0) {
      _setState(_state.copyWith(position: Duration.zero));
      return;
    }
    _setState(_state.copyWith(
      currentItem: _queue[prev],
      currentIndex: prev,
      position: Duration.zero,
      status: _state.isPlaying
          ? MusicPlayerStatus.playing
          : MusicPlayerStatus.ready,
    ));
  }

  @override
  Future<MusicQueue> getQueue() async {
    _requireInit();
    return MusicQueue(
      entries:
          _queue.map((r) => MusicQueueEntry(ref: r)).toList(growable: false),
      currentIndex: _state.currentIndex,
    );
  }

  @override
  Future<void> appendToQueue(List<MusicItemRef> items) async {
    _requireInit();
    _queue.addAll(items);
    _setState(_state.copyWith(queueLength: _queue.length));
  }

  @override
  Future<void> removeFromQueue(int index) async {
    _requireInit();
    if (index < 0 || index >= _queue.length) {
      throw MusicKitException(
        MusicKitErrorCode.resourceNotFound,
        message: 'Queue index out of range.',
        platform: 'mock',
      );
    }
    _queue.removeAt(index);
    _setState(_state.copyWith(queueLength: _queue.length));
  }

  @override
  Future<void> setShuffleMode(MusicShuffleMode mode) async {
    _requireInit();
    _setState(_state.copyWith(shuffleMode: mode));
  }

  @override
  Future<void> setRepeatMode(MusicRepeatMode mode) async {
    _requireInit();
    _setState(_state.copyWith(repeatMode: mode));
  }

  @override
  Stream<MusicPlayerState> get playerStates => Stream.multi((controller) {
        final subscription = _stateController.stream.listen(controller.addSync,
            onError: controller.addErrorSync, onDone: controller.closeSync);
        controller.addSync(_state);
        controller.onCancel = subscription.cancel;
      }, isBroadcast: true);

  // ---------------- internals ----------------

  void _setState(MusicPlayerState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 400), (_) {
      final pos = _state.position + const Duration(milliseconds: 400);
      final dur = _state.duration;
      if (dur != null && pos >= dur) {
        _ticker?.cancel();
        _setState(_state.copyWith(
            status: MusicPlayerStatus.completed,
            isPlaying: false,
            position: dur));
        return;
      }
      _setState(_state.copyWith(position: pos));
    });
  }
}

/// Installs [MockMusicKitPlatform] as the active platform.
///
/// For debug/demo builds only. Never ship this in a production code path
/// that claims real Apple Music support.
void installMusicKitMock({bool autoGrantAuthorization = true}) {
  debugPrint('apple_music_kit: MOCK platform installed. '
      'No real Apple Music functionality is available.');
  MusicKitPlatform.instance =
      MockMusicKitPlatform(autoGrantAuthorization: autoGrantAuthorization);
}
