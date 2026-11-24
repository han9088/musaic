import 'package:flutter/material.dart';

import 'screensaver_view.dart';

Future<void> showScreensaverDemo(BuildContext context) {
  const duration = Duration(minutes: 3, seconds: 46);
  final elapsed = Stopwatch()..start();
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: ScreensaverView(
          title: 'Random Access Memories',
          artwork: 'assets/albums/7.jpg',
          readPosition: () => Duration(
            seconds: (42 + elapsed.elapsed.inSeconds) % duration.inSeconds,
          ),
        ),
      ),
    ),
  );
}
