import 'directory_artwork.dart';

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Keeps mock asset rendering unchanged; local albums currently have no artwork.
Widget albumArtwork(
  String asset, {
  double? width,
  double? height,
  BoxFit? fit,
  FilterQuality filterQuality = FilterQuality.medium,
  String? semanticLabel,
  bool excludeFromSemantics = false,
}) {
  if (asset.startsWith('directory:')) {
    return DirectoryArtwork(
      identity: asset,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: excludeFromSemantics ? null : semanticLabel,
      placeholder: albumArtwork(
        'local:placeholder',
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }
  if (!asset.startsWith('local:')) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
    );
  }
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
