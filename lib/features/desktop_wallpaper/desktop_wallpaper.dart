import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Moves the current album view to or from the native desktop wallpaper window.
abstract final class DesktopWallpaper {
  static const _channel = OptionalMethodChannel(
    'com.deskbtm.musaic/desktop_wallpaper',
  );

  static bool get isAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  static Future<void> setCloseToBackground(bool enabled) =>
      _channel.invokeMethod<void>('setCloseToBackground', enabled);

  static Future<void> embedWindow() =>
      _channel.invokeMethod<void>('embedWindow');

  static Future<void> restoreWindow() =>
      _channel.invokeMethod<void>('restoreWindow');

  /// 托盘创建成功后才允许原生窗口依赖它作为恢复入口。
  static Future<void> setTrayReady(bool ready) =>
      _channel.invokeMethod<void>('setTrayReady', ready);

  static Future<void> quit() => _channel.invokeMethod<void>('quit');

  static void setHandlers({
    required Future<bool> Function() onPrepare,
    required VoidCallback onRestore,
  }) {
    if (!isAvailable) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'prepare':
          return await onPrepare();
        case 'didRestore':
          onRestore();
          return null;
        default:
          throw MissingPluginException();
      }
    });
  }

  static void clearHandlers() {
    if (isAvailable) _channel.setMethodCallHandler(null);
  }
}
