import 'dart:async';

import 'package:flutter/widgets.dart';

class DeveloperOptionsUnlock extends StatefulWidget {
  const DeveloperOptionsUnlock({
    super.key,
    required this.onUnlock,
    required this.child,
  });

  final VoidCallback onUnlock;
  final Widget child;

  @override
  State<DeveloperOptionsUnlock> createState() => _DeveloperOptionsUnlockState();
}

class _DeveloperOptionsUnlockState extends State<DeveloperOptionsUnlock> {
  Timer? _reset;
  int _taps = 0;

  void _tap() {
    _reset?.cancel();
    if (++_taps == 5) {
      _taps = 0;
      widget.onUnlock();
      return;
    }
    _reset = Timer(const Duration(milliseconds: 900), () => _taps = 0);
  }

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    excludeFromSemantics: true,
    onTap: _tap,
    child: widget.child,
  );
}
