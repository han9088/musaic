part of 'natural_rainbow.dart';

class _NaturalRainbowPainter extends CustomPainter {
  _NaturalRainbowPainter(this.animation, this.options, this.playing)
    : super(
        repaint: Listenable.merge([
          animation,
          if (options.sweepAngle != null) options.sweepAngle!,
          if (options.eraseAngle != null) options.eraseAngle!,
        ]),
      );

  final Animation<double> animation;
  final NaturalRainbow options;
  final bool playing;
  static const _featherSegments = 4;
  static const _bodySegments = 64;
  static const _columns = _bodySegments + 2 * _featherSegments + 1;
  static const _bodyEnd = _featherSegments + _bodySegments;

  Size? _size;
  late Rect _arc;
  late Path _fullArc;
  late List<({double radius, double weight})> _samples;
  late Float32List _positions;
  late Int32List _colors;
  late Uint16List _indices;
  final _strengths = List<double>.filled(3, 0);
  late List<Paint> _layers;
  late List<Int32List> _meshColors;
  late List<Paint> _meshPaints;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rawSweep = options.sweepAngle?.value ?? math.pi;
    if (!rawSweep.isFinite) return;
    final sweep = rawSweep.clamp(0.0, math.pi);
    final rawErase = options.eraseAngle?.value ?? 0;
    if (!rawErase.isFinite) return;
    final erased = rawErase.clamp(0.0, sweep);
    final remaining = sweep - erased;
    final t = animation.value;
    final visibility = playing
        ? _smooth(t / 0.28) * (1 - _smooth((t - 0.72) / 0.28))
        : _smooth(t);
    final breath = playing ? 0.99 + 0.01 * math.sin(t * math.pi * 4) : 1.0;
    final strength =
        (1 - math.exp(-2.1 * options.intensity * visibility)) * breath;
    if (strength <= 0 || remaining <= 0) return;
    if (_size != size) _prepareLayers(size);

    for (var layer = 0; layer < _layers.length; layer++) {
      _strengths[layer] =
          strength * (layer == 2 ? _smooth(visibility) : math.sqrt(visibility));
    }
    if (sweep == math.pi && erased == 0) {
      _drawFullArc(canvas);
      return;
    }

