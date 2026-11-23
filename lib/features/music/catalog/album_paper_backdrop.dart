import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Keeps the cover, gradient and reused paper texture in one static layer.
class AlbumPaperBackdrop extends StatelessWidget {
  const AlbumPaperBackdrop({
    super.key,
    required this.artwork,
    required this.accent,
  });

  final Widget artwork;
  final Color? accent;

  static final _paper = _createPaper();

  @override
  Widget build(BuildContext context) {
    final hue = HSLColor.fromColor(accent ?? const Color(0xffb68b37));
    final ink = hue.withSaturation((hue.saturation * 0.72).clamp(0.0, 0.62));
    Color shade(double lightness, double alpha) =>
        ink.withLightness(lightness).withAlpha(alpha).toColor();

    return RepaintBoundary(
      child: ColoredBox(
        color: shade(0.095, 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            artwork,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  stops: const [0, 0.34, 1],
                  colors: [
                    shade(0.078, 0.96),
                    shade(0.104, 0.91),
                    shade(0.20, 0.63),
                  ],
                ),
              ),
            ),
            FutureBuilder<ui.ImageShader>(
              future: _paper,
              builder: (context, snapshot) {
                final shader = snapshot.data;
                return shader == null
                    ? const SizedBox.shrink()
                    : CustomPaint(painter: _PaperGrain(shader));
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<ui.ImageShader> _createPaper() {
  const side = 96;
  final pixels = Uint8List(side * side * 4);
  final random = Random(62);
  for (var offset = 0; offset < pixels.length; offset += 4) {
    final light = random.nextBool();
    final alpha = random.nextInt(light ? 25 : 78);
    // The raw RGBA texture uses premultiplied color channels.
    final value = light ? alpha : 0;
    pixels[offset] = value;
    pixels[offset + 1] = value;
    pixels[offset + 2] = value;
    pixels[offset + 3] = alpha;
  }
  final shader = Completer<ui.ImageShader>();
  ui.decodeImageFromPixels(pixels, side, side, ui.PixelFormat.rgba8888, (
    image,
  ) {
    shader.complete(
      ui.ImageShader(
        image,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        Matrix4.identity().storage,
        filterQuality: ui.FilterQuality.none,
      ),
    );
  });
  return shader.future;
}

class _PaperGrain extends CustomPainter {
  _PaperGrain(this.shader) : _paint = Paint()..shader = shader;

  final ui.ImageShader shader;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawRect(Offset.zero & size, _paint);

  @override
  bool shouldRepaint(_PaperGrain oldDelegate) => oldDelegate.shader != shader;
}
