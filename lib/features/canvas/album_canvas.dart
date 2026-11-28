// 文件职责：绘制无限专辑网格并处理超出布局边界的点击。

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'album_grid_snapshot.dart';
import 'album_tile_motion.dart';
import 'portrait_tilt.dart';

class AlbumCanvas extends Stack {
  AlbumCanvas({
    super.key,
    required Size size,
    required this.tiltPadding,
    required this.transform,
    required this.isTransitioning,
    required this.albumAt,
    required Iterable<Widget> tiles,
    List<Widget> selectedTiles = const [],
    this.hiddenTileOffset,
    this.tileMotion,
  }) : tileCount = tiles.length,
       hasSelected = selectedTiles.isNotEmpty,
       super(
         clipBehavior: Clip.none,
         children: [
           SizedBox.fromSize(size: size),
           ...tiles,
           ...selectedTiles,
         ],
       );

  final Offset tiltPadding;
  final TransformationController transform;
  final bool isTransitioning;
  final bool hasSelected;
  final int tileCount;
  final AlbumTileMotion? tileMotion;
  final Offset? hiddenTileOffset;
  final Object Function(int row, int column) albumAt;

  @override
  RenderStack createRenderObject(BuildContext context) => _RenderAlbumCanvas(
    textDirection: Directionality.maybeOf(context),
    tiltPadding: tiltPadding,
    transform: transform,
    isTransitioning: isTransitioning,
    albumAt: albumAt,
    hasSelected: hasSelected,
    tileCount: tileCount,
    motion: tileMotion,
    hiddenTileOffset: hiddenTileOffset,
  );

  @override
  void updateRenderObject(BuildContext context, RenderStack renderObject) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderAlbumCanvas)
      ..tiltPadding = tiltPadding
      ..transform = transform
      ..isTransitioning = isTransitioning
      ..albumAt = albumAt
      ..hasSelected = hasSelected
      ..tileCount = tileCount
      ..motion = tileMotion
      ..hiddenTileOffset = hiddenTileOffset
      .._semanticCoverage = null
      ..markNeedsPaint()
      ..markNeedsSemanticsUpdate();
  }
}

class _RenderAlbumCanvas extends RenderStack {
  _RenderAlbumCanvas({
    required super.textDirection,
    required this.tiltPadding,
    required this.transform,
    required this.isTransitioning,
    required this.albumAt,
    required this.hasSelected,
    required this.tileCount,
    required this.hiddenTileOffset,
    required AlbumTileMotion? motion,
  }) : _motion = motion,
       super(clipBehavior: Clip.none);

  Offset tiltPadding;
  TransformationController transform;
  bool isTransitioning;
  Object Function(int row, int column) albumAt;
  bool hasSelected;
  int tileCount;
  Offset? hiddenTileOffset;
  AlbumTileMotion? _motion;

  set motion(AlbumTileMotion? value) {
    if (identical(value, _motion)) return;
    if (attached) _motion?.removeListener(markNeedsPaint);
    _motion = value;
    if (attached) _motion?.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _motion?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _motion?.removeListener(markNeedsPaint);
    super.detach();
  }

  bool get _groupRepeatedAlbums =>
      !isTransitioning && !hasSelected && hiddenTileOffset == null;
  var _albumRepresentatives = <Object, RenderBox>{};
  Set<RenderBox>? _semanticTiles;
  (Rect, Rect)? _semanticCoverage;

  static const _tileConstraints = BoxConstraints.tightFor(
    width: albumGridExtent,
    height: albumGridExtent,
  );

  @override
  void performLayout() {
    final viewport = firstChild!;
    viewport.layout(constraints, parentUsesSize: true);
    size = viewport.size;
    var tile = childAfter(viewport);
    while (tile != null) {
      final data = tile.parentData! as StackParentData;
      assert(data.width == albumGridExtent && data.height == albumGridExtent);
      tile.layout(_tileConstraints);
      data.offset = Offset(data.left!, data.top!);
      tile = data.nextSibling;
    }
  }

  Rect _sceneViewport(Offset padding) {
    final matrix = transform.value;
    final scale = matrix.getColumn(0).length;
    final x = matrix.entry(0, 3);
    final y = matrix.entry(1, 3);
    return Rect.fromLTRB(
      (-padding.dx - x) / scale,
      (-padding.dy - y) / scale,
      (size.width + padding.dx - x) / scale,
      (size.height + padding.dy - y) / scale,
    );
  }

