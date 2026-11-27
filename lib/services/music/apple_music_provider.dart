// 文件职责：音乐源、媒体库、播放及切换流程。

import 'package:apple_music_kit/apple_music_kit.dart' as apple;

import 'music_provider.dart';

/// 封装或定义Apple音乐提供器相关类型与行为，负责音乐源、媒体库、播放及切换流程。
final class AppleMusicProvider implements MusicProvider {
  AppleMusicProvider({required this._client});

  static const providerId = 'apple_music';

  final apple.AppleMusicClient _client;

  @override
  /// 执行当前模块中的id操作，用于音乐源、媒体库、播放及切换流程。
  String get id => providerId;

  @override
  Future<void> initialize() => _client.initialize();

  @override
  Future<MusicAccess> authorizationStatus() async =>
      _access(await _client.authorization.getStatus());

  @override
  Future<MusicAccess> requestAuthorization() async =>
      _access(await _client.authorization.request());

  @override
  Future<MusicFeatures> capabilities() async {
    final value = await _client.capabilities.get();
    return (
      playback: _feature(value.canPlayCatalog),
      library: _feature(value.canAccessLibrary),
      queue: _feature(value.canSetQueue),
      seek: _feature(value.canSeek),
    );
  }

  @override
  Future<List<ProviderAlbum>> searchAlbums(
    String query, {
    int limit = 25,
  }) async {
    _validateLimit(limit);
    if (query.trim().isEmpty) throw ArgumentError.value(query, 'query');
    final result = await _client.catalog.search(
      query.trim(),
      types: {apple.MusicResourceType.album},
      limit: limit,
    );
    return List<ProviderAlbum>.unmodifiable(
      result.albums?.items.map(_album) ?? const <ProviderAlbum>[],
    );
  }

  @override
  Future<MusicPage<ProviderAlbum>> libraryAlbums({
    int limit = 25,
    String? cursor,
  }) async {
    _validateLimit(limit);
    final offset = cursor == null ? null : int.tryParse(cursor);
    if (cursor != null && (offset == null || offset < 0)) {
      throw ArgumentError.value(cursor, 'cursor');
    }
    final result = await _client.library.getAlbums(
      limit: limit,
      offset: offset,
    );
    return (
      items: List<ProviderAlbum>.unmodifiable(result.items.map(_album)),
      nextCursor: result.nextOffset?.toString(),
    );
  }

  @override
  Future<ProviderAlbum> album(MusicReference reference) async {
    _validateReference(reference);
    if (reference.kind != MusicKind.album) {
      throw ArgumentError.value(reference, 'reference', 'Expected an album');
    }
    if (reference.source != MusicSource.catalog) {
      throw UnsupportedError(
        'Apple Music library album details are unavailable',
      );
    }
    return _album(
      await _client.catalog.getAlbum(
        reference.id,
        storefront: reference.storefront,
        includeTracks: true,
      ),
    );
  }

  @override
  Future<List<MusicAnimatedArtwork>> animatedArtwork(
    MusicReference reference,
  ) async {
    _validateReference(reference);
    if (reference.kind != MusicKind.album) {
      throw ArgumentError.value(reference, 'reference', 'Expected an album');
    }
    if (reference.source != MusicSource.catalog) {
      throw UnsupportedError(
        'Resolve the library album to a catalog album first',
      );
    }
    final storefront =
        reference.storefront ??
        (await _client.catalog.getCurrentStorefront()).id;
    final variants = await _client.catalog.getAlbumAnimatedArtwork(
      reference.id,
      storefront: storefront,
    );
    return List<MusicAnimatedArtwork>.unmodifiable(
      variants.map(
        (variant) => (
          layout: switch (variant.type) {
            'motionDetailSquare' ||
            'motionSquareVideo1x1' => MusicArtworkLayout.square,
            'motionDetailTall' ||
            'motionTallVideo3x4' => MusicArtworkLayout.portrait,
            _ => MusicArtworkLayout.unknown,
          },
          videoUrl: variant.videoUrl,
        ),
      ),
    );
  }

