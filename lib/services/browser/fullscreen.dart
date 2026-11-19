// 文件职责：浏览器平台能力及其跨平台兼容实现。

export 'fullscreen_stub.dart'
    if (dart.library.js_interop) 'fullscreen_web.dart';
