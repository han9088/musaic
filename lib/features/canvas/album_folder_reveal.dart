// 文件职责：绘制专辑夹展开、内页抽取落位及合拢。
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'album_tile_motion_artwork.dart';

class AlbumFolderReveal {
  static const _openEnd = Duration(milliseconds: 728);
  static const _transferStart = Duration(milliseconds: 900);
  static const _transferEnd = Duration(milliseconds: 1650);
  static const _closeStart = Duration(milliseconds: 1872);
  static const duration = Duration(milliseconds: 2600);
  static const panelCount = 4;
  static const extractedCoverIndex = 1;
  static const _opening = Cubic(.22, .75, .25, 1);
  static const _closing = Cubic(.4, 0, .2, 1);

  final _clock = Stopwatch()..start();
  final _panels = [
    _FolderPanel(-5, -.04, .94),
    _FolderPanel(-22, -.01, .94),
    _FolderPanel(-32, 0, .94),
    _FolderPanel(-44, 0, 1, front: true),
  ];
  double _openness = 0;
  double _transfer = 0;
  double? _lastOpenness;
  double? _lastTransfer;
  double? _lastSide;

  Duration get age => _clock.elapsed;
  bool get hasTransferred => _transfer == 1;

  void advance(Duration age) {
    _openness = _opennessAt(age);
    _transfer = _closing.transform(_phase(age, _transferStart, _transferEnd));
  }

  static Duration? holdUntil(Duration age) {
    if (age >= _openEnd && age < _transferStart) return _transferStart;
    if (age >= _transferEnd && age < _closeStart) return _closeStart;
    return null;
  }

  static double _phase(Duration age, Duration start, Duration end) =>
      ((age - start).inMicroseconds / (end - start).inMicroseconds).clamp(
        0.0,
        1.0,
      );

  static double _opennessAt(Duration age) {
    if (age < _openEnd) {
      return _opening.transform(_phase(age, Duration.zero, _openEnd));
    }
    return 1 - _closing.transform(_phase(age, _closeStart, duration));
  }

  void paint(
    Canvas canvas,
    Rect tile,
    Rect destination,
    List<AlbumTileMotionCover> covers,
  ) {
    assert(covers.length == panelCount);
    if (_openness == 0) {
      covers.first.paint(canvas, tile);
      return;
    }
    final side = tile.width;
    // 停留期间复用面片矩阵和阴影；画布自身移动也无需重算。
    if (_lastOpenness != _openness ||
        _lastTransfer != _transfer ||
        _lastSide != side) {
      for (var i = 0; i < _panels.length; i++) {
        if (i == 0 && hasTransferred) continue;
        _panels[i].update(side, _openness, settle: i == 0 ? _transfer : 0);
      }
      _lastOpenness = _openness;
      _lastTransfer = _transfer;
      _lastSide = side;
    }
    final face = Rect.fromLTWH(-side / 2, -side, side, side);
    final hinge = tile.bottomCenter;
    for (var i = 0; i < _panels.length; i++) {
      if (i == 0 && hasTransferred) continue;
      final panel = _panels[i];
      // 最后层的内页沿相邻格方向抽出，仍由前面的封面遮挡重叠部分。
      final origin = i == 0
          ? Offset(
              hinge.dx + (destination.center.dx - hinge.dx) * _transfer,
              hinge.dy - side * .18 * math.sin(math.pi * _transfer),
            )
          : hinge;
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
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

  void update(double side, double openness, {required double settle}) {
    final tilt = openness * (1 - settle);
    final panelScale = scale + (1 - scale) * settle;
    // 以底边中心为原点，负向 X 旋转将封面上沿朝观察者拉近。
    transform
      ..setIdentity()
      ..setEntry(3, 2, -1 / (8 * side))
      ..translateByDouble(0, lift * side * tilt, 0, 1)
      ..rotateX(angle * math.pi / 180 * tilt)
      ..scaleByDouble(panelScale, panelScale, 1, 1);
    shadowOffset = Offset(0, -(front ? .01 : .005) * side * tilt);
    shadow
      ..color = const Color(0xff000000)
          .withValues(alpha: (front ? .24 : .22) * tilt)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        (front ? .02 : .0075) * side * tilt,
      );
  }
}
