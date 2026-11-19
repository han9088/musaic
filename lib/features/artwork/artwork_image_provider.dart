import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../services/music/directory_music_library.dart';
import 'artwork_image_provider.dart' as resolver;

/// Resolves the exact source provider used by visible artwork widgets.
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
  return resolver.ArtworkImageResolver.resolve(identity);
}
