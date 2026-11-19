import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../../services/music/directory_music_library.dart';
import 'artwork_network_cache_manager.dart';

/// Resolves Demo assets, Apple Music URLs and local-file providers consistently.
class ArtworkImageResolver {
  const ArtworkImageResolver._();

  static ImageProvider<Object>? resolve(String source) {
    final uri = Uri.tryParse(source);
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      return CachedNetworkImageProvider(
        source,
        cacheManager: ArtworkNetworkCacheManager.instance,
        cacheKey: source,
      );
    }

    if (source.startsWith('local:') || source.startsWith('directory:')) {
      return null;
    }

    return AssetImage(source);
  }
}

/// Resolves the same provider used by visible artwork widgets for raster jobs.
Future<ImageProvider<Object>?> resolveArtworkImageProvider(
  String identity, {
  DirectoryMusicLibrary? directories,
}) async {
  if (identity.startsWith('local:')) return null;
  if (identity.startsWith('directory:')) {
    final id = Uri.decodeComponent(
      identity.substring('directory:'.length),
    );
    final track = directories?.track(id);
    if (directories == null || track == null) return null;
    final uri = await directories.artwork(track);
    if (uri == null || uri.isEmpty) return null;
    return FileImage(File.fromUri(Uri.parse(uri)));
  }
  return ArtworkImageResolver.resolve(identity);
}
