// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/src/foundation/_features.dart' show isWindowingEnabled;
import 'package:flutter/src/widgets/_window.dart';
import 'package:flutter/widgets.dart';

import '../../ui/theme/app_colors.dart';

/// Hosts settings in a second native view of the existing Flutter engine.
class DesktopSettingsWindow extends ChangeNotifier
    with RegularWindowControllerDelegate {
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
  RegularWindowController? _window;
  FlutterView? _macOSView;
  bool _disposed = false;

  Future<void> open(String title) async {
    if (_disposed || content == null) return;
    if (Platform.isMacOS) {
      await _openMacOSWindow(title);
      return;
    }
    if (_window case final window?) {
      if (window.title != title) window.setTitle(title);
      if (window.isMinimized) window.setMinimized(false);
      window.activate();
      return;
    }
    final window = RegularWindowController(
      size: const Size(720, 560),
      constraints: _windowConstraints,
      title: title,
      delegate: this,
    );
    _window = window;
    notifyListeners();
    window.activate();
  }

  Future<void> _openMacOSWindow(String title) async {
    final id = await _macOSWindow.invokeMethod<int>('prepare', title);
    if (id == null) throw StateError('Missing macOS settings view');
    try {
      if (_disposed) {
        await _macOSWindow.invokeMethod<void>('close', id);
        return;
      }
      final view = WidgetsBinding.instance.platformDispatcher.views.firstWhere(
        (view) => view.viewId == id,
      );
      if (_macOSView != view) {
        _macOSView = view;
        notifyListeners();
      }
      await _macOSWindow.invokeMethod<void>('show', id);
    } catch (_) {
      await _macOSWindow.invokeMethod<void>('close', id);
      rethrow;
    }
  }

  Future<void> _onMacOSWindowEvent(MethodCall call) async {
    if (call.method != 'closed' || _macOSView?.viewId != call.arguments) return;
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
        unawaited(_macOSWindow.invokeMethod<void>('close', view.viewId));
        _macOSView = null;
      }
    }
    final window = _window;
    _window = null;
    window?.destroy();
    super.dispose();
  }
}
