// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'package:material_ui/material_ui.dart';

const albumGridExtent = 100.0;
const albumCanvasArtworkResolution = 256;

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
    final scene = MatrixUtils.transformRect(
      Matrix4.inverted(transform),
      bounds,
    );
    final cells = <({int row, int column, Rect rect})>[];
    var focus = 0;
    var nearest = double.infinity;
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
        final rect = MatrixUtils.transformRect(
          transform,
          Rect.fromLTWH(
            column * albumGridExtent,
            row * albumGridExtent,
            albumGridExtent,
            albumGridExtent,
          ),
        );
        if (!rect.overlaps(bounds)) continue;
        final distance =
            (rect.center - viewport.center(Offset.zero)).distanceSquared;
        if (distance < nearest) {
          nearest = distance;
          focus = cells.length;
        }
        cells.add((row: row, column: column, rect: rect));
      }
    }
    return AlbumGridSnapshot._(viewport, cells, focus);
  }

  final Size viewport;
  final List<({int row, int column, Rect rect})> cells;
  final int focus;

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
