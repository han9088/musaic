part of 'xerox_artwork.dart';

class _XeroxPainter extends CustomPainter {
  const _XeroxPainter({
    required this.image,
    required this.shader,
    required this.fit,
    required this.identity,
    required this.config,
  });

  final ui.Image image;
  final ui.FragmentShader shader;
  final BoxFit fit;
  final String identity;
  final XeroxConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(fit, imageSize, size);
    final source = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & imageSize,
    );
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    if (destination.isEmpty) return;

    shader
      ..setFloat(0, image.width.toDouble())
      ..setFloat(1, image.height.toDouble())
      ..setFloat(2, source.left)
      ..setFloat(3, source.top)
      ..setFloat(4, source.width)
      ..setFloat(5, source.height)
      ..setFloat(6, destination.left)
      ..setFloat(7, destination.top)
      ..setFloat(8, destination.width)
      ..setFloat(9, destination.height)
      ..setFloat(10, xeroxSeed(identity).toDouble())
      ..setFloat(11, config.edge)
      ..setFloat(12, config.contrast)
      ..setFloat(13, config.grain)
      ..setFloat(14, config.invert ? 1 : 0)
      ..setImageSampler(0, image, filterQuality: FilterQuality.medium);
    canvas.drawRect(destination, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_XeroxPainter oldDelegate) =>
      image != oldDelegate.image ||
      shader != oldDelegate.shader ||
      fit != oldDelegate.fit ||
      identity != oldDelegate.identity ||
      config != oldDelegate.config;
}
