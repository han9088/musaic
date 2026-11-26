// 文件职责：管理系统托盘的原生资源、菜单与操作分发。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart' as tray;

import '../../l10n/generated/app_localizations.dart';
import '../desktop_wallpaper/desktop_wallpaper.dart';

class DesktopTrayController {
  tray.TrayIcon? _icon;
  tray.Menu? _menu;
  tray.MenuItem? _wallpaper;
  tray.MenuItem? _restore;
  tray.MenuItem? _quit;
  bool _disposed = false;
  bool _runningAction = false;

  static bool get isAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// 原生菜单只创建一次，切换应用语言时原地更新标题。
  void updateLocale(AppLocalizations l10n) {
    if (_disposed || !isAvailable) return;
    try {
      if (_icon == null) {
        _initialize(l10n);
      } else {
        _wallpaper?.label = l10n.desktopWallpaperSet;
        _restore?.label = l10n.desktopWallpaperRestore;
        _quit?.label = l10n.desktopShortcutsQuit;
        _icon?.setTooltip(l10n.appTitle);
      }
    } catch (error, stack) {
      debugPrint('Could not configure desktop tray: $error\n$stack');
      _release();
    }
  }

  void _initialize(AppLocalizations l10n) {
    final icon = _icon = tray.TrayIcon.create() ??
        (throw StateError('Could not create tray icon'));
    final menu = _menu = tray.Menu.create() ??
        (throw StateError('Could not create tray menu'));

    _wallpaper = _addItem(
      menu,
      l10n.desktopWallpaperSet,
      DesktopWallpaper.embedWindow,
      enabled: DesktopWallpaper.isAvailable,
    );
    _restore = _addItem(
      menu,
      l10n.desktopWallpaperRestore,
      DesktopWallpaper.restoreWindow,
    );
    menu.addSeparator();
    _quit = _addItem(menu, l10n.desktopShortcutsQuit, DesktopWallpaper.quit);

    icon.setTooltip(l10n.appTitle);
    icon.setContextMenu(menu);
    // macOS 菜单栏使用主键打开菜单；Linux 由桌面面板负责展示菜单。
    icon.setContextMenuTrigger(
      defaultTargetPlatform == TargetPlatform.macOS
          ? tray.ContextMenuTrigger.clicked
          : tray.ContextMenuTrigger.rightClicked,
    );
    if (defaultTargetPlatform == TargetPlatform.windows) {
      icon.addListener((event) {
        if (event is tray.TrayIconClickedEvent) {
          unawaited(_run(DesktopWallpaper.restoreWindow));
        }
      });
    }
    icon.isIconTemplate = defaultTargetPlatform == TargetPlatform.macOS;
    icon.icon = tray.ImageAsset.fromAsset('assets/branding/vinyl.png');
    if (DesktopWallpaper.isAvailable) {
      unawaited(_setTrayReady(true));
    }
  }

  tray.MenuItem _addItem(
    tray.Menu menu,
    String label,
    Future<void> Function() action, {
    bool enabled = true,
  }) {
    final item = tray.MenuItem.createWithLabelAndType(
      label,
      tray.MenuItemType.normal,
    ) ?? (throw StateError('Could not create tray menu item'));
    item.isEnabled = enabled;
    if (enabled) {
      item.addListener((event) {
        if (event is tray.MenuItemClickedEvent) {
          unawaited(_run(action));
        }
      });
    }
    menu.addItem(item);
    return item;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_disposed || _runningAction) return;
    _runningAction = true;
    try {
      // 让原生菜单先完成点击回调，再发起窗口操作。
      await Future<void>.delayed(Duration.zero);
      if (!_disposed) await action();
    } catch (error, stack) {
      debugPrint('Desktop tray action failed: $error\n$stack');
    } finally {
      _runningAction = false;
    }
  }

  Future<void> _setTrayReady(bool ready) async {
    try {
      await DesktopWallpaper.setTrayReady(ready);
    } catch (error) {
      debugPrint('Could not update tray availability: $error');
    }
  }

  void _release() {
    if (DesktopWallpaper.isAvailable) {
      unawaited(_setTrayReady(false));
    }
    _icon?.dispose();
    _icon = null;
    _menu?.dispose();
    _menu = null;
    _wallpaper?.dispose();
    _restore?.dispose();
    _quit?.dispose();
    _wallpaper = _restore = _quit = null;
  }

  void dispose() {
    _disposed = true;
    _release();
  }
}
