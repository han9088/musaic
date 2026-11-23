import 'package:flutter/widgets.dart';

class GuideTouchIndicator extends StatelessWidget {
  const GuideTouchIndicator({super.key});

  static const diameter = 24.0;

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: diameter,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0x4DFFFFFF),
        shape: BoxShape.circle,
      ),
    ),
  );
}
