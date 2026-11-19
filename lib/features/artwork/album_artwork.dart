import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'directory_artwork.dart';
import 'pipeline/artwork_image.dart';
import 'source/artwork_image_resolver.dart';
import 'source/artwork_source.dart';

/// Public artwork entry point. Source resolution and rendering stay in their
/// own modules so callers do not need to know about providers or caches.
Widget albumArtwork(
  String asset, {
  double? width,
  double? height,
  BoxFit? fit,
  FilterQuality filterQuality = FilterQuality.medium,
  String? semanticLabel,
  bool excludeFromSemantics = false,
  bool xerox = false,
  double scale = 1,
}) {
  final source = ArtworkSource.parse(asset);
  if (source.isDirectory) {
    return DirectoryArtwork(
      identity: asset,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      xerox: xerox,
      scale: scale,
      filterQuality: filterQuality,
      placeholder: albumArtwork(
        'local:placeholder',
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }

  if (source.isPlaceholder) {
    return Semantics(
      label: excludeFromSemantics ? null : semanticLabel,
      excludeSemantics: excludeFromSemantics,
      child: SizedBox(
        width: width,
        height: height,
        child: const ColoredBox(
          color: Color(0xff292929),
          child: Center(
            child: Icon(
              PhosphorIcons.vinylRecord,
              color: Colors.white38,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }

  final image = const ArtworkImageResolver().providerFor(source);
  if (image == null) return const SizedBox.shrink();

  return ArtworkImage(
    identity: source.identity,
    sourceKey: source.cacheKey,
    image: image,
    width: width,
    height: height,
    fit: fit,
    filterQuality: filterQuality,
    semanticLabel: semanticLabel,
    excludeFromSemantics: excludeFromSemantics,
    xerox: xerox,
    scale: scale,
  );
}
