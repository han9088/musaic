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

  static Future<void> setMenuTitles({
    required String setWallpaper,
    required String restoreWindow,
    required String quit,
  }) => _channel.invokeMethod<void>('setMenuTitles', {
    'set': setWallpaper,
    'restore': restoreWindow,
    'quit': quit,
  });

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
