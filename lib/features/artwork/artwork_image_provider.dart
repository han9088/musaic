// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'package:flutter/painting.dart';

import '../../services/music/directory_music_library.dart';
import 'source/artwork_image_resolver.dart';

export 'source/artwork_image_resolver.dart'
    show ArtworkImageResolver, ResolvedArtwork;
export 'source/artwork_source.dart';

/// 解析输入并转换为内部数据，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
Future<ImageProvider<Object>?> resolveArtworkImageProvider(
  String identity, {
  DirectoryMusicLibrary? directories,
}) async {
  final resolved = await const ArtworkImageResolver().resolve(
    identity,
    directories: directories,
  );
  return resolved?.image;
}
