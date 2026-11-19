// 文件职责：音乐源、媒体库、播放及切换流程。

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

const tileOutDurationMs = 85.0;
const tileRowDelayMs = 50.0;
const tileLeftDelayMs = 51.0;
const sourceHandoffMs = 110.0;
const enterStaggerMs = 28.0;
const enterRowMs = 190.0;
const enterHoldMs = 60.0;

/// 封装或定义来源tile动效相关类型与行为，负责音乐源、媒体库、播放及切换流程。
class SourceTileMotion {
  const SourceTileMotion({required this.rect, required this.startMs});

  final Rect rect;
  final double startMs;

  static ({Map<(int, int), SourceTileMotion> tiles, double durationMs}) exit(
    List<({int row, int column, Rect rect})> cells,
    Size viewport,
  ) {
    if (cells.isEmpty) return (tiles: const {}, durationMs: 0);
    final bottom = cells
        .map((cell) => cell.row)
        .reduce((a, b) => a > b ? a : b);
    final tiles = <(int, int), SourceTileMotion>{};
    var duration = 0.0;
    for (final cell in cells) {
      final centerX = cell.rect.center.dx / viewport.width;
      final left = ((0.75 - centerX) / 0.5).clamp(0.0, 1.0);
      final start =
          tileRowDelayMs * (bottom - cell.row) + tileLeftDelayMs * left;
      tiles[(cell.row, cell.column)] = SourceTileMotion(
        rect: cell.rect,
        startMs: start,
      );
      duration = math.max(duration, start + tileOutDurationMs);
    }
    return (tiles: tiles, durationMs: duration);
  }

  static ({Map<(int, int), SourceTileMotion> tiles, double durationMs}) enter(
    List<({int row, int column, Rect rect})> cells,
  ) {
    final rows = cells.map((cell) => cell.row).toSet().toList()..sort();
    final order = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    final tiles = <(int, int), SourceTileMotion>{};
    for (final cell in cells) {
      tiles[(cell.row, cell.column)] = SourceTileMotion(
        rect: cell.rect,
        startMs: order[cell.row]! * enterStaggerMs,
      );
    }
    final duration = rows.isEmpty
        ? 0.0
        : (rows.length - 1) * enterStaggerMs + enterRowMs + enterHoldMs;
    return (tiles: tiles, durationMs: duration);
  }

  ({Matrix4 transform, double alpha}) exitTransform({
    required double elapsedMs,
    required Size viewport,
    required double scale,
    required double tileSize,
  }) {
    final u = ((elapsedMs - startMs) / tileOutDurationMs).clamp(0.0, 1.0);
    final right = (rect.center.dx / viewport.width).clamp(0.0, 1.0);
    final dx =
        -(0.047 + (0.098 - 0.047) * right) * viewport.width * math.pow(u, 2.5);
    final angle = -45 * u * u * math.pi / 180;
    final eye = (viewport.height / 2) / math.tan(34 * math.pi / 360);
    final depth = 0.09 * eye * u * u;
    final hinge = rect.center.dx < viewport.width / 2 - 1
        ? tileSize / 2
        : -tileSize / 2;
    final matrix = _tileTransform(
      angle: angle,
      depth: depth / scale,
      dx: dx / scale,
      hinge: hinge,
      eyeDistance: eye / scale,
    );
    final alpha = u < 0.7 ? 1.0 : ((1 - u) / 0.3).clamp(0.0, 1.0);
    return (transform: matrix, alpha: alpha);
  }

  ({Matrix4 transform, double alpha}) enterTransform({
    required double elapsedMs,
    required Size viewport,
    required double scale,
    required double tileSize,
  }) {
    final t = ((elapsedMs - startMs) / enterRowMs).clamp(0.0, 1.0);
    final left = 1 - t;
    final angle = 69.8 * math.exp(-2.649 * t) * math.pow(left, 0.165);
    final depth =
        -0.182 *
        ((viewport.height / 2) / math.tan(34 * math.pi / 360)) *
        math.exp(-1.656 * t) *
        left;
    final travel =
        110.0 *
        (-0.476 * math.exp(-7.157 * t) + 0.193 * math.exp(-0.849 * t)) *
        math.sqrt(left);
    final hinge = rect.center.dx < viewport.width / 2 - 1
        ? tileSize / 2
        : -tileSize / 2;
    final matrix = _tileTransform(
      angle: angle * math.pi / 180,
      depth: depth / scale,
      dx: travel / scale,
      hinge: hinge,
      eyeDistance:
          ((viewport.height / 2) / math.tan(34 * math.pi / 360)) / scale,
    );
    final alpha =
        (0.7 + 0.3 * math.cos(angle * math.pi / 180)) * math.min(1.0, t / 0.08);
    return (transform: matrix, alpha: alpha);
  }

  static Matrix4 _tileTransform({
    required double angle,
    required double depth,
    required double dx,
    required double hinge,
    required double eyeDistance,
  }) => Matrix4.identity()
    ..setEntry(3, 2, 1 / eyeDistance)
    ..translateByDouble(dx, 0, depth, 1)
    ..translateByDouble(hinge, 0, 0, 1)
    ..rotateY(angle)
    ..translateByDouble(-hinge, 0, 0, 1);
}
