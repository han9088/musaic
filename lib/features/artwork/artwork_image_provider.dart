import 'package:flutter/widgets.dart';

import '../../services/music/directory_music_library.dart';
import 'artwork_file_provider_stub.dart'
    if (dart.library.io) 'artwork_file_provider_io.dart' as file_provider;
import 'artwork_network_provider_stub.dart'
    if (dart.library.io) 'artwork_network_provider_io.dart' as network_provider;

/// Resolves Demo assets, Apple Music URLs and local-file providers consistently.
class ArtworkImageResolver {
  const ArtworkImageResolver._();

  static ImageProvider<Object>? resolve(String source) {
    final uri = Uri.tryParse(source);
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      return network_provider.networkArtworkProvider(source);
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
    return file_provider.fileArtworkProvider(uri);
  }
  return ArtworkImageResolver.resolve(identity);
}
