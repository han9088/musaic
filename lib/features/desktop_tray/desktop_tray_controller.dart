// 文件职责：管理系统托盘资源，并按 Linux 会话能力安全地建立恢复入口。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart' as tray;

import '../../l10n/generated/app_localizations.dart';
import '../desktop_wallpaper/desktop_wallpaper.dart';

class DesktopTrayController {
  tray.TrayIcon? _icon;
  tray.Image? _image;
  tray.Menu? _menu;
  tray.MenuItem? _wallpaper;
  tray.MenuItem? _restore;
  tray.MenuItem? _quit;
  AppLocalizations? _localizations;
  DesktopCapabilities? _capabilities;
  StreamSubscription<DesktopCapabilities>? _capabilitySubscription;
  int? _trayRevision;
  int _capabilityEvents = 0;
  int _configurationVersion = 0;
  int _resourceGeneration = 0;
  bool _started = false;
  bool _syncPending = false;
  bool _synchronizing = false;
  bool _disposed = false;
  bool _runningAction = false;

  static bool get isAvailable => DesktopWallpaper.isAvailable;

  static bool get _isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// 语言变化只更新现有菜单；Linux 托盘宿主重启才重建原生资源。
  void updateLocale(AppLocalizations l10n) {
    if (_disposed || !isAvailable) return;
    _localizations = l10n;
    ++_configurationVersion;
    if (!_started) {
      _started = true;
      if (_isLinux) {
        _watchLinuxCapabilities();
      } else {
        _capabilities = DesktopCapabilities.standardDesktop;
      }
    }
    _scheduleSync();
  }

  void _watchLinuxCapabilities() {
    // 先订阅再读取快照，避免查询期间发生的面板变化被旧结果覆盖。
    _capabilitySubscription = DesktopWallpaper.capabilityChanges.listen((next) {
      ++_capabilityEvents;
      _updateCapabilities(next);
    });
    unawaited(_readInitialCapabilities(_capabilityEvents));
  }

  Future<void> _readInitialCapabilities(int eventVersion) async {
    try {
      final capabilities = await DesktopWallpaper.getCapabilities();
      if (!_disposed && eventVersion == _capabilityEvents) {
        _updateCapabilities(capabilities);
      }
    } catch (error, stack) {
      debugPrint('Could not read desktop capabilities: $error\n$stack');
      if (!_disposed && eventVersion == _capabilityEvents) {
        _updateCapabilities(DesktopCapabilities.unavailable);
      }
    }
  }

  void _updateCapabilities(DesktopCapabilities next) {
    if (_disposed || next == _capabilities) return;
    final previous = _capabilities;
    if (previous != null && next.trayRevision < previous.trayRevision) return;
    _capabilities = next;
    ++_configurationVersion;
    _scheduleSync();
  }

  void _scheduleSync() {
    _syncPending = true;
    if (_synchronizing) return;
    _synchronizing = true;
    unawaited(_synchronize());
  }

  Future<void> _synchronize() async {
    try {
      while (_syncPending) {
        _syncPending = false;
        try {
          await _synchronizeOnce();
        } catch (error, stack) {
          debugPrint('Could not configure desktop tray: $error\n$stack');
          await _release();
        }
      }
    } finally {
      _synchronizing = false;
    }
  }

  Future<void> _synchronizeOnce() async {
    final l10n = _localizations;
    final capabilities = _capabilities;
    final version = _configurationVersion;
    if (_disposed ||
        l10n == null ||
        capabilities == null ||
        !capabilities.trayHost) {
      await _release();
      return;
    }
    if (_icon == null || _trayRevision != capabilities.trayRevision) {
      // 先撤销原生恢复能力，再释放旧图标；异步期间的新配置由下一轮处理。
      await _release();
      if (_disposed || version != _configurationVersion) return;
      _create(l10n, capabilities);
      await _setTrayReady(true);
    } else {
      _wallpaper?.label = l10n.desktopWallpaperSet;
      _wallpaper?.isEnabled = capabilities.wallpaper;
      _restore?.label = l10n.desktopWallpaperRestore;
      _quit?.label = l10n.desktopShortcutsQuit;
      _icon?.setTooltip(l10n.appTitle);
    }
  }

  void _create(AppLocalizations l10n, DesktopCapabilities capabilities) {
    final icon = _icon = tray.TrayIcon.create() ??
        (throw StateError('Could not create tray icon'));
    // Linux 在 D-Bus 导出失败时仍可能返回对象，此时不能把窗口交给托盘恢复。
    if (_isLinux && !icon.isVisible()) {
      throw StateError('Could not export Linux tray icon');
    }
    final menu = _menu = tray.Menu.create() ??
        (throw StateError('Could not create tray menu'));
    final generation = _resourceGeneration;

    _wallpaper = _addItem(
      menu,
      l10n.desktopWallpaperSet,
      _embedWindow,
      enabled: capabilities.wallpaper,
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
    // macOS 点击打开菜单；Linux 面板负责展示已导出的菜单。
    icon.setContextMenuTrigger(
      defaultTargetPlatform == TargetPlatform.macOS
          ? tray.ContextMenuTrigger.clicked
          : tray.ContextMenuTrigger.rightClicked,
    );
    if (defaultTargetPlatform == TargetPlatform.windows) {
      icon.addListener((event) {
        if (event is tray.TrayIconClickedEvent) {
          unawaited(_run(DesktopWallpaper.restoreWindow, generation));
        }
      });
    }
    icon.isIconTemplate = defaultTargetPlatform == TargetPlatform.macOS;
    final image = _image =
        tray.ImageAsset.fromAsset('assets/branding/vinyl.png') ??
        (throw StateError('Could not load tray icon image'));
    icon.icon = image;
    if (!icon.setVisible(true)) {
      throw StateError('Could not show tray icon');
    }
    _trayRevision = capabilities.trayRevision;
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
    final generation = _resourceGeneration;
    item.isEnabled = enabled;
    item.addListener((event) {
      if (event is tray.MenuItemClickedEvent) {
        unawaited(_run(action, generation));
      }
    });
    menu.addItem(item);
    return item;
  }

  Future<void> _embedWindow() async {
    if (_capabilities?.wallpaper == true) {
      await DesktopWallpaper.embedWindow();
    }
  }

  Future<void> _run(
    Future<void> Function() action,
    int generation,
  ) async {
    if (_disposed || _runningAction || generation != _resourceGeneration) {
      return;
    }
    _runningAction = true;
    try {
      // 等原生菜单完成点击回调，且只执行仍属于当前图标的操作。
      await Future<void>.delayed(Duration.zero);
      if (!_disposed && generation == _resourceGeneration) await action();
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

  Future<void> _release() async {
    ++_resourceGeneration;
    await _setTrayReady(false);
    final disposers = <void Function()>[
      if (_icon case final icon?) icon.dispose,
      if (_menu case final menu?) menu.dispose,
      if (_wallpaper case final item?) item.dispose,
      if (_restore case final item?) item.dispose,
      if (_quit case final item?) item.dispose,
      if (_image case final image?) image.dispose,
    ];
    _icon = null;
    _menu = null;
    _wallpaper = _restore = _quit = null;
    _image = null;
    _trayRevision = null;
    for (final dispose in disposers) {
      try {
        dispose();
      } catch (error) {
        debugPrint('Could not release desktop tray resource: $error');
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_configurationVersion;
    final subscription = _capabilitySubscription;
    _capabilitySubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _scheduleSync();
  }
}
