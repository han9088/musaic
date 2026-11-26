// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/src/foundation/_features.dart' show isWindowingEnabled;
import 'package:flutter/src/widgets/_window.dart';
import 'package:flutter/widgets.dart';

import '../../ui/theme/app_colors.dart';

/// Hosts settings in a second native view of the existing Flutter engine.
class DesktopSettingsWindow extends ChangeNotifier
    with WindowControllerDelegate {
  DesktopSettingsWindow() {
    if (isEnabled && Platform.isMacOS) {
      _macOSWindow.setMethodCallHandler(_onMacOSWindowEvent);
    }
  }

  static const _windowConstraints = BoxConstraints(
    minWidth: 460,
    minHeight: 380,
  );
  static const _macOSWindow = MethodChannel(
    'com.deskbtm.musaic/settings_window',
  );

  static bool get isSupported =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  static bool get isEnabled => isSupported && isWindowingEnabled;

  static void enable() {
    if (isSupported) isWindowingEnabled = true;
  }

  WidgetBuilder? content;
  WindowController? _window;
  FlutterView? _macOSView;
  String _title = 'Settings';
  bool _opening = false;
  bool _disposed = false;

  void updateTitle(String title) {
    if (_disposed || _title == title) return;
    _title = title;
    _window?.setTitle(title);
    if (_macOSView != null) {
      unawaited(_updateMacOSWindow('setTitle', title));
    }
  }

  Future<void> open() async {
    if (_disposed || _opening || content == null) return;
    _opening = true;
    try {
      if (Platform.isMacOS) {
        await _openMacOSWindow();
      } else if (_window case final window?) {
        if (window.isActivated) return;
        if (Platform.isWindows && window.isMaximized) {
          window.setMaximized(true);
        } else {
          window.activate();
        }
      } else {
        final window = _window = WindowController(
          size: const Size(720, 560),
          constraints: _windowConstraints,
          title: _title,
          delegate: this,
        );
        notifyListeners();
        // Let the embedder show the first frame unless hidden windows have paused frames.
        if (!WidgetsBinding.instance.framesEnabled) window.activate();
      }
    } catch (error, stack) {
      debugPrint('Could not open desktop settings: $error\n$stack');
    } finally {
      _opening = false;
    }
  }

  Future<void> _openMacOSWindow() async {
    final title = _title;
    final id = await _macOSWindow.invokeMethod<int>('prepare', title);
    if (id == null) throw StateError('Missing macOS settings view');
    try {
      if (_disposed) {
        await _updateMacOSWindow('close', id);
        return;
      }
      final view = WidgetsBinding.instance.platformDispatcher.views.firstWhere(
        (view) => view.viewId == id,
      );
      if (_macOSView != view) {
        _macOSView = view;
        notifyListeners();
      }
      if (title != _title) await _updateMacOSWindow('setTitle', _title);
      await _macOSWindow.invokeMethod<void>('show', id);
    } catch (_) {
      await _updateMacOSWindow('close', id);
      _detachMacOSView(id);
      rethrow;
    }
  }

  Future<void> _updateMacOSWindow(String method, Object argument) async {
    try {
      await _macOSWindow.invokeMethod<void>(method, argument);
    } catch (error, stack) {
      debugPrint('Could not $method on macOS settings: $error\n$stack');
    }
  }

  Future<void> _onMacOSWindowEvent(MethodCall call) async {
    if (call.method == 'open') {
      await open();
      return;
    }
    if (call.method != 'closed') return;
    if (call.arguments case final int id) _detachMacOSView(id);
  }

  void _detachMacOSView(int id) {
    if (_disposed || _macOSView?.viewId != id) return;
    _macOSView = null;
    notifyListeners();
  }

  Widget attach({
    required Widget child,
    required Widget Function(WidgetBuilder content) buildApp,
  }) => ListenableBuilder(
    listenable: this,
    child: child,
    builder: (context, child) {
      final view = _macOSView ?? _window?.rootView;
      final builder = content;
      return ViewAnchor(
        view: view == null || builder == null
            ? null
            : View(
                view: view,
                child: ColoredBox(
                  color: AppColors.sheetBackground,
                  child: Padding(
                    padding: EdgeInsets.only(top: Platform.isMacOS ? 34 : 0),
                    child: buildApp(builder),
                  ),
                ),
              ),
        child: child!,
      );
    },
  );

  @override
  void onWindowDestroyed() {
    if (_window == null) return;
    _window = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (isEnabled && Platform.isMacOS) {
      _macOSWindow.setMethodCallHandler(null);
      if (_macOSView case final view?) {
        unawaited(_updateMacOSWindow('close', view.viewId));
        _macOSView = null;
      }
    }
    final window = _window;
    _window = null;
    window?.destroy();
    super.dispose();
  }
}
