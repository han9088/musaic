import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'directory_artwork.dart';
import 'artwork_image.dart';
import 'source/artwork_image_resolver.dart';
import 'source/artwork_source.dart';

/// Public artwork entry point. Source resolution is independent from rendering.
/// Converts a source reference into the appropriate artwork widget.
///
/// Directory references are resolved asynchronously; placeholders stay in the
/// presentation layer and never enter image decoding or Xerox processing.
/// Converts a source reference into the appropriate artwork widget.
/// Directory references resolve asynchronously; placeholders remain UI-only.
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
  // Parse once so the routing below does not depend on string-prefix checks.
  // Parse once so routing below uses typed source information.
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

  // A placeholder is UI, not an image source: do not create an ImageProvider.
  // A placeholder is presentation, not an image to decode or rasterize.
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
    sourceKey: image.toString(),
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
