// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'package:material_ui/material_ui.dart';

/// 封装或定义底部弹层遮罩相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetMask extends StatelessWidget {
  const BottomSheetMask({
    super.key,
    required this.height,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  final double height;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (height <= 0) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: enabled ? onTap : null,
        child: ColoredBox(color: color),
      ),
    );
  }
}
