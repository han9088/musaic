import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'artwork_image.dart';
import 'directory_artwork.dart';

/// Artwork entry point. Source resolution is independent from presentation.
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
  if (asset.startsWith('directory:')) {
    return DirectoryArtwork(
      identity: asset,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: excludeFromSemantics ? null : semanticLabel,
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

  final image = ArtworkImageResolver.resolve(asset);
  if (image == null) {
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

  return ArtworkImage(
    identity: asset,
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
