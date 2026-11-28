// 文件职责：绘制底边固定的四层专辑夹，并定义展开、停留和合拢的时序。
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'album_tile_motion_artwork.dart';

class AlbumFolderReveal {
  static const openEnd = Duration(milliseconds: 728);
  static const closeStart = Duration(milliseconds: 1872);
  static const duration = Duration(milliseconds: 2600);
  static const panelCount = 4;
  static const _opening = Cubic(.22, .75, .25, 1);
  static const _closing = Cubic(.4, 0, .2, 1);

  final _clock = Stopwatch()..start();
  final _panels = [
    _FolderPanel(-5, -.04, .94),
    _FolderPanel(-22, -.01, .94),
    _FolderPanel(-32, 0, .94),
    _FolderPanel(-44, 0, 1, front: true),
  ];
  double? _lastOpenness;
  double? _lastSide;

  Duration get age => _clock.elapsed;

  static double opennessAt(Duration age) {
    if (age < openEnd) {
      return _opening.transform(age.inMicroseconds / openEnd.inMicroseconds);
    }
    if (age <= closeStart) return 1;
    if (age >= duration) return 0;
    return 1 -
        _closing.transform(
          (age - closeStart).inMicroseconds /
              (duration - closeStart).inMicroseconds,
        );
  }

  void paint(
    Canvas canvas,
    Rect tile,
    double openness,
    List<AlbumTileMotionCover> covers,
  ) {
    assert(covers.length == panelCount);
    if (openness == 0) {
      covers.first.paint(canvas, tile);
      return;
    }
    final side = tile.width;
    // 停留期间复用面片矩阵和阴影；画布自身移动也无需重算。
    if (_lastOpenness != openness || _lastSide != side) {
      for (final panel in _panels) {
        panel.update(side, openness);
      }
      _lastOpenness = openness;
      _lastSide = side;
    }
    final face = Rect.fromLTWH(-side / 2, -side, side, side);
    final hinge = tile.bottomCenter;
    for (var i = 0; i < _panels.length; i++) {
      final panel = _panels[i];
      canvas.save();
      canvas.translate(hinge.dx, hinge.dy);
      canvas.transform(panel.transform.storage);
      canvas.drawRect(face.shift(panel.shadowOffset), panel.shadow);
      covers[(i + 1) % panelCount].paint(canvas, face);
      canvas.restore();
    }
  }
}

class _FolderPanel {
  _FolderPanel(this.angle, this.lift, this.scale, {this.front = false});

  final double angle;
  final double lift;
  final double scale;
  final bool front;
  final transform = Matrix4.identity();
  final shadow = Paint();
  Offset shadowOffset = Offset.zero;

  void update(double side, double openness) {
    // 以底边中心为原点，负向 X 旋转将封面上沿朝观察者拉近。
    transform
      ..setIdentity()
      ..setEntry(3, 2, -1 / (8 * side))
      ..translateByDouble(0, lift * side * openness, 0, 1)
      ..rotateX(angle * math.pi / 180 * openness)
      ..scaleByDouble(scale, scale, 1, 1);
    shadowOffset = Offset(0, -(front ? .01 : .005) * side * openness);
    shadow
      ..color = const Color(0xff000000)
          .withValues(alpha: (front ? .24 : .22) * openness)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        (front ? .02 : .0075) * side * openness,
      );
  }
}
