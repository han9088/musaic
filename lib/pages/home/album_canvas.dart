import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Keeps viewport-sized layout while allowing the infinite stack to receive taps.
class AlbumCanvas extends SingleChildRenderObjectWidget {
  const AlbumCanvas({super.key, required this.size, required Stack child})
    : super(child: child);

  final Size size;

  @override
  RenderConstrainedBox createRenderObject(BuildContext context) =>
      _RenderAlbumCanvas(size);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderConstrainedBox renderObject,
  ) {
    renderObject.additionalConstraints = BoxConstraints.tight(size);
  }
}

class _RenderAlbumCanvas extends RenderConstrainedBox {
  _RenderAlbumCanvas(Size size)
    : super(additionalConstraints: BoxConstraints.tight(size));

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Stack paints overflowing tiles; its layout bounds must not block their taps.
    return (child! as RenderStack).defaultHitTestChildren(
      result,
      position: position,
    );
  }
}
