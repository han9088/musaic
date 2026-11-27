// 文件职责：应用启动、依赖初始化与根组件挂载。

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:audioplayers/audioplayers.dart' show AudioLogger, AudioLogLevel;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'features/settings/desktop_settings_window.dart';
import 'services/diagnostics/diagnostic_log.dart';
import 'storage/settings/app_language_preference.dart';

Future<void> main() async {
  DesktopSettingsWindow.enable();
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode) AudioLogger.logLevel = AudioLogLevel.none;
  diagnosticLog.start();
  final onFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    final recorded = diagnosticLog.record(
      DiagnosticEvent.frameworkError,
      error: details.exception,
      stack: details.stack,
      frameworkLibrary: details.library,
    );
    if (recorded ||
        !kReleaseMode ||
        onFlutterError != FlutterError.dumpErrorToConsole) {
      onFlutterError?.call(details);
    }
  };
  final dispatcher = PlatformDispatcher.instance;
  final onUnhandledError = dispatcher.onError;
  dispatcher.onError = (error, stack) {
    final recorded = diagnosticLog.record(
      DiagnosticEvent.unhandledError,
      error: error,
      stack: stack,
    );
    if (recorded) unawaited(diagnosticLog.flush());
    return onUnhandledError?.call(error, stack) ?? false;
  };
  GoogleFonts.config.allowRuntimeFetching = false;
  final language = await AppLanguagePreference.load();
  runApp(MusaicApp(initialLanguage: language));
}