  Set<RenderBox> _chooseSemanticTiles(Rect viewport) {
    final innerViewport = _sceneViewport(-tiltPadding);
    // Each edge changes membership only when it crosses a cover or its center.
    final coverage = (
      Rect.fromLTRB(
        (viewport.left / albumGridExtent).floorToDouble(),
        (viewport.top / albumGridExtent).floorToDouble(),
        (viewport.right / albumGridExtent).ceilToDouble(),
        (viewport.bottom / albumGridExtent).ceilToDouble(),
      ),
      Rect.fromLTRB(
        (innerViewport.left / albumGridExtent - .5).ceilToDouble(),
        (innerViewport.top / albumGridExtent - .5).ceilToDouble(),
        (innerViewport.right / albumGridExtent - .5).ceilToDouble(),
        (innerViewport.bottom / albumGridExtent - .5).ceilToDouble(),
      ),
    );
    if (coverage == _semanticCoverage && _semanticTiles != null) {
      return _semanticTiles!;
    }
    _semanticCoverage = coverage;
    final center = viewport.center;
    final representatives = <Object, RenderBox>{};
    final distances = <Object, double>{};
    final edgeTiles = <(Object, RenderBox)>[];
    var tile = childAfter(firstChild!);
    while (tile != null) {
      final data = tile.parentData! as StackParentData;
      final rect = data.offset & tile.size;
      if (viewport.overlaps(rect)) {
        final album = albumAt(
          (data.offset.dy / albumGridExtent).round(),
          (data.offset.dx / albumGridExtent).round(),
        );
        if (innerViewport.contains(rect.center)) {
          // Keep the same node until it nears a projected edge.
          final distance = identical(tile, _albumRepresentatives[album])
              ? -1.0
              : (rect.center - center).distanceSquared;
          if (distance < (distances[album] ?? double.infinity)) {
            representatives[album] = tile;
            distances[album] = distance;
          }
        } else {
          edgeTiles.add((album, tile));
        }
      }
      tile = data.nextSibling;
    }
    _albumRepresentatives = representatives;
    return {
      ...representatives.values,
      // Let Flutter clip albums that appear only along the tilted edges.
      for (final (album, tile) in edgeTiles)
        if (!representatives.containsKey(album)) tile,
    };
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (!_groupRepeatedAlbums || !hasSize || firstChild == null) {
      super.visitChildrenForSemantics(visitor);
      return;
    }
    final tiles = _semanticTiles ??= _chooseSemanticTiles(
      _sceneViewport(tiltPadding),
    );
    var tile = childAfter(firstChild!);
    while (tile != null) {
      if (tiles.contains(tile)) visitor(tile);
      tile = (tile.parentData! as StackParentData).nextSibling;
    }
  }

  @override
  void paintStack(PaintingContext context, Offset offset) {
    if (isTransitioning && hiddenTileOffset == null) {
      super.paintStack(context, offset);
      return;
    }
    final viewport = _sceneViewport(tiltPadding);
    if (_groupRepeatedAlbums && owner?.semanticsOwner != null) {
      final tiles = _chooseSemanticTiles(viewport);
      if (!setEquals(tiles, _semanticTiles)) {
        _semanticTiles = tiles;
        markNeedsSemanticsUpdate();
      }
    }
    // Lifted covers extend past their cell by half of the 16% scale increase.
    final paintViewport = hasSelected
        ? viewport.inflate(albumGridExtent * 0.08)
        : viewport;
    final motion = _motion?.isActive == true ? _motion : null;
    // 先画下沉封面，再画静态格位，上浮和单张翻转位于静态格位之上。
    motion?.paintBehind(context.canvas, offset);
    // Keep the guard-ring covers mounted without recording paint for them.
    var tile = childAfter(firstChild!);
    var paintedTiles = 0;
    while (tile != null) {
      final data = tile.parentData! as StackParentData;
      if (paintedTiles == tileCount) motion?.paintAbove(context.canvas, offset);
      final covered =
          motion != null &&
          paintedTiles < tileCount &&
          motion.owns((
            (data.offset.dy / albumGridExtent).round(),
            (data.offset.dx / albumGridExtent).round(),
          ));
      // Both the grid tile and its lifted copy share this offset.
      if (!covered &&
          data.offset != hiddenTileOffset &&
          (isTransitioning ||
              paintViewport.overlaps(data.offset & tile.size))) {
        context.paintChild(tile, offset + data.offset);
      }
      paintedTiles++;
      tile = data.nextSibling;
    }
    if (paintedTiles == tileCount) motion?.paintAbove(context.canvas, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (result is TiltEdgeHitTestResult) {
      position += result.viewportDelta / transform.value.getColumn(0).length;
    }
    return defaultHitTestChildren(result, position: position);
  }
}
