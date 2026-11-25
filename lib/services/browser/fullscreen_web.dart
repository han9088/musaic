// 文件职责：浏览器平台能力及其跨平台兼容实现。

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

/// 封装或定义浏览器全屏相关类型与行为，负责浏览器平台能力及其跨平台兼容实现。
class BrowserFullscreen extends ChangeNotifier {
  BrowserFullscreen() {
    _listen('fullscreenchange', _changed);
  }

  late final JSFunction _changed = ((JSAny? _) => notifyListeners()).toJS;

  /// 执行当前模块中的supported操作，用于浏览器平台能力及其跨平台兼容实现。
  bool get supported => _enabled == true;

  /// 执行当前模块中的active操作，用于浏览器平台能力及其跨平台兼容实现。
  bool get active => _element != null;

  // 必须在用户手势回调中同步调用，才能保留浏览器授予的用户激活状态。
  /// 应用选择并更新对应状态，用于浏览器平台能力及其跨平台兼容实现。
  Future<void> toggle() => (active ? _exit() : _enter()).toDart;

  @override
  void dispose() {
    _unlisten('fullscreenchange', _changed);
    super.dispose();
  }
}