  @override
  /// 执行当前模块中的播放操作，用于音乐源、媒体库、播放及切换流程。
  Stream<MusicPlayback> get playback => _client.player.states.map(
    (state) => (
      status: switch (state.status) {
        apple.MusicPlayerStatus.idle => MusicPlaybackStatus.idle,
        apple.MusicPlayerStatus.loading => MusicPlaybackStatus.loading,
        apple.MusicPlayerStatus.buffering => MusicPlaybackStatus.buffering,
        apple.MusicPlayerStatus.ready => MusicPlaybackStatus.ready,
        apple.MusicPlayerStatus.playing => MusicPlaybackStatus.playing,
        apple.MusicPlayerStatus.paused => MusicPlaybackStatus.paused,
        apple.MusicPlayerStatus.stopped => MusicPlaybackStatus.stopped,
        apple.MusicPlayerStatus.completed => MusicPlaybackStatus.completed,
        apple.MusicPlayerStatus.error => MusicPlaybackStatus.error,
      },
      currentItem: state.currentItem == null
          ? null
          : _reference(state.currentItem!),
      position: state.position,
      duration: state.duration,
      isPlaying: state.isPlaying,
      isBuffering: state.isBuffering,
      error: state.error,
    ),
  );

  @override
  Future<void> play(List<MusicReference> items, {int startIndex = 0}) async {
    if (items.isEmpty) throw ArgumentError.value(items, 'items', 'Empty queue');
    RangeError.checkValidIndex(startIndex, items, 'startIndex');
    final queue = items
        .map((item) {
          _validateReference(item);
          if (item.kind != MusicKind.song && item.kind != MusicKind.album) {
            throw ArgumentError.value(
              item,
              'items',
              'Expected songs or albums',
            );
          }
          return apple.MusicItemRef(
            id: item.id,
            type: item.kind == MusicKind.song
                ? apple.MusicResourceType.song
                : apple.MusicResourceType.album,
            source: item.source == MusicSource.catalog
                ? apple.MusicItemSource.catalog
                : apple.MusicItemSource.library,
            storefront: item.storefront,
          );
        })
        .toList(growable: false);
    await _client.player.setQueue(
      queue,
      startIndex: startIndex,
      autoplay: true,
    );
  }

  @override
  Future<void> resume() => _client.player.play();
  @override
  Future<void> pause() => _client.player.pause();
  @override
  Future<void> seek(Duration position) async {
    if (position.isNegative) throw ArgumentError.value(position, 'position');
    await _client.player.seekTo(position);
  }

  @override
  Future<void> next() => _client.player.skipToNext();
  @override
  Future<void> previous() => _client.player.skipToPrevious();
  @override
  Future<void> dispose() => _client.dispose();

  void _validateReference(MusicReference reference) {
    if (reference.provider != id || reference.id.trim().isEmpty) {
      throw ArgumentError.value(
        reference,
        'reference',
        'Invalid provider or ID',
      );
    }
  }

  /// 检查输入或当前状态是否符合约束，用于音乐源、媒体库、播放及切换流程。
  static void _validateLimit(int limit) =>
      RangeError.checkValueInInterval(limit, 1, 25, 'limit');

  static MusicAccess _access(apple.MusicAuthorizationStatus status) =>
      switch (status) {
        apple.MusicAuthorizationStatus.notDetermined =>
          MusicAccess.notDetermined,
        apple.MusicAuthorizationStatus.authorized => MusicAccess.authorized,
        apple.MusicAuthorizationStatus.denied => MusicAccess.denied,
        apple.MusicAuthorizationStatus.restricted => MusicAccess.restricted,
        apple.MusicAuthorizationStatus.unavailable => MusicAccess.unavailable,
      };

  static MusicFeature _feature(apple.MusicCapability value) => (
    supported: value.supported,
    reason: value.reason.name,
    detail: value.detail,
  );

  MusicReference _reference(apple.MusicItemRef value) => (
    provider: id,
    id: value.id,
    kind: switch (value.type) {
      apple.MusicResourceType.song => MusicKind.song,
      apple.MusicResourceType.album => MusicKind.album,
      apple.MusicResourceType.artist => MusicKind.artist,
      apple.MusicResourceType.playlist => MusicKind.playlist,
      apple.MusicResourceType.station => MusicKind.station,
    },
    source: value.source == apple.MusicItemSource.catalog
        ? MusicSource.catalog
        : MusicSource.library,
    storefront: value.storefront,
  );

  ProviderAlbum _album(apple.MusicAlbum value) => (
    reference: _reference(value.ref),
    title: value.title,
    artist: value.artistName,
    artworkUrl: value.artwork?.url(),
    trackCount: value.trackCount,
    tracks: value.tracks == null
        ? null
        : List<ProviderSong>.unmodifiable(
            value.tracks!.map(
              (song) => (
                reference: _reference(song.ref),
                title: song.title,
                artist: song.artistName,
                artworkUrl: song.artwork?.url(),
                duration: song.duration,
                playable: song.isPlayable,
              ),
            ),
          ),
  );
}
