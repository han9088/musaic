// 文件职责：桥接桌面窗口操作，并独立分发页面回调与 Linux 会话能力事件。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'desktop_capabilities.dart';

export 'desktop_capabilities.dart';

/// 将当前专辑视图移入原生桌面壁纸窗口，或恢复为普通窗口。
abstract final class DesktopWallpaper {
  static const _channel = OptionalMethodChannel(
    'com.deskbtm.musaic/desktop_wallpaper',
  );

  static final _capabilityChanges =
      StreamController<DesktopCapabilities>.broadcast();
  static final _trayRestoreChanges = StreamController<bool>.broadcast();
  static Future<bool> Function()? _onPrepare;
  static VoidCallback? _onRestore;
  static bool _handlerInstalled = false;

  /// 仅表示平台提供桌面桥接；Linux 的实际能力由当前会话决定。
  static bool get isAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  static bool get _isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  static Stream<DesktopCapabilities> get capabilityChanges {
    _ensureHandler();
    return _capabilityChanges.stream;
  }

  static Stream<bool> get trayRestoreChanges {
    _ensureHandler();
    return _trayRestoreChanges.stream;
  }

  static Future<bool> getTrayRestoreNeeded() async =>
      await _channel.invokeMethod<bool>('getTrayRestoreNeeded') ?? false;

  static Future<void> toggleTrayWindow() =>
      _channel.invokeMethod<void>('toggleTrayWindow');

  static Future<DesktopCapabilities> getCapabilities() async {
    if (!isAvailable) return DesktopCapabilities.unavailable;
    if (!_isLinux) return DesktopCapabilities.standardDesktop;
    _ensureHandler();
    final result = await _channel.invokeMethod<Object?>('getCapabilities');
    return DesktopCapabilities.fromMessage(result);
  }

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
    _onPrepare = onPrepare;
    _onRestore = onRestore;
    _ensureHandler();
  }

  static void clearHandlers() {
    // 页面销毁只清理页面回调，不能中断仍属于应用生命周期的托盘监听。
    _onPrepare = null;
    _onRestore = null;
  }

  static void _ensureHandler() {
    if (!isAvailable || _handlerInstalled) return;
    _channel.setMethodCallHandler(_handleNativeCall);
    _handlerInstalled = true;
  }

  static Future<Object?> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'prepare':
        return await _onPrepare?.call() ?? false;
      case 'didRestore':
        _onRestore?.call();
        return null;
      case 'trayRestoreChanged':
        if (call.arguments case final bool needed) {
          _trayRestoreChanges.add(needed);
        }
        return null;
      case 'capabilitiesChanged':
        if (_isLinux) {
          _capabilityChanges.add(
            DesktopCapabilities.fromMessage(call.arguments),
          );
        }
        return null;
      default:
        throw MissingPluginException();
    }
  }
}
