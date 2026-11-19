// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 封装或定义专辑画布相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
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

/// 封装或定义画布渲染相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class _RenderAlbumCanvas extends RenderConstrainedBox {
  _RenderAlbumCanvas(Size size)
    : super(additionalConstraints: BoxConstraints.tight(size));

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Stack 会绘制超出自身布局边界的专辑卡片，命中测试不能因此拦截卡片点击。
    return (child! as RenderStack).defaultHitTestChildren(
      result,
      position: position,
    );
  }
}
