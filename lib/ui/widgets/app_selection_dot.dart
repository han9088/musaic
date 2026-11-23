import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// Visual marker for a control that already exposes its selected state.
class AppSelectionDot extends StatelessWidget {
  const AppSelectionDot({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 16,
    child: Center(
      child: SizedBox.square(
        dimension: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.settingsAccent,
          ),
        ),
      ),
    ),
  );
}

/// Aligns a selection marker with the title line, even when a row has a subtitle.
class AppSelectionTitle extends StatelessWidget {
  const AppSelectionTitle({
    super.key,
    required this.selected,
    required this.child,
  });

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      Expanded(child: child),
      if (selected)
        Transform.translate(
          // The glyphs sit slightly below the center of the text line box.
          offset: const Offset(0, 1),
          child: const AppSelectionDot(),
        ),
    ],
  );
}
