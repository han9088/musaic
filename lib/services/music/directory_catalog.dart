// 文件职责：音乐源、媒体库、播放及切换流程。

import 'dart:convert';

import 'package:musaic_query/musaic_query.dart';

import '../../storage/music/music_index.dart';
import 'music_provider.dart';

const directoryMusicProviderId = 'directory';

/// 封装或定义本地目录目录相关类型与行为，负责音乐源、媒体库、播放及切换流程。
final class DirectoryCatalog {
  DirectoryCatalog(this.tracks, this.sources, this.folders, this.albums)
    : tracksById = {for (final track in tracks) track.file.id: track};
  final Map<String, IndexedAudio> tracksById;
  final List<IndexedAudio> tracks;
  final List<AudioDirectory> sources;
  final List<AudioFolderSummary> folders;
  final List<ProviderAlbum> albums;
}

/// 创建并组装所需对象或界面结构，用于音乐源、媒体库、播放及切换流程。
DirectoryCatalog buildDirectoryCatalog(MusicIndexRows rows) {
  final snapshot = rows.decode();
  final groups = <String, List<IndexedAudio>>{};
  for (final track in snapshot.tracks) {
    final key = jsonEncode([
      track.file.parent,
      track.metadata['album'],
      track.metadata['albumArtist'],
    ]);
    groups.putIfAbsent(key, () => []).add(track);
  }
  final albums = <ProviderAlbum>[
    for (final group in groups.entries)
      (
        reference: (
          provider: directoryMusicProviderId,
          id: group.key,
          kind: MusicKind.album,
          source: MusicSource.library,
          storefront: null,
        ),
        title:
            group.value.first.metadata['album'] as String? ??
            group.value.first.source.name,
        artist:
            group.value.first.metadata['albumArtist'] as String? ??
            group.value.first.metadata['artist'] as String?,
        artworkUrl:
            'directory:${Uri.encodeComponent(group.value.first.file.id)}',
        trackCount: group.value.length,
        tracks: [
          for (final track in group.value)
            (
              reference: (
                provider: directoryMusicProviderId,
                id: track.file.id,
                kind: MusicKind.song,
                source: MusicSource.library,
                storefront: null,
              ),
              title: track.title,
              artist: track.metadata['artist'] as String?,
              artworkUrl: null,
              duration: track.metadata['durationMs'] is int
                  ? Duration(milliseconds: track.metadata['durationMs'] as int)
                  : null,
              playable: true,
            ),
        ],
      ),
  ];
  return DirectoryCatalog(
    snapshot.tracks,
    snapshot.sources.values.toList(),
    snapshot.summaries(recursive: true),
    albums,
  );
}
