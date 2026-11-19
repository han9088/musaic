// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'package:material_ui/material_ui.dart';

/// 封装或定义底部弹层背景相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetBackdrop extends StatelessWidget {
  const BottomSheetBackdrop({
    super.key,
    required this.color,
    required this.opacity,
    this.onTap,
    this.solid = false,
  });

  final Color color;
  final double opacity;
  final VoidCallback? onTap;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final effectiveOpacity = solid ? 1.0 : opacity;
    if (effectiveOpacity <= 0) {
      return const SizedBox.expand();
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: color.withValues(alpha: solid ? color.a : effectiveOpacity),
      ),
    );
  }
}
