import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../services/music/directory_music_library.dart';

/// Resolves the same provider used by the artwork widgets for raster jobs.
Future<ImageProvider<Object>?> resolveArtworkImageProvider(
  String identity, {
  DirectoryMusicLibrary? directories,
}) async {
  if (identity.startsWith('local:')) return null;
  if (!identity.startsWith('directory:')) return AssetImage(identity);

  final id = Uri.decodeComponent(
    identity.substring('directory:'.length),
  );
  final track = directories?.track(id);
  if (directories == null || track == null) return null;

  final uri = await directories.artwork(track);
  if (uri == null || uri.isEmpty) return null;
  return FileImage(File.fromUri(Uri.parse(uri)));
}
