// 文件职责：应用通用界面组件及其视觉绘制实现。

import 'dart:ui';

import 'package:material_ui/material_ui.dart';

/// 封装或定义玻璃图标按钮相关类型与行为，负责应用通用界面组件及其视觉绘制实现。
class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.onLongPress,
    this.diameter = 30,
    this.iconSize,
    this.foreground,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final double diameter;
  final double? iconSize;
  final Widget? foreground;
  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

/// 封装或定义玻璃图标按钮状态相关类型与行为，负责应用通用界面组件及其视觉绘制实现。
class _GlassIconButtonState extends State<GlassIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.icon,
      color: Colors.white,
      size: widget.iconSize ?? widget.diameter * 16 / 30,
    );
    final foreground = widget.foreground;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          width: widget.diameter < 44 ? 44 : widget.diameter,
          height: widget.diameter < 44 ? 44 : widget.diameter,
          child: Center(
            child: AnimatedScale(
              scale: _pressed ? 0.88 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 100),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: ColoredBox(
                    color: const Color(0x18FFFFFF),
                    child: SizedBox(
                      width: widget.diameter,
                      height: widget.diameter,
                      child: foreground == null
                          ? icon
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                icon,
                                IgnorePointer(child: foreground),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
