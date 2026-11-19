import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

import '../../../services/music/directory_music_library.dart';
import 'artwork_network_cache.dart';
import 'artwork_source.dart';

class ResolvedArtwork {
  const ResolvedArtwork({
    required this.identity,
    required this.sourceKey,
    required this.image,
  });

  final String identity;
  final String sourceKey;
  final ImageProvider<Object> image;
}

/// Resolves Asset, Network and local-directory artwork into ImageProviders.
class ArtworkImageResolver {
  const ArtworkImageResolver();

  ImageProvider<Object>? providerFor(ArtworkSource source) {
    switch (source.type) {
      case ArtworkSourceType.asset:
        return AssetImage(source.value);
      case ArtworkSourceType.network:
        return CachedNetworkImageProvider(
          source.value,
          cacheManager: ArtworkNetworkCache.instance,
          cacheKey: source.cacheKey,
        );
      case ArtworkSourceType.directory:
      case ArtworkSourceType.placeholder:
        return null;
    }
  }

  Future<ResolvedArtwork?> resolve(
    String reference, {
    required DirectoryMusicLibrary? directories,
  }) async {
    final source = ArtworkSource.parse(reference);
    final provider = providerFor(source);
    if (provider != null) {
      return ResolvedArtwork(
        identity: source.identity,
        sourceKey: provider.toString(),
        image: provider,
      );
    }

    if (!source.isDirectory || directories == null) return null;
    final id = Uri.decodeComponent(source.value);
    final track = directories.track(id);
    if (track == null) return null;

    final uri = await directories.artwork(track);
    if (uri == null || uri.isEmpty) return null;

    final file = File.fromUri(Uri.parse(uri));
    final version = jsonEncode(track.file.data);
    final provider = FileImage(file);
    return ResolvedArtwork(
      identity: source.identity,
      sourceKey: '${provider.toString()}:$version:$uri',
      image: provider,
    );
  }
}
