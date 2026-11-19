import 'package:flutter/painting.dart';

import '../../services/music/directory_music_library.dart';
import 'source/artwork_image_resolver.dart';

export 'source/artwork_image_resolver.dart'
    show ArtworkImageResolver, ResolvedArtwork;
export 'source/artwork_source.dart';

/// Backwards-compatible entry point used by the home transition planner.
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
