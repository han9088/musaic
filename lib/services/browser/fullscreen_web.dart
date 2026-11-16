import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('document.fullscreenEnabled')
external bool? get _enabled;
@JS('document.fullscreenElement')
external JSObject? get _element;
@JS('document.documentElement.requestFullscreen')
external JSPromise<JSAny?> _enter();
@JS('document.exitFullscreen')
external JSPromise<JSAny?> _exit();
@JS('document.addEventListener')
external void _listen(String event, JSFunction listener);
@JS('document.removeEventListener')
external void _unlisten(String event, JSFunction listener);

class BrowserFullscreen extends ChangeNotifier {
  BrowserFullscreen() {
    _listen('fullscreenchange', _changed);
  }

  late final JSFunction _changed = ((JSAny? _) => notifyListeners()).toJS;

  bool get supported => _enabled == true;
  bool get active => _element != null;

  // Call synchronously from the user's action to retain browser activation.
  Future<void> toggle() => (active ? _exit() : _enter()).toDart;

  @override
  void dispose() {
    _unlisten('fullscreenchange', _changed);
    super.dispose();
  }
}
