// 文件职责：浏览器平台能力及其跨平台兼容实现。

import 'package:flutter/foundation.dart';

/// 封装或定义浏览器全屏相关类型与行为，负责浏览器平台能力及其跨平台兼容实现。
class BrowserFullscreen extends ChangeNotifier {
  /// 执行当前模块中的supported操作，用于浏览器平台能力及其跨平台兼容实现。
  bool get supported => false;

  /// 执行当前模块中的active操作，用于浏览器平台能力及其跨平台兼容实现。
  bool get active => false;

  /// 应用选择并更新对应状态，用于浏览器平台能力及其跨平台兼容实现。
  Future<void> toggle() => Future.error(
    UnsupportedError('Browser fullscreen is unavailable on native platforms'),
  );
}
