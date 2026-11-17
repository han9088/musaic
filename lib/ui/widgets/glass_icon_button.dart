import 'dart:ui';

import 'package:material_ui/material_ui.dart';

class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.diameter = 30,
    this.iconSize,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double diameter;
  final double? iconSize;
  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
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
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: widget.iconSize ?? widget.diameter * 16 / 30,
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
