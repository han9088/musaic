import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class ArtworkPlaceholder extends StatelessWidget {
  const ArtworkPlaceholder.canvasTile({super.key});

  static const _background = Color(0xff292929);
  static const _icon = PhosphorIcons.vinylRecord;
  static const _iconColor = Colors.white38;
  static const _iconSize = 48.0;
  static final _tileBitmap = _rasterizeTile();

  static const standard = ColoredBox(
    color: _background,
    child: Center(
      child: Icon(_icon, color: _iconColor, size: _iconSize),
    ),
  );

  @override
  Widget build(BuildContext context) => RawImage(
    image: _tileBitmap,
    fit: BoxFit.fill,
    filterQuality: FilterQuality.low,
  );

  static ui.Image _rasterizeTile() {
    const pixels = 256;
    const artworkExtent = 100.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawColor(_background, BlendMode.src)
      ..scale(pixels / artworkExtent);
    final icon = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(_icon.codePoint),
        style: TextStyle(
          inherit: false,
          color: _iconColor,
          fontSize: _iconSize,
          fontFamily: _icon.fontFamily,
          package: _icon.fontPackage,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(
      canvas,
      Offset(
        (artworkExtent - icon.width) / 2,
        (artworkExtent - icon.height) / 2,
      ),
    );
    icon.dispose();
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(pixels, pixels);
    } finally {
      picture.dispose();
    }
  }
}
