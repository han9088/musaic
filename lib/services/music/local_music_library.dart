// 文件职责：音乐源、媒体库、播放及切换流程。

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:musaic_query/musaic_query.dart';

import 'music_models.dart';

/// 封装或定义本地音乐媒体库相关类型与行为，负责音乐源、媒体库、播放及切换流程。
final class LocalMusicLibrary {
  LocalMusicLibrary({MusaicQuery? query}) : _query = query ?? MusaicQuery();

  final MusaicQuery _query;
  static const providerId = 'local';
  Map<String, ProviderSong> _songs = {};
  Map<String, ProviderAlbum> _albums = {};
  Map<String, String> _sources = {};
  List<ProviderAlbum> _orderedAlbums = const [];
  /// 执行当前模块中的albums操作，用于音乐源、媒体库、播放及切换流程。
  List<ProviderAlbum> get albums => _orderedAlbums;

  static Future<Uint8List?> trackArtwork(int id) =>
      MusaicQuery().queryArtwork(id, ArtworkType.AUDIO, size: 512, quality: 90);

  /// 执行当前模块中的authorizationstatus操作，用于音乐源、媒体库、播放及切换流程。
  Future<MusicAccess> authorizationStatus({bool request = false}) async {
    if (kIsWeb) return MusicAccess.unavailable;
    try {
      final authorized = request
          ? await _query.permissionsRequest()
          : await _query.permissionsStatus();
      // 插件只提供是否授权的布尔结果，不会区分具体的拒绝原因。
      return authorized ? MusicAccess.authorized : MusicAccess.denied;
    } on MissingPluginException {
      return MusicAccess.unavailable;
    }
  }

  /// 移除、清理或重置相关状态与资源，用于音乐源、媒体库、播放及切换流程。
  void clear() {
    _songs = {};
    _albums = {};
    _sources = {};
    _orderedAlbums = const [];
  }

  /// 执行当前模块中的scan操作，用于音乐源、媒体库、播放及切换流程。
  Future<void> scan() async {
    final result = await compute(
      _buildCatalog,
      await _query.querySongs(),
      debugLabel: 'system-music-catalog',
    );
    if (await authorizationStatus() != MusicAccess.authorized) {
      clear();
      throw StateError('System music access was revoked during query');
    }
    _songs = result.songs;
    _albums = result.albums;
    _sources = result.sources;
    _orderedAlbums = result.ordered;
  }

  static ({
    Map<String, ProviderSong> songs,
    Map<String, ProviderAlbum> albums,
    Map<String, String> sources,
    List<ProviderAlbum> ordered,
  })
  _buildCatalog(List<SongModel> rows) {
    rows.sort((a, b) {
      final album = (a.albumId ?? 0).compareTo(b.albumId ?? 0);
      if (album != 0) return album;
      final disc = ((a.getMap['disc'] as int?) ?? 0).compareTo(
        (b.getMap['disc'] as int?) ?? 0,
      );
      if (disc != 0) return disc;
      final track = (a.track ?? 0).compareTo(b.track ?? 0);
      return track == 0 ? a.id.compareTo(b.id) : track;
    });
    final songs = <String, ProviderSong>{};
    final groups = <String, List<ProviderSong>>{};
    final titles = <String, String>{};
    final sources = <String, String>{};
    for (final row in rows) {
      if (row.isMusic == false) continue;
      final id = row.id.toString();
      final albumId = row.albumId?.toString() ?? 'song:$id';
      final url = row.uri;
      final uri = url == null ? null : Uri.tryParse(url);
      final playable =
          row.getMap['is_protected'] != true &&
          uri != null &&
          {'content', 'file', 'ipod-library'}.contains(uri.scheme);
      final millis = row.duration;
      final ProviderSong song = (
        reference: reference(id, MusicKind.song),
        title: row.title.isEmpty ? 'Unknown song' : row.title,
        artist: row.artist,
        artworkUrl: uri?.scheme == 'content' && uri?.authority == 'media'
            ? 'media-store:$id?modified=${row.dateModified ?? 0}'
            : null,
        duration: millis == null ? null : Duration(milliseconds: millis),
        playable: playable,
      );
      if (songs.containsKey(id)) continue;
      songs[id] = song;
      if (playable) sources[id] = url!;
      groups.putIfAbsent(albumId, () => []).add(song);
      titles[albumId] = row.album ?? 'Unknown album';
    }
    final albums = <String, ProviderAlbum>{};
    for (final entry in groups.entries) {
      albums[entry.key] = (
        reference: reference(entry.key, MusicKind.album),
        title: titles[entry.key]!,
        artist: entry.value.first.artist,
        artworkUrl: entry.value.first.artworkUrl,
        trackCount: entry.value.length,
        tracks: List<ProviderSong>.unmodifiable(entry.value),
      );
    }
    final ordered = albums.values.toList()
      ..sort((a, b) {
        final title = a.title.compareTo(b.title);
        return title == 0 ? a.reference.id.compareTo(b.reference.id) : title;
      });
    return (
      songs: songs,
      albums: albums,
      sources: sources,
      ordered: List<ProviderAlbum>.unmodifiable(ordered),
    );
  }

  /// 执行当前模块中的来源操作，用于音乐源、媒体库、播放及切换流程。
  String source(ProviderSong song) {
    final value = _sources[song.reference.id];
    if (value == null) {
      throw UnsupportedError(
        'This system music item has no playable local asset',
      );
    }
    return value;
  }

  /// 执行当前模块中的专辑操作，用于音乐源、媒体库、播放及切换流程。
  ProviderAlbum album(MusicReference ref) {
    validate(ref);
    final value = ref.kind == MusicKind.album ? _albums[ref.id] : null;
    if (value == null) {
      throw ArgumentError.value(ref, 'reference', 'Unknown local album');
    }
    return value;
  }

  /// 解析输入并转换为内部数据，用于音乐源、媒体库、播放及切换流程。
  List<ProviderSong> resolve(List<MusicReference> items) => [
    for (final item in items) ..._resolve(item),
  ];

  /// 解析输入并转换为内部数据，用于音乐源、媒体库、播放及切换流程。
  Iterable<ProviderSong> _resolve(MusicReference ref) {
    validate(ref);
    if (ref.kind == MusicKind.album) {
      final tracks = album(ref).tracks!.where((song) => song.playable).toList();
      if (tracks.isEmpty) {
        throw UnsupportedError('Album has no playable local tracks');
      }
      return tracks;
    }
    final song = ref.kind == MusicKind.song ? _songs[ref.id] : null;
    if (song == null) {
      throw ArgumentError.value(ref, 'reference', 'Unknown local song');
    }
    source(song);
    return [song];
  }

  /// 检查输入或当前状态是否符合约束，用于音乐源、媒体库、播放及切换流程。
  static void validate(MusicReference ref) {
    if (ref.provider != providerId ||
        ref.source != MusicSource.library ||
        ref.storefront != null) {
      throw ArgumentError.value(
        ref,
        'reference',
        'Expected a local library reference',
      );
    }
  }

  /// 执行当前模块中的reference操作，用于音乐源、媒体库、播放及切换流程。
  static MusicReference reference(String id, MusicKind kind) => (
    provider: providerId,
    id: id,
    kind: kind,
    source: MusicSource.library,
    storefront: null,
  );
}
