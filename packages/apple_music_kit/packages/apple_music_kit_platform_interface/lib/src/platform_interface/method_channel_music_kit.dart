/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import '../../apple_music_kit_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// Shared native channel transport for the iOS and Android implementations.
class MethodChannelMusicKit extends MusicKitPlatform {
  MethodChannelMusicKit(this.platformName);

  final String platformName;
  final _channel = const MethodChannel('deskbtm.apple_music_kit/methods');

  @protected
  Future<T?> invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw MusicKitException(
        MusicKitErrorCode.fromName(e.code),
        message: e.message ?? '$platformName MusicKit error.',
        platform: platformName,
        details: e.details is Map
            ? Map<String, Object?>.fromEntries((e.details as Map).entries
                .where((entry) => entry.key is String)
                .map((entry) => MapEntry(entry.key as String, entry.value)))
            : null,
      );
    } on MissingPluginException {
      throw MusicKitException(MusicKitErrorCode.unsupportedFeature,
          message: 'The native implementation does not support $method.',
          platform: platformName);
    }
  }

  @override
  Future<void> initialize(MusicKitPlatformConfig config) async =>
      invoke<void>('initialize', {
        'appName': config.appName,
        'appBuild': config.appBuild,
      });

  @override
  Future<void> dispose({bool stopPlayback = false}) async =>
      invoke<void>('dispose', {'stopPlayback': stopPlayback});

  @override
  Future<MusicAuthorizationStatus> getAuthorizationStatus() async =>
      MusicAuthorizationStatus.fromName(
          await invoke<String>('getAuthorizationStatus'));

  @override
  Future<MusicAuthorizationStatus> requestAuthorization() async =>
      MusicAuthorizationStatus.fromName(
          await invoke<String>('requestAuthorization'));

  @override
  late final Stream<MusicAuthorizationStatus> onAuthorizationChanged =
      EventChannel('deskbtm.apple_music_kit/authEvents')
          .receiveBroadcastStream()
          .map((dynamic s) => MusicAuthorizationStatus.fromName(s as String?));

  @override
  Future<MusicSubscription> getSubscription() async =>
      MusicSubscription.fromJson(_map(await invoke<Object>('getSubscription')));

  @override
  Future<MusicCapabilities> getCapabilities() async =>
      MusicCapabilities.fromJson(_map(await invoke<Object>('getCapabilities')));

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
    final raw = _map(await invoke<Object>('searchCatalog', {
      'term': term,
      'types': types.map((t) => t.wireName).toList(),
      'limit': limit,
      if (storefront != null) 'storefront': storefront,
    }));
    return MusicSearchResult(
      songs: _page<MusicSong>(raw['songs'], MusicSong.fromApiJson),
      albums: _page<MusicAlbum>(raw['albums'], MusicAlbum.fromApiJson),
      artists: _page<MusicArtist>(raw['artists'], MusicArtist.fromApiJson),
      playlists:
          _page<MusicPlaylist>(raw['playlists'], MusicPlaylist.fromApiJson),
    );
  }

  @override
  Future<List<MusicAnimatedArtwork>> getAlbumAnimatedArtwork(String id,
      {required String storefront}) async =>
      MusicAnimatedArtwork.fromApiResponse(
          await invoke<Object>('getAlbumAnimatedArtwork', {
        'id': id,
        'storefront': storefront,
      }));

  @override
  Future<MusicSong> getCatalogSong(String id, {String? storefront}) async =>
      MusicSong.fromApiJson(_map(await invoke<Object>('getCatalogSong', {
        'id': id,
        if (storefront != null) 'storefront': storefront,
      })));

  @override
  Future<MusicAlbum> getCatalogAlbum(String id,
          {String? storefront, bool includeTracks = false}) async =>
      MusicAlbum.fromApiJson(_map(await invoke<Object>('getCatalogAlbum', {
        'id': id,
        'includeTracks': includeTracks,
        if (storefront != null) 'storefront': storefront,
      })));

  @override
  Future<MusicArtist> getCatalogArtist(String id, {String? storefront}) async =>
      MusicArtist.fromApiJson(_map(await invoke<Object>('getCatalogArtist', {
        'id': id,
        if (storefront != null) 'storefront': storefront,
      })));

  @override
  Future<MusicPlaylist> getCatalogPlaylist(String id,
          {String? storefront, bool includeTracks = false}) async =>
      MusicPlaylist.fromApiJson(
          _map(await invoke<Object>('getCatalogPlaylist', {
        'id': id,
        'includeTracks': includeTracks,
        if (storefront != null) 'storefront': storefront,
      })));

  @override
  Future<List<MusicChart>> getCharts(MusicChartKind kind,
      {String? storefront, int limit = 20}) async {
    final raw = _list(await invoke<Object>('getCharts', {
      'kind': kind.name,
      'limit': limit,
      if (storefront != null) 'storefront': storefront,
    }));
    return raw.map((c) {
      final m = _map(c);
      return MusicChart(
        kind: kind,
        name: m['name'] as String? ?? '',
        songs: _page<MusicSong>(m['songs'], MusicSong.fromApiJson),
        albums: _page<MusicAlbum>(m['albums'], MusicAlbum.fromApiJson),
      );
    }).toList(growable: false);
  }

  @override
  Future<MusicStorefront> getCurrentStorefront() async =>
      MusicStorefront.fromApiJson(
          _map(await invoke<Object>('getCurrentStorefront')));

  @override
  Future<MusicPage<MusicSong>> getLibrarySongs(
          {int limit = 25, int? offset}) async =>
      _page<MusicSong>(
        _map(await invoke<Object>('getLibrarySongs',
            {'limit': limit, if (offset != null) 'offset': offset})),
        (m) => MusicSong.fromApiJson(m, source: MusicItemSource.library),
      )!;

  @override
  Future<MusicPage<MusicAlbum>> getLibraryAlbums(
          {int limit = 25, int? offset}) async =>
      _page<MusicAlbum>(
        _map(await invoke<Object>('getLibraryAlbums',
            {'limit': limit, if (offset != null) 'offset': offset})),
        (m) => MusicAlbum.fromApiJson(m, source: MusicItemSource.library),
      )!;

  @override
  Future<MusicPage<MusicPlaylist>> getLibraryPlaylists(
          {int limit = 25, int? offset}) async =>
      _page<MusicPlaylist>(
        _map(await invoke<Object>('getLibraryPlaylists',
            {'limit': limit, if (offset != null) 'offset': offset})),
        (m) => MusicPlaylist.fromApiJson(m, source: MusicItemSource.library),
      )!;

  @override
  Future<MusicSearchResult> searchLibrary(String term,
      {Set<MusicResourceType> types = const {MusicResourceType.song},
      int limit = 25}) async {
    final raw = _map(await invoke<Object>('searchLibrary', {
      'term': term,
      'types': types.map((t) => t.wireName).toList(),
      'limit': limit,
    }));
    return MusicSearchResult(
      songs: _page<MusicSong>(raw['songs'],
          (m) => MusicSong.fromApiJson(m, source: MusicItemSource.library)),
      albums: _page<MusicAlbum>(raw['albums'],
          (m) => MusicAlbum.fromApiJson(m, source: MusicItemSource.library)),
      artists: _page<MusicArtist>(raw['artists'], MusicArtist.fromApiJson),
      playlists: _page<MusicPlaylist>(raw['playlists'],
          (m) => MusicPlaylist.fromApiJson(m, source: MusicItemSource.library)),
    );
  }

  @override
  Future<void> addToLibrary(List<MusicItemRef> songs) async => invoke<void>(
      'addToLibrary', {'songs': songs.map((s) => s.toJson()).toList()});

  @override
  Future<MusicCreatedPlaylist> createPlaylist(String name,
      {String? description, List<MusicItemRef>? tracks}) async {
    final raw = _map(await invoke<Object>('createPlaylist', {
      'name': name,
      if (description != null) 'description': description,
      if (tracks != null) 'tracks': tracks.map((t) => t.toJson()).toList(),
    }));
    return MusicCreatedPlaylist(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? name,
      description: raw['description'] as String?,
    );
  }

  @override
  Future<MusicAddToPlaylistResult> addToPlaylist(
      String playlistLibraryId, List<MusicItemRef> tracks) async {
    final raw = _map(await invoke<Object>('addToPlaylist', {
      'playlistId': playlistLibraryId,
      'tracks': tracks.map((t) => t.toJson()).toList(),
    }));
    return MusicAddToPlaylistResult(
      playlistId: raw['playlistId'] as String? ?? playlistLibraryId,
      addedRefs: ((raw['added'] as List<dynamic>?) ?? const [])
          .map((dynamic r) => MusicItemRef.fromJson(_map(r)))
          .toList(growable: false),
    );
  }

  // ---------------- player ----------------

  @override
  Future<void> setQueue(List<MusicItemRef> items,
          {int startIndex = 0, bool autoplay = true}) async =>
      invoke<void>('setQueue', {
        'items': items.map((i) => i.toJson()).toList(),
        'startIndex': startIndex,
        'autoplay': autoplay,
      });

  @override
  Future<void> play() async => invoke<void>('play');

  @override
  Future<void> pause() async => invoke<void>('pause');

  @override
  Future<void> stop() async => invoke<void>('stop');

  @override
  Future<void> togglePlayPause() async => invoke<void>('togglePlayPause');

  @override
  Future<void> seekTo(Duration position) async =>
      invoke<void>('seekTo', {'positionMillis': position.inMilliseconds});

  @override
  Future<void> skipToNext() async => invoke<void>('skipToNext');

  @override
  Future<void> skipToPrevious() async => invoke<void>('skipToPrevious');

  @override
  Future<MusicQueue> getQueue() async {
    final raw = _map(await invoke<Object>('getQueue'));
    return MusicQueue(
      entries:
          ((raw['entries'] as List<dynamic>?) ?? const []).map((dynamic e) {
        final m = _map(e);
        return MusicQueueEntry(
          ref: MusicItemRef.fromJson(_map(m['ref'])),
          song:
              m['song'] == null ? null : MusicSong.fromApiJson(_map(m['song'])),
        );
      }).toList(growable: false),
      currentIndex: raw['currentIndex'] as int?,
    );
  }

  @override
  Future<void> appendToQueue(List<MusicItemRef> items) async => invoke<void>(
      'appendToQueue', {'items': items.map((i) => i.toJson()).toList()});

  @override
  Future<void> removeFromQueue(int index) async =>
      invoke<void>('removeFromQueue', {'index': index});

  @override
  Future<void> setShuffleMode(MusicShuffleMode mode) async =>
      invoke<void>('setShuffleMode', {'mode': mode.name});

  @override
  Future<void> setRepeatMode(MusicRepeatMode mode) async =>
      invoke<void>('setRepeatMode', {'mode': mode.name});

  @override
  late final Stream<MusicPlayerState> playerStates =
      EventChannel('deskbtm.apple_music_kit/playerEvents')
          .receiveBroadcastStream()
          .map((dynamic s) => _stateFromMap(_map(s)));

  static MusicPlayerState _stateFromMap(Map<String, dynamic> m) =>
      MusicPlayerState(
        status: MusicPlayerStatus.fromName(m['status'] as String?),
        currentItem: m['currentItem'] == null
            ? null
            : MusicItemRef.fromJson(_map(m['currentItem'])),
        currentIndex: m['currentIndex'] as int?,
        position: Duration(milliseconds: m['positionMillis'] as int? ?? 0),
        duration: m['durationMillis'] == null
            ? null
            : Duration(milliseconds: m['durationMillis'] as int),
        queueLength: m['queueLength'] as int? ?? 0,
        shuffleMode: MusicShuffleMode.fromName(m['shuffleMode'] as String?),
        repeatMode: MusicRepeatMode.fromName(m['repeatMode'] as String?),
        isPlaying: m['isPlaying'] as bool? ?? false,
        isBuffering: m['isBuffering'] as bool? ?? false,
      );

  static Map<String, dynamic> _map(Object? o) => o == null
      ? const <String, dynamic>{}
      : (o as Map).map((key, value) => MapEntry(key as String, _decode(value)));

  static Object? _decode(Object? value) {
    if (value is Map) return _map(value);
    if (value is List) return value.map(_decode).toList(growable: false);
    return value;
  }

  static List<dynamic> _list(Object? o) => (o as List<dynamic>? ?? const []);

  static MusicPage<T>? _page<T>(
      Object? raw, T Function(Map<String, dynamic>) convert) {
    if (raw == null) return null;
    return MusicPage.fromApiJson<T>(_map(raw), convert);
  }
}
