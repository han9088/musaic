import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Blurs a track progressively as it crosses the list's fading edges.
class AlbumTrackEdgeBlur extends SingleChildRenderObjectWidget {
  const AlbumTrackEdgeBlur({
    super.key,
    required this.edgeExtent,
    required super.child,
  });

  final double edgeExtent;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAlbumTrackEdgeBlur(Scrollable.of(context).position, edgeExtent);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderAlbumTrackEdgeBlur).update(
        Scrollable.of(context).position,
        edgeExtent,
      );
}

class _RenderAlbumTrackEdgeBlur extends RenderProxyBox {
  _RenderAlbumTrackEdgeBlur(this._position, this._edgeExtent);

  ScrollPosition _position;
  double _edgeExtent;

  void update(ScrollPosition position, double edgeExtent) {
    if (position == _position && edgeExtent == _edgeExtent) return;
    if (attached) _position.removeListener(markNeedsPaint);
    _position = position;
    _edgeExtent = edgeExtent;
    if (attached) _position.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _position.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _position.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (RenderAbstractViewport.maybeOf(parent) case final RenderBox viewport) {
      final edge = math.min(_edgeExtent, viewport.size.height * 0.35);
      final top = localToGlobal(Offset.zero, ancestor: viewport).dy;
      final overlap = math.max(
        edge - top,
        top + size.height + edge - viewport.size.height,
      );
      if (overlap > 0) {
        final strength = (overlap / (edge + size.height / 2)).clamp(0.0, 1.0);
        final sigma = 2.2 * strength;
        final filtered = layer as ImageFilterLayer? ?? ImageFilterLayer();
        filtered.imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: ui.TileMode.decal,
        );
        context.pushLayer(
          filtered,
          super.paint,
          offset,
          childPaintBounds: offset & size,
        );
        layer = filtered;
        return;
      }
    }
    layer = null;
    super.paint(context, offset);
  }
}
