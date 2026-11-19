// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'package:material_ui/material_ui.dart';

import '../constants.dart';

/// 封装或定义底部弹层手柄相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetHandle extends StatelessWidget {
  const BottomSheetHandle({
    super.key,
    required this.color,
    this.visible = true,
    this.height = kHandleHeight,
    this.hiddenHeight = kHiddenHandleHeight,
  });

  final Color color;
  final bool visible;
  final double height;
  final double hiddenHeight;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return SizedBox(height: hiddenHeight);
    }
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          width: 44,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
