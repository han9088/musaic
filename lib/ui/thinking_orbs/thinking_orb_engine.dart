// 文件职责：思考光球的状态驱动、几何计算与绘制动画。

part of 'thinking_orb.dart';

// 移植自 thinking-orbs（MIT 许可证），版权所有 © 2026 Jakub Antalik。
// 此处尽可能保留原始 TypeScript 实现和经过调优的常量，
// 仅在 Dart/Flutter Canvas API 的能力范围内做必要适配。

/// 封装或定义modeopts相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
typedef _ModeOpts = Map<String, double>;
/// 封装或定义projector相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
typedef _Projector = _ProjectedPoint Function(double x, double y, double z);

/// 封装或定义光球mode相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
enum _OrbMode { orbits, globe, rubik, wave, web, braid, ribbon, ring, morph }

/// 封装或定义dot相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
class _Dot {
  const _Dot({
    required this.x,
    required this.y,
    required this.z,
    required this.radius,
    required this.white,
    this.alpha = 1,
  });

  final double x;
  final double y;
  final double z;
  final double radius;
  final double white;
  final double alpha;
}

/// 封装或定义光球line相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
class _OrbLine {
  const _OrbLine({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.white,
    required this.alpha,
    required this.width,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double white;
  final double alpha;
  final double width;
}

/// 封装或定义vec3相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
class _Vec3 {
  const _Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

/// 封装或定义projectedpoint相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
class _ProjectedPoint {
  const _ProjectedPoint(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

/// 封装或定义resolvedpreset相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
class _ResolvedPreset {
  const _ResolvedPreset(this.mode, this.speed, this.opts);

  final _OrbMode mode;
  final double speed;
  final _ModeOpts opts;
}

/// 封装或定义preset相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
class _Preset {
  const _Preset({
    required this.speed,
    required this.count,
    required this.size,
    this.extra = const {},
  });

  final double speed;
  final double count;
  final double size;
  final _ModeOpts extra;
}

/// 封装或定义思考光球绘制器相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
class _ThinkingOrbPainter extends CustomPainter {
  _ThinkingOrbPainter({
    required this.state,
    required this.presetSize,
    required this.dark,
    required this.initialTime,
    required this.speed,
    required this.paused,
    required this.reducedMotion,
    required this.sharedSeconds,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final ThinkingOrbState state;
  final ThinkingOrbSize presetSize;
  final bool dark;
  final double initialTime;
  final double speed;
  final bool paused;
  final bool reducedMotion;
  final double Function() sharedSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final preset = _resolvePreset(state, presetSize);
    final time = reducedMotion
        ? 0.6
        : paused
        ? initialTime * preset.speed
        : sharedSeconds() * speed * preset.speed;
    _drawMode(canvas, size.shortestSide, time, dark, preset);
  }

  @override
  bool shouldRepaint(_ThinkingOrbPainter oldDelegate) {
    return state != oldDelegate.state ||
        presetSize != oldDelegate.presetSize ||
        dark != oldDelegate.dark ||
        initialTime != oldDelegate.initialTime ||
        speed != oldDelegate.speed ||
        paused != oldDelegate.paused ||
        reducedMotion != oldDelegate.reducedMotion;
  }
}

double _o(_ModeOpts opts, String key, double fallback) => opts[key] ?? fallback;

double _lerp(double a, double b, double f) => a + (b - a) * f;

double _frac(double x) => x - x.floorToDouble();

double _hashD(double a, double b) {
  final h = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return h - h.floorToDouble();
}

double _vnoise(double x, double y) {
  final xi = x.floor();
  final yi = y.floor();
  var fx = x - xi;
  var fy = y - yi;
  fx = fx * fx * (3 - 2 * fx);
  fy = fy * fy * (3 - 2 * fy);
  final a = _hashD(xi.toDouble(), yi.toDouble());
  final b = _hashD((xi + 1).toDouble(), yi.toDouble());
  final c = _hashD(xi.toDouble(), (yi + 1).toDouble());
  final d = _hashD((xi + 1).toDouble(), (yi + 1).toDouble());
  return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
}

_Vec3 _fibDir(int i, int n) {
  final golden = math.pi * (3 - math.sqrt(5));
  final y = 1 - (2 * (i + 0.5)) / n;
  final radius = math.sqrt(1 - y * y);
  final angle = i * golden;
  return _Vec3(radius * math.cos(angle), y, radius * math.sin(angle));
}

double _angleDelta(double a, double b) =>
    math.atan2(math.sin(a - b), math.cos(a - b));

_Projector _makeProjector(
  double yaw,
  double tilt,
  double centerX,
  double centerY,
  double scale,
) {
  final sinTilt = math.sin(tilt);
  final cosTilt = math.cos(tilt);
  final sinYaw = math.sin(yaw);
  final cosYaw = math.cos(yaw);
  return (x, y, z) {
    final x1 = x * cosYaw + z * sinYaw;
    final z1 = -x * sinYaw + z * cosYaw;
    final y1 = y * cosTilt - z1 * sinTilt;
    final z2 = y * sinTilt + z1 * cosTilt;
    return _ProjectedPoint(centerX + x1 * scale, centerY - y1 * scale, z2);
  };
}

double _radiusScale(double size, double power) =>
    math.pow(size / 300, power).toDouble();

Color _inkColor(bool dark, double white, double alpha) {
  final clampedWhite = white.clamp(0.0, 1.0);
  final gray = ((dark ? 1 - clampedWhite : clampedWhite) * 255).round();
  return Color.fromRGBO(gray, gray, gray, alpha.clamp(0.0, 1.0));
}

/// 执行对应内容的绘制或渲染，用于思考光球的状态驱动、几何计算与绘制动画。
void _paintDots(
  Canvas canvas,
  List<_Dot> dots,
  bool dark, [
  double radiusMin = 0.3,
]) {
  dots.sort((a, b) => a.z.compareTo(b.z));
  final paint = Paint()..style = PaintingStyle.fill;
  for (final dot in dots) {
    if (dot.alpha < 0.02) continue;
    paint.color = _inkColor(dark, dot.white, dot.alpha);
    canvas.drawCircle(
      Offset(dot.x, dot.y),
      math.max(radiusMin, dot.radius),
      paint,
    );
  }
}

/// 执行对应内容的绘制或渲染，用于思考光球的状态驱动、几何计算与绘制动画。
void _paintLines(Canvas canvas, List<_OrbLine> lines, bool dark) {
  final paint = Paint()..style = PaintingStyle.stroke;
  for (final line in lines) {
    if (line.alpha < 0.02) continue;
    paint
      ..color = _inkColor(dark, line.white, line.alpha)
      ..strokeWidth = line.width;
    canvas.drawLine(Offset(line.x1, line.y1), Offset(line.x2, line.y2), paint);
  }
}

/// 执行对应内容的绘制或渲染，用于思考光球的状态驱动、几何计算与绘制动画。
void _drawMode(
  Canvas canvas,
  double size,
  double time,
  bool dark,
  _ResolvedPreset preset,
) {
  switch (preset.mode) {
    case _OrbMode.orbits:
      _drawOrbits(canvas, size, time, dark, preset.opts);
    case _OrbMode.globe:
      _drawGlobe(canvas, size, time, dark, preset.opts);
    case _OrbMode.rubik:
      _drawRubik(canvas, size, time, dark, preset.opts);
    case _OrbMode.wave:
      _drawWave(canvas, size, time, dark, preset.opts);
    case _OrbMode.web:
      _drawWeb(canvas, size, time, dark, preset.opts);
    case _OrbMode.braid:
      _drawBraid(canvas, size, time, dark, preset.opts);
    case _OrbMode.ribbon:
    case _OrbMode.ring:
      _drawRibbon(canvas, size, time, dark, preset.opts);
    case _OrbMode.morph:
      _drawMorph(canvas, size, time, dark, preset.opts);
  }
}

/// 执行对应内容的绘制或渲染，用于思考光球的状态驱动、几何计算与绘制动画。
void _drawOrbits(
  Canvas canvas,
  double size,
  double time,
  bool dark,
  _ModeOpts opts,
) {
  final center = size / 2;
  final radius = center * 0.82;
  final project = _makeProjector(time * 0.12, 0.3, center, center, 1);
  final radiusScale = _radiusScale(size, _o(opts, 'rsPow', 0.6));
  final orbitCount = _o(opts, 'orbitN', 12).round();
  final ghostCount = _o(opts, 'ghostN', 40).round();
  final particleCount = _o(opts, 'particles', 3).round();
  final dots = <_Dot>[];

  for (var orbit = 0; orbit < orbitCount; orbit++) {
    final h1 = _hashD(orbit.toDouble(), 1.7);
    final h2 = _hashD(orbit.toDouble(), 5.2);
    final h3 = _hashD(orbit.toDouble(), 8.9);
    final orbitRadius = radius * (0.45 + 0.52 * h1);
    final theta = h1 * 2 * math.pi;
    final phi = math.acos(2 * h2 - 1);
    final nx = math.sin(phi) * math.cos(theta);
    final ny = math.cos(phi);
    final nz = math.sin(phi) * math.sin(theta);
    var ux = -ny;
    var uy = nx;
    const uz = 0.0;
    final unitLength = math.max(1e-6, math.sqrt(ux * ux + uy * uy));
    ux /= unitLength;
    uy /= unitLength;
    final vx = ny * uz - nz * uy;
    final vy = nz * ux - nx * uz;
    final vz = nx * uy - ny * ux;
    final particleSpeed = (0.25 + 0.55 * h3) * (h3 > 0.5 ? 1 : -1);

    for (var index = 0; index < ghostCount; index++) {
      final angle = (index / ghostCount) * 2 * math.pi;
      final cosAngle = math.cos(angle);
      final sinAngle = math.sin(angle);
      final point = project(
        (ux * cosAngle + vx * sinAngle) * orbitRadius,
        (uy * cosAngle + vy * sinAngle) * orbitRadius,
        (uz * cosAngle + vz * sinAngle) * orbitRadius,
      );
      final depth = (point.z / orbitRadius + 1) / 2;
      dots.add(
        _Dot(
          x: point.x,
          y: point.y,
          z: point.z,
          radius: _o(opts, 'ghostR', 0.9) * radiusScale,
          white: 0.72,
          alpha: _o(opts, 'ghostA', 0.5) * (0.4 + 0.6 * depth),
        ),
      );
    }

    for (var particle = 0; particle < particleCount; particle++) {
      final angle =
          time * particleSpeed +
          (particle / particleCount) * 2 * math.pi +
          h2 * 6;
      final cosAngle = math.cos(angle);
      final sinAngle = math.sin(angle);
      final point = project(
        (ux * cosAngle + vx * sinAngle) * orbitRadius,
        (uy * cosAngle + vy * sinAngle) * orbitRadius,
        (uz * cosAngle + vz * sinAngle) * orbitRadius,
      );
      final depth = (point.z / orbitRadius + 1) / 2;
      dots.add(
        _Dot(
          x: point.x,
          y: point.y,
          z: point.z,
          radius:
              (_o(opts, 'partR', 1.2) + _o(opts, 'partRDepth', 1.6) * depth) *
              radiusScale,
          white: 0.3 - 0.22 * depth,
        ),
      );
    }
  }
  _paintDots(canvas, dots, dark, _o(opts, 'rMin', 0.3));
}

/// 执行对应内容的绘制或渲染，用于思考光球的状态驱动、几何计算与绘制动画。
void _drawGlobe(
  Canvas canvas,
  double size,
  double time,
  bool dark,
  _ModeOpts opts,
) {
  const spin = 0.5;
  final center = size / 2;
  final radius = center * 0.82;
  final tilt = 0.4 + 0.06 * math.sin(time * 0.35);
  final project = _makeProjector(time * spin, tilt, center, center, radius);
  final scan = time * (spin + (1.7 - spin) * _o(opts, 'scanMul', 1));
  final radiusScale = _radiusScale(size, _o(opts, 'rsPow', 0.6));
  final dimBase = _o(opts, 'dimBase', 1);
  final latitudeRings = _o(opts, 'latRings', 17).round();
  final longitudeDensity = _o(opts, 'lonDensity', 44).round();
  final dots = <_Dot>[];

  for (var latitudeIndex = 0; latitudeIndex <= latitudeRings; latitudeIndex++) {
    final latitude = -math.pi / 2 + (latitudeIndex / latitudeRings) * math.pi;
    final cosLatitude = math.cos(latitude);
    final sinLatitude = math.sin(latitude);
    final longitudeCount = math.max(
      1,
      (cosLatitude.abs() * longitudeDensity).round(),
    );
    for (
      var longitudeIndex = 0;
      longitudeIndex < longitudeCount;
      longitudeIndex++
    ) {
      final longitude = (longitudeIndex / longitudeCount) * 2 * math.pi;
      final point = project(
        cosLatitude * math.cos(longitude),
        sinLatitude,
        cosLatitude * math.sin(longitude),
      );
      final depth = (point.z + 1) / 2;
      final distance = _angleDelta(longitude + time * spin, scan);
      final boost =
          math.exp(-(distance * distance) / 0.18) * math.max(0, point.z);
      dots.add(
        _Dot(
          x: point.x,
          y: point.y,
          z: point.z,
          radius:
              (_o(opts, 'rBase', 0.6) +
                  _o(opts, 'rDepth', 1.7) * depth +
                  _o(opts, 'rBoost', 1) * boost) *
              radiusScale,
          white: _o(opts, 'inkFar', 0.62) - _o(opts, 'inkSpan', 0.54) * depth,
          alpha: dimBase + (1 - dimBase) * math.min(1, boost),
        ),
      );
    }
  }
  _paintDots(canvas, dots, dark, _o(opts, 'rMin', 0.3));
}

/// 封装或定义rubikmove相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
class _RubikMove {
  const _RubikMove(this.axis, this.low, this.high, this.angle);

  final int axis;
  final double low;
  final double high;
  final double angle;
}

/// 封装或定义solvecycle相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
class _SolveCycle {
  const _SolveCycle(this.amount, this.active);

  final List<double> amount;
  final int active;
}

/// 封装或定义movedpoint相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
class _MovedPoint {
  const _MovedPoint(this.point, this.active);

  final _Vec3 point;
  final bool active;
}

_SolveCycle _solveCycle(
  double time,
  int count,
  double slotDuration,
  double rest,
) {
  final cycle = 2 * count * slotDuration + rest;
  final cycleTime = time % cycle;
  final amount = List<double>.filled(count, 0);
  var active = -1;
  if (cycleTime < 2 * count * slotDuration) {
    final slot = (cycleTime / slotDuration).floor();
    final progress = (cycleTime - slot * slotDuration) / slotDuration;
    final clamped = math.min(1, progress / 0.7);
    final eased = 1 - math.pow(1 - clamped, 3);
    if (slot < count) {
      for (var index = 0; index < slot; index++) {
        amount[index] = 1;
      }
      amount[slot] = eased.toDouble();
      active = slot;
    } else {
      final undo = 2 * count - 1 - slot;
      for (var index = 0; index < undo; index++) {
        amount[index] = 1;
      }
      amount[undo] = 1 - eased.toDouble();
      active = undo;
    }
  }
  return _SolveCycle(amount, active);
}

List<_RubikMove> _makeMoves(int count) {
  return List.generate(count, (index) {
    final axis = math.min(2, (_hashD(index.toDouble(), 2.3) * 3).floor());
    final low =
        -1 + 0.5 * math.min(3, (_hashD(index.toDouble(), 5.9) * 4).floor());
    final direction = _hashD(index.toDouble(), 7.7) < 0.5 ? 1 : -1;
    return _RubikMove(axis, low, low + 0.5, direction * math.pi / 2);
  });
}

_MovedPoint _applyMoves(
  _Vec3 input,
  List<_RubikMove> moves,
  _SolveCycle cycle,
) {
  var x = input.x;
  var y = input.y;
  var z = input.z;
  var inActive = false;
  for (var index = 0; index < moves.length; index++) {
    if (cycle.amount[index] <= 0) continue;
    final move = moves[index];
    final coordinate = move.axis == 0 ? x : (move.axis == 1 ? y : z);
    if (coordinate < move.low || coordinate >= move.high) continue;
    if (index == cycle.active) inActive = true;
    final angle = move.angle * cycle.amount[index];
    final cosAngle = math.cos(angle);
    final sinAngle = math.sin(angle);
    if (move.axis == 0) {
      final y2 = y * cosAngle - z * sinAngle;
      z = y * sinAngle + z * cosAngle;
      y = y2;
    } else if (move.axis == 1) {
      final x2 = x * cosAngle + z * sinAngle;
      z = -x * sinAngle + z * cosAngle;
      x = x2;
    } else {
      final x2 = x * cosAngle - y * sinAngle;
      y = x * sinAngle + y * cosAngle;
      x = x2;
    }
  }
  return _MovedPoint(_Vec3(x, y, z), inActive);
}

/// 执行对应内容的绘制或渲染，用于思考光球的状态驱动、几何计算与绘制动画。
void _drawRubik(
  Canvas canvas,
  double size,
  double time,
  bool dark,
  _ModeOpts opts,
) {
  final center = size / 2;
  final radius = center * 0.82;
  final project = _makeProjector(
    time * 0.55,
    0.35 + 0.1 * math.sin(time * 0.9),
    center,
    center,
    radius,
  );
  final radiusScale = _radiusScale(size, _o(opts, 'rsPow', 0.6));
  final moveCount = _o(opts, 'moveCount', 14).round();
  final moves = _makeMoves(moveCount);
  final cycle = _solveCycle(time, moveCount, 0.42, 1.2);
  final latitudeRings = _o(opts, 'latRings', 15).round();
  final longitudeDensity = _o(opts, 'lonDensity', 40).round();
  final dots = <_Dot>[];

  for (var latitudeIndex = 0; latitudeIndex <= latitudeRings; latitudeIndex++) {
    final latitude = -math.pi / 2 + (latitudeIndex / latitudeRings) * math.pi;
    final cosLatitude = math.cos(latitude);
    final sinLatitude = math.sin(latitude);
    final longitudeCount = math.max(
      1,
      (cosLatitude.abs() * longitudeDensity).round(),
    );
    for (
      var longitudeIndex = 0;
      longitudeIndex < longitudeCount;
      longitudeIndex++
    ) {
      final longitude = (longitudeIndex / longitudeCount) * 2 * math.pi;
      final moved = _applyMoves(
        _Vec3(
          cosLatitude * math.cos(longitude),
          sinLatitude,
          cosLatitude * math.sin(longitude),
        ),
        moves,
        cycle,
      );
      final point = project(moved.point.x, moved.point.y, moved.point.z);
      final depth = (point.z + 1) / 2;
      dots.add(
        _Dot(
          x: point.x,
          y: point.y,
          z: point.z,
          radius:
              (_o(opts, 'rBase', 0.6) +
                  _o(opts, 'rDepth', 1.7) * depth +
                  (moved.active ? _o(opts, 'rActive', 0.3) : 0)) *
              radiusScale,
          white:
              _o(opts, 'inkFar', 0.62) -
              _o(opts, 'inkSpan', 0.54) * depth -
              (moved.active ? 0.14 : 0),
        ),
      );
    }
  }
  _paintDots(canvas, dots, dark, _o(opts, 'rMin', 0.3));
}

/// 执行对应内容的绘制或渲染，用于思考光球的状态驱动、几何计算与绘制动画。
void _drawWave(
  Canvas canvas,
  double size,
  double time,
  bool dark,
  _ModeOpts opts,
) {
  final center = size / 2;
  final radius = center * 0.874;
  final project = _makeProjector(time * 0.18, 0.38, center, center, 1);
  final radiusScale = _radiusScale(size, _o(opts, 'rsPow', 0.6));
  final rings = _o(opts, 'rings', 15).round();
  final longitudeDensity = _o(opts, 'lonDensity', 40).round();
  final dots = <_Dot>[];

  for (var ring = 0; ring <= rings; ring++) {
    final latitude = -math.pi / 2 + (ring / rings) * math.pi;
    final cosLatitude = math.cos(latitude);
    final sinLatitude = math.sin(latitude);
    final wave =
        0.62 * math.sin(time * 2.1 - ring * 0.52) +
        0.38 * math.sin(time * 1.27 + ring * 0.83);
    final ringRadius = radius * (0.88 + 0.105 * wave);
    final longitudeCount = math.max(
      1,
      (cosLatitude.abs() * longitudeDensity).round(),
    );
    for (
      var longitudeIndex = 0;
      longitudeIndex < longitudeCount;
      longitudeIndex++
    ) {
      final longitude = (longitudeIndex / longitudeCount) * 2 * math.pi;
      final point = project(
        cosLatitude * math.cos(longitude) * ringRadius,
        sinLatitude * ringRadius,
        cosLatitude * math.sin(longitude) * ringRadius,
      );
      final depth = (point.z / radius + 1) / 2;
      final crest = math.max(0, wave);
      dots.add(
        _Dot(
          x: point.x,
          y: point.y,
          z: point.z,
          radius:
              (_o(opts, 'rBase', 0.6) + _o(opts, 'rDepth', 1.7) * depth) *
              (1 + 0.4 * crest) *
              radiusScale,
          white: 0.66 - 0.56 * depth - 0.1 * crest,
        ),
      );
    }
  }
  _paintDots(canvas, dots, dark, _o(opts, 'rMin', 0.3));
}

/// 执行对应内容的绘制或渲染，用于思考光球的状态驱动、几何计算与绘制动画。
void _drawWeb(
  Canvas canvas,
  double size,
  double time,
  bool dark,
  _ModeOpts opts,
) {
  final center = size / 2;
  final radius = center * 0.8 * _o(opts, 'spread', 1);
  final project = _makeProjector(time * 0.12, 0.32, center, center, radius);
  final radiusScale = _radiusScale(size, _o(opts, 'rsPow', 0.6));
  final nodeCount = _o(opts, 'nodeN', 30).round();
  final threshold = _o(opts, 'thr', 0.72);
  final nodeRadius = _o(opts, 'nodeR', 1.4);
  final nodeRadiusDepth = _o(opts, 'nodeRDepth', 1.8);
  final nodes = <_Vec3>[];

  for (var index = 0; index < nodeCount; index++) {
    final direction = _fibDir(index, nodeCount);
    final x =
        direction.x + 0.3 * (_vnoise(index * 0.31 + 9, time * 0.24) - 0.5) * 2;
    final y =
        direction.y + 0.3 * (_vnoise(index * 0.53 + 27, time * 0.21) - 0.5) * 2;
    final z =
        direction.z + 0.3 * (_vnoise(index * 0.77 + 55, time * 0.27) - 0.5) * 2;
    final length = math.sqrt(x * x + y * y + z * z);
    nodes.add(_Vec3(x / length, y / length, z / length));
  }

  final lines = <_OrbLine>[];
  final dots = <_Dot>[];
  for (var first = 0; first < nodeCount; first++) {
    for (var second = first + 1; second < nodeCount; second++) {
      final dx = nodes[first].x - nodes[second].x;
      final dy = nodes[first].y - nodes[second].y;
      final dz = nodes[first].z - nodes[second].z;
      final distance = math.sqrt(dx * dx + dy * dy + dz * dz);
      if (distance >= threshold) continue;
      final p1 = project(nodes[first].x, nodes[first].y, nodes[first].z);
      final p2 = project(nodes[second].x, nodes[second].y, nodes[second].z);
      final depth = ((p1.z + p2.z) / 2 + 1) / 2;
      lines.add(
        _OrbLine(
          x1: p1.x,
          y1: p1.y,
          x2: p2.x,
          y2: p2.y,
          white: 0.42,
          alpha: (1 - distance / threshold) * (0.3 + 0.55 * depth),
          width: math.max(0.6, _o(opts, 'lineW', 0.8) * radiusScale),
        ),
      );
    }
  }

  for (var index = 0; index < nodeCount; index++) {
    final point = project(nodes[index].x, nodes[index].y, nodes[index].z);
    final depth = (point.z + 1) / 2;
    final pulse = 1 + 0.25 * math.sin(time * 1.4 + index * 2.7);
    dots.add(
      _Dot(
        x: point.x,
        y: point.y,
        z: point.z,
        radius: (nodeRadius + nodeRadiusDepth * depth) * pulse * radiusScale,
        white: 0.55 - 0.45 * depth,
      ),
    );
  }

  final signalCount = _o(opts, 'signals', 5).round();
  for (var signal = 0; signal < signalCount; signal++) {
    final segment = (time * 0.55 + signal * 7.31).floor();
    final first = (_hashD(segment.toDouble(), signal * 3.1 + 1.7) * nodeCount)
        .floor();
    final second = (_hashD(segment.toDouble(), signal * 5.7 + 4.2) * nodeCount)
        .floor();
    if (first == second) continue;
    final progress = _frac(time * 0.55 + signal * 7.31);
    final x = _lerp(nodes[first].x, nodes[second].x, progress);
    final y = _lerp(nodes[first].y, nodes[second].y, progress);
    final z = _lerp(nodes[first].z, nodes[second].z, progress);
    final length = math.max(1e-6, math.sqrt(x * x + y * y + z * z));
    final point = project(x / length, y / length, z / length);
    final depth = (point.z + 1) / 2;
    dots.add(
      _Dot(
        x: point.x,
        y: point.y,
        z: point.z,
        radius: (nodeRadius * 1.5 + nodeRadiusDepth * depth) * radiusScale,
        white: 0.05,
        alpha: 0.5 + 0.5 * depth,
      ),
    );
  }

  _paintLines(canvas, lines, dark);
  _paintDots(canvas, dots, dark, _o(opts, 'rMin', 0.3));
}

/// 执行对应内容的绘制或渲染，用于思考光球的状态驱动、几何计算与绘制动画。
void _drawBraid(
  Canvas canvas,
  double size,
  double time,
  bool dark,
  _ModeOpts opts,
) {
  final center = size / 2;
  final radius = center * 0.76;
  final project = _makeProjector(time * 0.4, 0.3, center, center, 1);
  final radiusScale = _radiusScale(size, _o(opts, 'rsPow', 0.6));
  final dots = <_Dot>[];
  final ghostCount = _o(opts, 'ghostN', 150).round();

  for (var index = 0; index < ghostCount; index++) {
    final direction = _fibDir(index, ghostCount);
    final point = project(
      direction.x * radius,
      direction.y * radius,
      direction.z * radius,
    );
    final depth = (point.z / radius + 1) / 2;
    dots.add(
      _Dot(
        x: point.x,
        y: point.y,
        z: point.z,
        radius: 0.8 * radiusScale,
        white: 0.78,
        alpha: 0.1 + 0.22 * depth,
      ),
    );
  }

  final strandCount = _o(opts, 'strandN', 52).round();
  final turns = _o(opts, 'turns', 3);
  for (var strand = 0; strand < 3; strand++) {
    final phase = (strand / 3) * 2 * math.pi;
    for (var index = 0; index < strandCount; index++) {
      final u = (_frac(index / strandCount + time * 0.045) * 2 - 1) * 0.96;
      final surface = math.sqrt(math.max(0, 1 - u * u));
      final endFade = math.min(1, (1 - u.abs()) / 0.1);
      final angle = u * math.pi * turns + phase;
      final weave =
          1 +
          0.075 * math.sin(u * math.pi * turns * 2 + phase * 2 + time * 0.8);
      final ringRadius = surface * radius * weave;
      final point = project(
        math.cos(angle) * ringRadius,
        u * radius * weave,
        math.sin(angle) * ringRadius,
      );
      final depth = (point.z / radius + 1) / 2;
      dots.add(
        _Dot(
          x: point.x,
          y: point.y,
          z: point.z,
          radius:
              (_o(opts, 'rBase', 1.2) + _o(opts, 'rDepth', 1.8) * depth) *
              radiusScale,
          white: 0.55 - 0.45 * depth,
          alpha: endFade * (0.45 + 0.55 * depth),
        ),
      );
    }
  }
  _paintDots(canvas, dots, dark, _o(opts, 'rMin', 0.3));
}

/// 执行对应内容的绘制或渲染，用于思考光球的状态驱动、几何计算与绘制动画。
void _drawRibbon(
  Canvas canvas,
  double size,
  double time,
  bool dark,
  _ModeOpts opts,
) {
  final center = size / 2;
  final radius = center * 0.78;
  final spin = _o(opts, 'spin', 1);
  const cameraTilt = 0.3;
  final project = _makeProjector(
    time * 0.1 * spin,
    cameraTilt,
    center,
    center,
    1,
  );
  final radiusScale = _radiusScale(size, _o(opts, 'rsPow', 0.6));
  final dots = <_Dot>[];
  final ghostCount = _o(opts, 'ghostN', 150).round();
  for (var index = 0; index < ghostCount; index++) {
    final direction = _fibDir(index, ghostCount);
    final point = project(
      direction.x * radius,
      direction.y * radius,
      direction.z * radius,
    );
    final depth = (point.z / radius + 1) / 2;
    dots.add(
      _Dot(
        x: point.x,
        y: point.y,
        z: point.z,
        radius: 0.8 * radiusScale,
        white: 0.78,
        alpha: 0.1 + 0.22 * depth,
      ),
    );
  }

  final yawAngle = time * 0.24 * spin;
  final faceOn = _o(opts, 'faceOn', 0) != 0;
  final tiltAngle = faceOn
      ? -cameraTilt
      : 0.55 + 0.3 * math.sin(time * 0.18) * spin;
  final ux = math.cos(yawAngle);
  const uy = 0.0;
  final uz = math.sin(yawAngle);
  final vx = -uz * math.sin(tiltAngle);
  final vy = math.cos(tiltAngle);
  final vz = ux * math.sin(tiltAngle);
  final nx = uy * vz - uz * vy;
  final ny = uz * vx - ux * vz;
  final nz = ux * vy - uy * vx;

  final wobbleMultiplier = _o(opts, 'wobMul', 1);
  final wobbleAmplitude = 0.23 * wobbleMultiplier;
  final baseRadius = faceOn ? radius / (1 + 0.85 * wobbleAmplitude) : radius;
  final baseLanes = _o(opts, 'lanes', 5);
  final segments = _o(opts, 'segs', 88).round();
  final lanes = math.max(1, (baseLanes * _o(opts, 'bandMul', 1)).round());
  for (var lane = 0; lane < lanes; lane++) {
    final laneOffset = (lane - (lanes - 1) / 2) * 0.075;
    final edge = (lane - (lanes - 1) / 2).abs() / math.max(1, (lanes - 1) / 2);
    for (var segment = 0; segment < segments; segment++) {
      final angle = (segment / segments) * 2 * math.pi;
      final wobble =
          (0.16 * math.sin(angle * 3 - time * 1.7 + lane * 0.22) +
              0.07 * math.sin(angle * 5 + time * 1.1)) *
          wobbleMultiplier;
      final radial = faceOn ? 1 + wobble : 1.0;
      final offset = faceOn ? laneOffset : laneOffset + wobble;
      final x = ux * math.cos(angle) + vx * math.sin(angle) + nx * offset;
      final y = uy * math.cos(angle) + vy * math.sin(angle) + ny * offset;
      final z = uz * math.cos(angle) + vz * math.sin(angle) + nz * offset;
      final length = math.sqrt(x * x + y * y + z * z);
      final ringRadius = baseRadius * radial;
      final point = project(
        (x / length) * ringRadius,
        (y / length) * ringRadius,
        (z / length) * ringRadius,
      );
      final depth = (point.z / radius + 1) / 2;
      dots.add(
        _Dot(
          x: point.x,
          y: point.y,
          z: point.z,
          radius:
              (_o(opts, 'rBase', 1.1) + _o(opts, 'rDepth', 1.7) * depth) *
              (1 - 0.25 * edge) *
              radiusScale,
          white: 0.52 - 0.44 * depth + 0.18 * edge,
          alpha: 0.4 + 0.6 * depth,
        ),
      );
    }
  }
  _paintDots(canvas, dots, dark, _o(opts, 'rMin', 0.3));
}

/// 封装或定义pathsampler相关类型与行为，负责思考光球的状态驱动、几何计算与绘制动画。
typedef _PathSampler = Offset Function(double fraction);

double _smoothEase(double value) => value * value * (3 - 2 * value);

_PathSampler _polygonPath(List<Offset> vertices) {
  final lengths = <double>[];
  var total = 0.0;
  for (var index = 0; index < vertices.length; index++) {
    final length =
        (vertices[(index + 1) % vertices.length] - vertices[index]).distance;
    lengths.add(length);
    total += length;
  }
  return (fraction) {
    var target = fraction * total;
    var index = 0;
    while (target > lengths[index] && index < vertices.length - 1) {
      target -= lengths[index];
      index++;
    }
    final first = vertices[index];
    final second = vertices[(index + 1) % vertices.length];
    final progress = lengths[index] == 0
        ? 0.0
        : math.min(1.0, target / lengths[index]);
    return Offset(
      _lerp(first.dx, second.dx, progress),
      _lerp(first.dy, second.dy, progress),
    );
  };
}

Offset _circlePath(double fraction) {
  final angle = -math.pi / 2 + fraction * 2 * math.pi;
  return Offset(math.cos(angle) * 0.24, math.sin(angle) * 0.24);
}

final _PathSampler _trianglePath = _polygonPath(const [
  Offset(0, -0.26),
  Offset(0.24, 0.16),
  Offset(-0.24, 0.16),
]);

final _PathSampler _squarePath = _polygonPath(const [
  Offset(0, -0.2),
  Offset(0.2, -0.2),
  Offset(0.2, 0.2),
  Offset(-0.2, 0.2),
  Offset(-0.2, -0.2),
]);

/// 执行对应内容的绘制或渲染，用于思考光球的状态驱动、几何计算与绘制动画。
void _drawMorph(
  Canvas canvas,
  double size,
  double time,
  bool dark,
  _ModeOpts opts,
) {
  final paths = [_circlePath, _trianglePath, _squarePath];
  const hold = 1.4;
  const morph = 0.9;
  const segmentDuration = hold + morph;
  final cycleTime = time % (segmentDuration * paths.length);
  final pathIndex = (cycleTime / segmentDuration).floor();
  final localTime = cycleTime - pathIndex * segmentDuration;
  final blend = localTime > hold
      ? _smoothEase((localTime - hold) / morph)
      : 0.0;
  final spread = _o(opts, 'spread', 1);
  final firstPath = paths[pathIndex];
  final secondPath = paths[(pathIndex + 1) % paths.length];
  const sampleCount = 160;
  final points = <Offset>[];
  for (var index = 0; index < sampleCount; index++) {
    final fraction = index / sampleCount;
    final first = firstPath(fraction);
    final second = secondPath(fraction);
    points.add(
      Offset(
        _lerp(first.dx, second.dx, blend) * spread,
        _lerp(first.dy, second.dy, blend) * spread,
      ),
    );
  }

  final lengths = <double>[];
  var total = 0.0;
  for (var index = 0; index < sampleCount; index++) {
    final length = (points[(index + 1) % sampleCount] - points[index]).distance;
    lengths.add(length);
    total += length;
  }

  final dotCount = math.max(6, (34 * _o(opts, 'iconD', 1)).round());
  final radius = _o(opts, 'rDot', 0.021) * 1.35 * spread;
  final pulse = 1 + 0.02 * math.sin(localTime * 3.1);
  final dots = <_Dot>[];
  final center = size / 2;
  var segment = 0;
  var accumulated = 0.0;
  for (var dot = 0; dot < dotCount; dot++) {
    final target = (dot / dotCount) * total;
    while (accumulated + lengths[segment] < target &&
        segment < sampleCount - 1) {
      accumulated += lengths[segment];
      segment++;
    }
    final first = points[segment];
    final second = points[(segment + 1) % sampleCount];
    final progress = lengths[segment] == 0
        ? 0.0
        : math.min(1.0, (target - accumulated) / lengths[segment]);
    final x = _lerp(first.dx, second.dx, progress) * pulse;
    final y = _lerp(first.dy, second.dy, progress) * pulse;
    dots.add(
      _Dot(
        x: center + x * size,
        y: center + y * size,
        z: 0,
        radius: math.max(0.35, radius * size),
        white: 0.1,
      ),
    );
  }
  _paintDots(canvas, dots, dark, _o(opts, 'rMin', 0.25));
}

_OrbMode _modeFor(ThinkingOrbState state) => switch (state) {
  ThinkingOrbState.working => _OrbMode.orbits,
  ThinkingOrbState.searching => _OrbMode.globe,
  ThinkingOrbState.solving => _OrbMode.rubik,
  ThinkingOrbState.listening => _OrbMode.wave,
  ThinkingOrbState.connecting => _OrbMode.web,
  ThinkingOrbState.weaving => _OrbMode.braid,
  ThinkingOrbState.composing => _OrbMode.ribbon,
  ThinkingOrbState.breathing => _OrbMode.ring,
  ThinkingOrbState.shaping => _OrbMode.morph,
};

_ModeOpts _baseProfile(_OrbMode mode) => switch (mode) {
  _OrbMode.globe => {
    'latRings': 17,
    'lonDensity': 44,
    'rBase': 0.6,
    'rDepth': 1.7,
    'rBoost': 1,
    'inkFar': 0.62,
    'inkSpan': 0.54,
    'rsPow': 0.6,
    'rMin': 0.3,
  },
  _OrbMode.orbits => {
    'orbitN': 12,
    'ghostN': 40,
    'ghostR': 0.9,
    'ghostA': 0.5,
    'particles': 3,
    'partR': 1.2,
    'partRDepth': 1.6,
    'rsPow': 0.6,
    'rMin': 0.3,
  },
  _OrbMode.rubik => {
    'latRings': 15,
    'lonDensity': 40,
    'moveCount': 14,
    'rBase': 0.6,
    'rDepth': 1.7,
    'rActive': 0.3,
    'inkFar': 0.62,
    'inkSpan': 0.54,
    'rsPow': 0.6,
    'rMin': 0.3,
  },
  _OrbMode.wave => {
    'rings': 15,
    'lonDensity': 40,
    'rBase': 0.6,
    'rDepth': 1.7,
    'rsPow': 0.6,
    'rMin': 0.3,
  },
  _OrbMode.web => {
    'nodeN': 30,
    'thr': 0.72,
    'signals': 5,
    'nodeR': 1.4,
    'nodeRDepth': 1.8,
    'lineW': 0.8,
    'rsPow': 0.6,
    'rMin': 0.3,
  },
  _OrbMode.braid => {
    'strandN': 52,
    'turns': 3,
    'ghostN': 150,
    'rBase': 1.2,
    'rDepth': 1.8,
    'rsPow': 0.6,
    'rMin': 0.3,
  },
  _OrbMode.ribbon => {
    'lanes': 5,
    'segs': 88,
    'ghostN': 150,
    'rBase': 1.1,
    'rDepth': 1.7,
    'rsPow': 0.6,
    'rMin': 0.3,
  },
  _OrbMode.ring => {
    'lanes': 5,
    'segs': 88,
    'ghostN': 0,
    'faceOn': 1,
    'rBase': 1.1,
    'rDepth': 1.7,
    'rsPow': 0.6,
    'rMin': 0.3,
  },
  _OrbMode.morph => {'rDot': 0.021, 'iconD': 1, 'rMin': 0.25},
};

const Map<_OrbMode, Map<ThinkingOrbSize, _Preset>> _presets = {
  _OrbMode.orbits: {
    ThinkingOrbSize.regular: _Preset(speed: 1.885, count: 1, size: 1),
    ThinkingOrbSize.inline: _Preset(speed: 3.9, count: 0.238, size: 2.4),
  },
  _OrbMode.globe: {
    ThinkingOrbSize.regular: _Preset(
      speed: 2.015,
      count: 0.42,
      size: 1.15,
      extra: {'scanMul': 4.08, 'dimBase': 0.45},
    ),
    ThinkingOrbSize.inline: _Preset(
      speed: 2.665,
      count: 0.105,
      size: 1.75,
      extra: {'scanMul': 4.335, 'dimBase': 0.45},
    ),
  },
  _OrbMode.rubik: {
    ThinkingOrbSize.regular: _Preset(speed: 1.82, count: 0.35, size: 1.05),
    ThinkingOrbSize.inline: _Preset(speed: 1.95, count: 0.088, size: 1.9),
  },
  _OrbMode.wave: {
    ThinkingOrbSize.regular: _Preset(speed: 4.388, count: 0.341, size: 1),
    ThinkingOrbSize.inline: _Preset(speed: 3.998, count: 0.105, size: 1.6),
  },
  _OrbMode.web: {
    ThinkingOrbSize.regular: _Preset(speed: 3.315, count: 1.35, size: 0.95),
    ThinkingOrbSize.inline: _Preset(speed: 6.63, count: 0.25, size: 1.52),
  },
  _OrbMode.braid: {
    ThinkingOrbSize.regular: _Preset(speed: 1.625, count: 0.5, size: 1),
    ThinkingOrbSize.inline: _Preset(speed: 2.75, count: 0.1125, size: 1.36),
  },
  _OrbMode.ribbon: {
    ThinkingOrbSize.regular: _Preset(
      speed: 2.34,
      count: 0.25,
      size: 0.85,
      extra: {'spin': 0, 'bandMul': 3.9, 'wobMul': 1},
    ),
    ThinkingOrbSize.inline: _Preset(
      speed: 3.12,
      count: 0.051,
      size: 1.073,
      extra: {'spin': 0, 'bandMul': 4.94, 'wobMul': 1},
    ),
  },
  _OrbMode.ring: {
    ThinkingOrbSize.regular: _Preset(
      speed: 3.24,
      count: 0.25,
      size: 0.956,
      extra: {'spin': 0, 'bandMul': 3.627, 'wobMul': 0.368},
    ),
    ThinkingOrbSize.inline: _Preset(
      speed: 3.78,
      count: 0.028,
      size: 1.622,
      extra: {'spin': 0, 'bandMul': 3.968, 'wobMul': 0.565},
    ),
  },
  _OrbMode.morph: {
    ThinkingOrbSize.regular: _Preset(
      speed: 2.405,
      count: 0.702,
      size: 0.395,
      extra: {'spread': 1.45},
    ),
    ThinkingOrbSize.inline: _Preset(
      speed: 2.08,
      count: 0.53,
      size: 1.011,
      extra: {'spread': 1.45},
    ),
  },
};

const List<(String, String)> _countPairs = [
  ('latRings', 'lonDensity'),
  ('rings', 'lonDensity'),
  ('lanes', 'segs'),
];
const List<String> _countKeys = [
  'orbitN',
  'ghostN',
  'nodeN',
  'strandN',
  'signals',
];
const List<String> _radiusKeys = [
  'rBase',
  'rDepth',
  'rActive',
  'rDot',
  'ghostR',
  'partR',
  'partRDepth',
  'nodeR',
  'nodeRDepth',
];

_ModeOpts _scaleCounts(_ModeOpts opts, double scale) {
  final result = Map<String, double>.from(opts);
  final done = <String>{};
  final root = math.sqrt(scale);
  for (final pair in _countPairs) {
    final first = result[pair.$1];
    final second = result[pair.$2];
    if (first != null &&
        second != null &&
        !done.contains(pair.$1) &&
        !done.contains(pair.$2)) {
      result[pair.$1] = math.max(2, (first * root).round()).toDouble();
      result[pair.$2] = math.max(2, (second * root).round()).toDouble();
      done
        ..add(pair.$1)
        ..add(pair.$2);
    }
  }
  for (final key in _countKeys) {
    final value = result[key];
    if (value != null && value != 0 && !done.contains(key)) {
      result[key] = math.max(1, (value * scale).round()).toDouble();
    }
  }
  final density = result['iconD'];
  if (density != null) result['iconD'] = math.max(0.02, density * scale);
  return result;
}

_ModeOpts _scaleRadii(_ModeOpts opts, double scale) {
  final result = Map<String, double>.from(opts);
  for (final key in _radiusKeys) {
    final value = result[key];
    if (value != null) result[key] = value * scale;
  }
  result['rSizeMul'] = (result['rSizeMul'] ?? 1) * scale;
  return result;
}

_ResolvedPreset _resolvePreset(ThinkingOrbState state, ThinkingOrbSize size) {
  final mode = _modeFor(state);
  final preset = _presets[mode]![size]!;
  var opts = _baseProfile(mode);
  if (preset.count != 1) opts = _scaleCounts(opts, preset.count);
  if (preset.size != 1) opts = _scaleRadii(opts, preset.size);
  opts.addAll(preset.extra);
  return _ResolvedPreset(mode, preset.speed, opts);
}
