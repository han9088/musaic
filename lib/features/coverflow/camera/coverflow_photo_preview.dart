import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Shrinks the captured scene into a temporary thumbnail.
class CoverFlowPhotoPreview extends StatefulWidget {
  const CoverFlowPhotoPreview({
    super.key,
    required this.image,
    required this.reduceMotion,
    required this.label,
    required this.onTap,
    required this.onDismissed,
  });

  final ui.Image image;
  final bool reduceMotion;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  State<CoverFlowPhotoPreview> createState() => _CoverFlowPhotoPreviewState();
}

class _CoverFlowPhotoPreviewState extends State<CoverFlowPhotoPreview>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(vsync: this);
  Timer? _hold;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _motion.addStatusListener(_onMotionStatus);
    _motion.animateTo(
      1,
      duration: widget.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _onMotionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_leaving) {
      widget.onDismissed();
      return;
    }
    _hold = Timer(const Duration(seconds: 3), () {
      if (widget.reduceMotion) {
        widget.onDismissed();
        return;
      }
      _leaving = true;
      _motion.value = 0;
      _motion.animateTo(
        1,
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeInCubic,
      );
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final width = math.min(104.0, size.width * 0.19);
        final thumb = Rect.fromLTWH(
          size.width - padding.right - 12 - width,
          padding.top + 12,
          width,
          width * widget.image.height / widget.image.width,
        );
        return AnimatedBuilder(
          animation: _motion,
          child: Semantics(
            label: widget.label,
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: RawImage(image: widget.image, fit: BoxFit.fill),
            ),
          ),
          builder: (context, child) {
            final rect = _leaving
                ? thumb.shift(
                    Offset((size.width - thumb.left) * _motion.value, 0),
                  )
                : Rect.lerp(Offset.zero & size, thumb, _motion.value)!;
            return Stack(
              children: [Positioned.fromRect(rect: rect, child: child!)],
            );
          },
        );
      },
    );
  }
}
