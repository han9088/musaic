import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../storage/settings/desktop_shortcut_preferences.dart';
import '../desktop_wallpaper/desktop_wallpaper.dart';
import '../music/playback/album_playback.dart';

enum DesktopShortcut {
  playPause(PhysicalKeyboardKey.keyP),
  seekBackward(PhysicalKeyboardKey.arrowLeft),
  seekForward(PhysicalKeyboardKey.arrowRight),
  previousTrack(PhysicalKeyboardKey.arrowUp),
  nextTrack(PhysicalKeyboardKey.arrowDown),
  restoreWindow(PhysicalKeyboardKey.keyR),
  embedWindow(PhysicalKeyboardKey.keyE);

  const DesktopShortcut(this.defaultKey);

  final PhysicalKeyboardKey defaultKey;

  HotKey get defaultBinding => binding(defaultKey, [
    if (_isMac) HotKeyModifier.meta else HotKeyModifier.control,
    HotKeyModifier.alt,
    HotKeyModifier.shift,
  ]);

  HotKey binding(PhysicalKeyboardKey key, List<HotKeyModifier> modifiers) =>
      HotKey(identifier: 'musaic.$name', key: key, modifiers: modifiers);
}

bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

String desktopShortcutLabel(HotKey binding) {
  final keys = binding.modifiers?.toSet() ?? {};
  final modifiers = [
    if (keys.contains(HotKeyModifier.control)) _isMac ? '⌃' : 'Ctrl',
    if (keys.contains(HotKeyModifier.alt)) _isMac ? '⌥' : 'Alt',
    if (keys.contains(HotKeyModifier.shift)) _isMac ? '⇧' : 'Shift',
    if (keys.contains(HotKeyModifier.meta)) _isMac ? '⌘' : 'Win',
  ];
  final label = binding.physicalKey.keyLabel;
  return _isMac
      ? '${modifiers.join()} $label'
      : [...modifiers, label].join(' + ');
}

enum ShortcutChange { saved, duplicate, unavailable, saveFailed }

class DesktopShortcuts {
  DesktopShortcuts(this._playback) {
    ready = _initialize();
  }

  final AlbumPlayback _playback;
  final _preferences = DesktopShortcutPreferences();
  final _bindings = <DesktopShortcut, HotKey>{};
  late final Future<void> ready;
  void Function(HotKey)? _capture;
  bool _disposed = false;

  // Linux 托盘与壁纸不自动启用全局快捷键，避免启动时触发 Wayland 授权。
  static bool get isAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  HotKey binding(DesktopShortcut action) =>
      _bindings[action] ?? action.defaultBinding;

  bool isRegistered(DesktopShortcut action) => hotKeyManager
      .registeredHotKeyList
      .any((hotkey) => hotkey.identifier == binding(action).identifier);

  VoidCallback capture(void Function(HotKey) onCaptured) {
    _capture = onCaptured;
    return () => _capture = null;
  }

  Future<void> _initialize() async {
    await _setCloseToBackground(false);
    await _clearRegistrations();
    for (final action in DesktopShortcut.values) {
      if (_disposed) return;
      final stored = await _readBinding(action);
      if (_disposed) return;
      _bindings[action] = stored;
      await _register(action, stored);
    }
    if (!_disposed) {
      await _setCloseToBackground(isRegistered(DesktopShortcut.restoreWindow));
    }
  }

  Future<HotKey> _readBinding(DesktopShortcut action) async {
    try {
      if (await _preferences.read(action.name) case final stored?) {
        final saved = HotKey.fromJson(
          jsonDecode(stored) as Map<String, dynamic>,
        );
        return action.binding(saved.physicalKey, saved.modifiers ?? []);
      }
    } catch (error) {
      debugPrint('Could not read ${action.name} shortcut: $error');
    }
    return action.defaultBinding;
  }

  Future<ShortcutChange> change(DesktopShortcut action, HotKey? custom) async {
    await ready;
    if (_disposed) return ShortcutChange.unavailable;
    final next = custom == null
        ? action.defaultBinding
        : action.binding(custom.physicalKey, custom.modifiers ?? []);
    final duplicate = _bindings.entries.any((entry) {
      final other = entry.value;
      return entry.key != action &&
          other.physicalKey == next.physicalKey &&
          setEquals(other.modifiers?.toSet(), next.modifiers?.toSet());
    });
    if (duplicate) return ShortcutChange.duplicate;
    if (!await _register(action, next) || _disposed) {
      return ShortcutChange.unavailable;
    }

    _bindings[action] = next;
    if (action == DesktopShortcut.restoreWindow) {
      await _setCloseToBackground(true);
    }
    try {
      await _preferences.write(
        action.name,
        custom == null ? null : jsonEncode(next.toJson()),
      );
    } catch (error) {
      debugPrint('Could not save ${action.name} shortcut: $error');
      return ShortcutChange.saveFailed;
    }
    return ShortcutChange.saved;
  }

  Future<bool> _register(DesktopShortcut action, HotKey binding) async {
    void activate(HotKey binding) => _activate(action, binding);
    try {
      await hotKeyManager.register(
        binding,
        keyDownHandler: _isMac ? null : activate,
        keyUpHandler: _isMac ? activate : null,
      );
      return true;
    } catch (error) {
      debugPrint('Could not register ${action.name} shortcut: $error');
      return false;
    }
  }

  void _activate(DesktopShortcut action, HotKey binding) {
    if (_disposed) return;
    if (_capture case final capture?) {
      capture(binding);
      if (action != DesktopShortcut.restoreWindow) return;
    }
    switch (action) {
      case DesktopShortcut.playPause:
        _playback.toggleCurrent();
      case DesktopShortcut.seekBackward:
        _playback.seekStep(forward: false);
      case DesktopShortcut.seekForward:
        _playback.seekStep(forward: true);
      case DesktopShortcut.previousTrack:
        _playback.skip(forward: false);
      case DesktopShortcut.nextTrack:
        _playback.skip(forward: true);
      case DesktopShortcut.restoreWindow:
        unawaited(DesktopWallpaper.restoreWindow());
      case DesktopShortcut.embedWindow:
        unawaited(DesktopWallpaper.embedWindow());
    }
  }

  Future<void> _setCloseToBackground(bool enabled) async {
    try {
      await DesktopWallpaper.setCloseToBackground(enabled);
    } catch (error) {
      debugPrint('Could not update background window behavior: $error');
    }
  }

  Future<void> _clearRegistrations() async {
    try {
      await hotKeyManager.unregisterAll();
    } catch (error) {
      debugPrint('Could not clear desktop shortcuts: $error');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _capture = null;
    await Future.wait([_setCloseToBackground(false), _clearRegistrations()]);
  }
}
