import 'package:flutter/foundation.dart';

class BrowserFullscreen extends ChangeNotifier {
  bool get supported => false;
  bool get active => false;
  Future<void> toggle() => Future.error(
    UnsupportedError('Browser fullscreen is unavailable on native platforms'),
  );
}
