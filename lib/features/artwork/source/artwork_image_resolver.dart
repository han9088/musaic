import 'dart:convert';

import 'package:flutter/painting.dart';

import '../../../services/music/directory_music_library.dart';
import '../artwork_file_provider_stub.dart'
    if (dart.library.io) '../artwork_file_provider_io.dart' as file_provider;
import '../artwork_network_provider_stub.dart'
    if (dart.library.io) '../artwork_network_provider_io.dart' as network_provider;
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

/// Resolves Asset, Network and directory artwork using platform-aware providers.
class ArtworkImageResolver {
  const ArtworkImageResolver();

  ImageProvider<Object>? providerFor(ArtworkSource source) {
    switch (source.type) {
      case ArtworkSourceType.asset:
        return AssetImage(source.value);
      case ArtworkSourceType.network:
        return network_provider.networkArtworkProvider(source.value);
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

    final image = file_provider.fileArtworkProvider(uri);
    if (image == null) return null;
    final version = jsonEncode(track.file.data);
    return ResolvedArtwork(
      identity: source.identity,
      sourceKey: '${image.toString()}:$version:$uri',
      image: image,
    );
  }
}
