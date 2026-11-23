// 文件职责：音乐源、媒体库、播放及切换流程。

import '../../../services/music/music_models.dart';

String albumArtworkSource(ProviderAlbum album) =>
    album.artworkUrl ?? 'local:${album.reference.id}';

bool albumHasSingleTrack(Map<String, dynamic> album) {
  final count =
      album['trackCount'] as int? ??
      (album['tracks'] as List<ProviderSong>?)?.length;
  return count == 1;
}

/// 转换数据格式并生成目标结构，用于音乐源、媒体库、播放及切换流程。
List<Map<String, dynamic>> mapProviderAlbums(List<ProviderAlbum> albums) => [
  for (final album in albums)
    <String, dynamic>{
      'id':
          '${album.reference.provider}:${album.reference.source.name}:${album.reference.id}',
      'asset': albumArtworkSource(album),
      'title': album.title,
      'artist': album.artist ?? '',
      if (album.trackCount != null) 'trackCount': album.trackCount,
      if (album.tracks != null) 'tracks': album.tracks,
    },
];
