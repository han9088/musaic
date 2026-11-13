import 'package:material_ui/material_ui.dart';

/// Tap target above the sheet panel.
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
