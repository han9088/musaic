// 文件职责：绘制无限专辑网格并处理超出布局边界的点击。

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'portrait_tilt.dart';

class AlbumCanvas extends Stack {
  AlbumCanvas({
    super.key,
    required Size size,
    required this.tiltPadding,
    required this.transform,
    required this.isTransitioning,
    required Iterable<Widget> tiles,
    Widget? selected,
  }) : hasSelected = selected != null,
       super(
         clipBehavior: Clip.none,
         children: [
           SizedBox.fromSize(size: size),
           ...tiles,
           ?selected,
         ],
       );

  final Offset tiltPadding;
  final TransformationController transform;
  final bool isTransitioning;
  final bool hasSelected;

  @override
  RenderStack createRenderObject(BuildContext context) =>
      _RenderAlbumCanvas(
        textDirection: Directionality.maybeOf(context),
        tiltPadding: tiltPadding,
        transform: transform,
        isTransitioning: isTransitioning,
        hasSelected: hasSelected,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderStack renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderAlbumCanvas)
      ..tiltPadding = tiltPadding
      ..transform = transform
      ..isTransitioning = isTransitioning
      ..hasSelected = hasSelected
      ..markNeedsPaint();
  }
}

class _RenderAlbumCanvas extends RenderStack {
  _RenderAlbumCanvas({
    required super.textDirection,
    required this.tiltPadding,
    required this.transform,
    required this.isTransitioning,
    required this.hasSelected,
  }) : super(clipBehavior: Clip.none);

  Offset tiltPadding;
  TransformationController transform;
  bool isTransitioning;
  bool hasSelected;

  @override
  void paintStack(PaintingContext context, Offset offset) {
    if (isTransitioning) {
      super.paintStack(context, offset);
      return;
    }
    final matrix = transform.value;
    final scale = matrix.getColumn(0).length;
    final x = matrix.entry(0, 3);
    final y = matrix.entry(1, 3);
    final viewport = Rect.fromLTRB(
      (-tiltPadding.dx - x) / scale,
      (-tiltPadding.dy - y) / scale,
      (size.width + tiltPadding.dx - x) / scale,
      (size.height + tiltPadding.dy - y) / scale,
    );
    // Keep the guard-ring covers mounted without recording paint for them.
    var tile = childAfter(firstChild!);
    while (tile != null) {
      final data = tile.parentData! as StackParentData;
      if ((hasSelected && tile == lastChild) ||
          viewport.overlaps(data.offset & tile.size)) {
        context.paintChild(tile, offset + data.offset);
      }
      tile = data.nextSibling;
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (result is TiltEdgeHitTestResult) {
      position += result.viewportDelta / transform.value.getColumn(0).length;
    }
    return defaultHitTestChildren(result, position: position);
  }
}
