// 文件职责：音乐源、媒体库、播放及切换流程。

import '../../../services/music/music_models.dart';

/// 转换数据格式并生成目标结构，用于音乐源、媒体库、播放及切换流程。
List<Map<String, dynamic>> mapProviderAlbums(List<ProviderAlbum> albums) => [
  for (final album in albums)
    <String, dynamic>{
      'asset': album.artworkUrl ?? 'local:${album.reference.id}',
      'title': album.title,
      'artist': album.artist ?? '',
    },
];
