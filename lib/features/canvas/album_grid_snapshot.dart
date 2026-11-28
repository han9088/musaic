// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'package:material_ui/material_ui.dart';

const albumGridExtent = 100.0;
const albumCanvasArtworkResolution = 256;

typedef AlbumGridCell = (int row, int column);

Rect albumGridRect(AlbumGridCell cell) => Rect.fromLTWH(
  cell.$2 * albumGridExtent,
  cell.$1 * albumGridExtent,
  albumGridExtent,
  albumGridExtent,
);

/// 执行当前模块中的网格专辑索引操作，用于专辑墙无限画布的布局、视口与交互状态。
int gridAlbumIndex(int row, int column, int count) =>
    ((row * 73856093) ^ (column * 19349663)) % count;

/// 封装或定义专辑网格快照相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class AlbumGridSnapshot {
  AlbumGridSnapshot._(this.viewport, this.cells, this.focus);

  factory AlbumGridSnapshot.capture(
    Size viewport,
    Matrix4 transform, {
    double overscan = 0,
  }) {
    final bounds = Rect.fromLTWH(
      -overscan,
      -overscan,
      viewport.width + overscan * 2,
      viewport.height + overscan * 2,
    );
    final cells = <({int row, int column, Rect rect})>[];
    var focus = 0;
    var nearest = double.infinity;
    for (final (cell, rect) in _projectedCells(bounds, transform)) {
      if (!rect.overlaps(bounds)) continue;
      final distance =
          (rect.center - viewport.center(Offset.zero)).distanceSquared;
      if (distance < nearest) {
        nearest = distance;
        focus = cells.length;
      }
      cells.add((row: cell.$1, column: cell.$2, rect: rect));
    }
    return AlbumGridSnapshot._(viewport, cells, focus);
  }

  static Iterable<AlbumGridCell> fullyVisibleCells(
    Rect bounds,
    Matrix4 transform,
  ) sync* {
    for (final (cell, rect) in _projectedCells(bounds, transform)) {
      if (_fullyContains(bounds, rect)) yield cell;
    }
  }

  static Iterable<AlbumGridCell> intersectingCells(
    Rect bounds,
    Matrix4 transform,
  ) sync* {
    for (final (cell, rect) in _projectedCells(bounds, transform)) {
      if (rect.isFinite && rect.overlaps(bounds)) yield cell;
    }
  }

  static bool isFullyVisible(
    AlbumGridCell cell,
    Rect bounds,
    Matrix4 transform,
  ) => _fullyContains(
    bounds,
    MatrixUtils.transformRect(transform, albumGridRect(cell)),
  );

  static bool _fullyContains(Rect bounds, Rect rect) =>
      rect.isFinite &&
      !rect.isEmpty &&
      rect.left >= bounds.left &&
      rect.right <= bounds.right &&
      rect.top >= bounds.top &&
      rect.bottom <= bounds.bottom;

  static Iterable<(AlbumGridCell, Rect)> _projectedCells(
    Rect bounds,
    Matrix4 transform,
  ) sync* {
    // Flatten the projection to the artwork plane before inverting it.
    final plane = transform.clone()
      ..setEntry(2, 0, 0)
      ..setEntry(2, 1, 0)
      ..setEntry(2, 2, 1)
      ..setEntry(2, 3, 0)
      ..setEntry(0, 2, 0)
      ..setEntry(1, 2, 0)
      ..setEntry(3, 2, 0);
    final inverse = Matrix4.tryInvert(plane);
    if (inverse == null) return;
    final scene = MatrixUtils.transformRect(inverse, bounds);
    if (!scene.isFinite) return;
    for (
      var row = (scene.top / albumGridExtent).floor();
      row <= (scene.bottom / albumGridExtent).ceil();
      row++
    ) {
      for (
        var column = (scene.left / albumGridExtent).floor();
        column <= (scene.right / albumGridExtent).ceil();
        column++
      ) {
        final cell = (row, column);
        yield (cell, MatrixUtils.transformRect(transform, albumGridRect(cell)));
      }
    }
  }

  final Size viewport;
  final List<({int row, int column, Rect rect})> cells;
  final int focus;

  /// Picks distinct covers in the top-to-bottom entrance order.
  List<({int row, int column, Rect rect})> leadingArtworkCells({
    required int albumCount,
    required int limit,
  }) {
    if (albumCount == 0 || limit <= 0) return const [];
    final centerX = viewport.width / 2;
    final ordered = cells.toList()
      ..sort((a, b) {
        final row = a.row.compareTo(b.row);
        if (row != 0) return row;
        return (a.rect.center.dx - centerX).abs().compareTo(
          (b.rect.center.dx - centerX).abs(),
        );
      });
    final seen = <int>{};
    return ordered
        .where(
          (cell) => seen.add(gridAlbumIndex(cell.row, cell.column, albumCount)),
        )
        .take(limit)
        .toList(growable: false);
  }

  /// 执行当前模块中的rectfor操作，用于专辑墙无限画布的布局、视口与交互状态。
  Rect rectFor(int index, Size size, EdgeInsets padding) {
    final rect = cells[index].rect;
    return Rect.fromCenter(
      center: Offset(
        rect.center.dx / viewport.width * size.width - padding.left,
        rect.center.dy / viewport.height * size.height - padding.top,
      ),
      width: rect.width,
      height: rect.height,
    );
  }
}