    final leftFeather = math.min(
      0.10,
      math.min(remaining * 0.3, (math.pi - sweep) * 0.8),
    );
    final rightFeather = math.min(
      0.10,
      math.min(remaining * 0.3, erased * 0.8),
    );
    for (var row = 0; row < _samples.length; row++) {
      final sample = _samples[row];
      final exponent = 0.90 + 0.34 * sample.weight;
      final start = -math.pi * math.pow(sweep / math.pi, exponent);
      final end = -math.pi * math.pow(erased / math.pi, exponent);
      final bodyStart = math.min(start + leftFeather, end);
      final bodyEnd = math.max(bodyStart, end - rightFeather);
      for (var column = 0; column < _columns; column++) {
        final double angle;
        if (column < _featherSegments) {
          angle = start + (bodyStart - start) * column / _featherSegments;
        } else if (column <= _bodyEnd) {
          angle =
              bodyStart +
              (bodyEnd - bodyStart) *
                  (column - _featherSegments) /
                  _bodySegments;
        } else {
          angle =
              bodyEnd +
              (end - bodyEnd) * (column - _bodyEnd) / _featherSegments;
        }
        final index = (row * _columns + column) * 2;
        _positions[index] = _arc.center.dx + sample.radius * math.cos(angle);
        _positions[index + 1] =
            _arc.center.dy + sample.radius * math.sin(angle);
      }
    }
    // Vertex colors avoid gradient/vertex-blend snapshots on Impeller.
    for (var layer = 0; layer < _layers.length; layer++) {
      final colors = _meshColors[layer];
      for (var i = 0; i < colors.length; i++) {
        final color = colors[i];
        final alpha = (((color >>> 24) & 0xFF) * _strengths[layer]).round();
        _colors[i] = (alpha << 24) | (color & 0xFFFFFF);
      }
      final vertices = ui.Vertices.raw(
        ui.VertexMode.triangles,
        _positions,
        colors: _colors,
        indices: _indices,
      );
      canvas.drawVertices(vertices, BlendMode.dst, _meshPaints[layer]);
      vertices.dispose();
    }
  }

  void _drawFullArc(Canvas canvas) {
    for (var layer = 0; layer < _layers.length; layer++) {
      final paint = _layers[layer];
      paint.color = Color.from(
        alpha: _strengths[layer],
        red: 1,
        green: 1,
        blue: 1,
      );
      canvas.drawPath(_fullArc, paint);
    }
  }

  void _prepareLayers(Size size) {
    _size = size;
    final fit = math.min(size.width / 2, size.height * 0.85);
    final width = options.thickness ?? fit * 0.315;
    final radius = options.radius ?? math.max(fit - width / 2, fit * 0.2);
    final center = Offset(size.width / 2, size.height);
    final outerRadius = radius + width * 4.8 * 1.15;
    _arc = Rect.fromCircle(center: center, radius: outerRadius);
    _fullArc = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(_arc, -math.pi, math.pi, false)
      ..close();
    // Include every spectral stop in each optical layer, so mesh interpolation
    // preserves the gradient instead of spreading the faint halo across the core.
    final radii = <double>{
      0,
      outerRadius,
      for (var i = 0; i <= 32; i++)
        math.max(0, radius + (i / 32 * 2.3 - 1.15) * width),
      for (final scale in [1.0, 2.1, 4.8])
        for (final position in [
          -0.65,
          for (var i = 1; i < 8; i++) -0.65 + i * 0.65 / 8,
          for (final sample in _spectrum) sample.position,
          for (var i = 1; i < 8; i++) 1 + i * 0.65 / 8,
          1.65,
        ])
          math.max(0, radius + (position - 0.5) * width * scale),
    }.toList()..sort();
    _samples = [
      for (final r in radii)
        (radius: r, weight: _smooth((r - radius) / width + 0.5)),
    ];
    _positions = Float32List(_samples.length * _columns * 2);
    _colors = Int32List(_samples.length * _columns);
    _indices = Uint16List((_samples.length - 1) * (_columns - 1) * 6);
    for (var row = 0; row < _samples.length; row++) {
      for (var column = 0; column < _columns; column++) {
        final fade = column < _featherSegments
            ? _smooth(column / _featherSegments)
            : 1 - _smooth((column - _bodyEnd) / _featherSegments);
        _colors[row * _columns + column] =
            (255 * fade).round() << 24 | 0xFFFFFF;
        if (row == _samples.length - 1 || column == _columns - 1) continue;
        final vertex = row * _columns + column;
        final index = (row * (_columns - 1) + column) * 6;
        _indices.setRange(index, index + 6, [
          vertex,
          vertex + 1,
          vertex + _columns,
          vertex + 1,
          vertex + _columns + 1,
          vertex + _columns,
        ]);
      }
    }
    _meshColors = [];
    _meshPaints = [];
    _layers = [
      _layer(
        center,
        radius,
        width * 4.8,
        0.018 * options.glowIntensity,
        0.99,
        BlendMode.screen,
      ),
      _layer(
        center,
        radius,
        width * 2.1,
        0.045 * options.glowIntensity,
        0.88,
        BlendMode.srcOver,
      ),
      _layer(center, radius, width, 0.98, 0, BlendMode.srcOver),
    ];
  }

  Paint _layer(
    Offset center,
    double radius,
    double width,
    double peak,
    double whiteMix,
    BlendMode blend,
  ) {
    final support = width * 1.15;
    final outerRadius = radius + support;
    final colors = <Color>[];
    final stops = <double>[];
    final sigma = 0.34 + options.softness * 0.12;

    void sample(double position, Color color, double sensitivity) {
      final distance = (position - 0.58) / sigma;
      // Ease the warm outer rim to zero before the gradient's final stop.
      final outerFade = 1 - _smooth((position - 0.80) / 0.85);
      final alpha =
          (peak *
                  math.exp(-0.5 * distance * distance) *
                  sensitivity *
                  outerFade)
              .clamp(0.0, 1.0);
      colors.add(
        Color.lerp(
          color,
          const Color(0xFFFFFFFF),
          whiteMix,
        )!.withValues(alpha: alpha),
      );
      stops.add(
        ((radius + (position - 0.5) * width) / outerRadius).clamp(0, 1),
      );
    }

    // Transparent tails retain the neighboring hue, preventing gray fringes.
    colors.add(_spectrum.first.color.withValues(alpha: 0));
    stops.add(math.max(0, radius - support) / outerRadius);
    for (var i = 1; i < 8; i++) {
      sample(
        -0.65 + i * 0.65 / 8,
        _spectrum.first.color,
        _spectrum.first.sensitivity,
      );
    }
    for (final samplePoint in _spectrum) {
      sample(samplePoint.position, samplePoint.color, samplePoint.sensitivity);
    }
    for (var i = 1; i < 8; i++) {
      sample(
        1 + i * 0.65 / 8,
        _spectrum.last.color,
        _spectrum.last.sensitivity,
      );
    }
    colors.add(_spectrum.last.color.withValues(alpha: 0));
    stops.add(1);
    final meshColors = Int32List(_colors.length);
    for (var row = 0; row < _samples.length; row++) {
      final position = _samples[row].radius / outerRadius;
      var stop = 0;
      while (stop < stops.length - 2 && stops[stop + 1] < position) {
        stop++;
      }
      final span = stops[stop + 1] - stops[stop];
      final t = span == 0
          ? 0.0
          : ((position - stops[stop]) / span).clamp(0.0, 1.0);
      final color = Color.lerp(colors[stop], colors[stop + 1], t)!;
      final rgb = color.toARGB32() & 0xFFFFFF;
      for (var column = 0; column < _columns; column++) {
        final index = row * _columns + column;
        final feather = (_colors[index] >>> 24) & 0xFF;
        meshColors[index] = ((color.a * feather).round() << 24) | rgb;
      }
    }
    _meshColors.add(meshColors);
    _meshPaints.add(Paint()..blendMode = blend);
    return Paint()
      ..style = PaintingStyle.fill
      ..blendMode = blend
      ..shader = ui.Gradient.radial(center, outerRadius, colors, stops);
  }

  @override
  bool shouldRepaint(_NaturalRainbowPainter oldDelegate) =>
      oldDelegate.options != options || oldDelegate.playing != playing;
}

double _smooth(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

// Uneven spectral stops preserve the broad warm rim and luminous green center.
const _spectrum = [
  (position: 0.00, color: Color(0xFF6551B8), sensitivity: 0.62),
  (position: 0.14, color: Color(0xFF3868D3), sensitivity: 0.78),
  (position: 0.27, color: Color(0xFF00A7DE), sensitivity: 0.90),
  (position: 0.38, color: Color(0xFF16C7B0), sensitivity: 0.96),
  (position: 0.48, color: Color(0xFF6CD85A), sensitivity: 1.00),
  (position: 0.59, color: Color(0xFFE6E63E), sensitivity: 1.00),
  (position: 0.67, color: Color(0xFFFFD64A), sensitivity: 1.00),
  (position: 0.78, color: Color(0xFFFFA047), sensitivity: 0.98),
  (position: 0.90, color: Color(0xFFEF6B57), sensitivity: 0.94),
  (position: 1.00, color: Color(0xFFD95676), sensitivity: 0.88),
];
