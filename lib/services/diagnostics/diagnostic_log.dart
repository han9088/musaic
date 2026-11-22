import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

final diagnosticLog = DiagnosticLog();

enum DiagnosticEvent {
  appStarted,
  appResumed,
  appHidden,
  frameworkError,
  unhandledError,
  musicRestoreStarted,
  musicRestoreCompleted,
  musicRestoreFailed,
  demoSourceSelected,
  secondDemoSourceSelected,
  musicSourceSwitchFailed,
  musicSourceTransitionFailed,
  localLibrarySelected,
  localAccessDenied,
  localAccessRestricted,
  localAccessUnavailable,
  localLibraryLoaded,
  localLibraryFailed,
  directorySourceSelected,
  directorySourceFailed,
  directoryScanStarted,
  directoryRescanStarted,
  directoryScanCompleted,
  directoryScanCancelled,
  directoryScanFailed,
  playbackStarted,
  playbackResumed,
  playbackPaused,
  playbackNext,
  playbackPrevious,
  playbackSeekFailed,
  playbackCommandFailed,
  playbackStreamFailed,
  playbackPlayerFailed,
  playbackAdvanceFailed,
  coverFlowShown,
  canvasShown,
  xeroxEnabled,
  xeroxDisabled,
  xeroxTransitionFailed,
  cameraOpened,
  cameraAccessDenied,
  cameraUnavailable,
  cameraOpenFailed,
  cameraPhotoSaved,
  cameraPhotoFailed,
  updateFound,
  updateCurrent,
  updateNoRelease,
  updateCheckFailed,
  appIconChanged,
  appIconChangeFailed,
  reportExportFailed,
  reportMailUnavailable,
  reportMailFailed,
}

/// Bounded, local history of app events, counts, and sanitized error details.
class DiagnosticLog {
  static const _storageKey = 'diagnostics.recentEvents.v1';
  static const _capacity = 300;
  static final _appFrame = RegExp(
    r'\(package:musaic/([a-z0-9_/]+\.dart:\d+:\d+)\)',
  );

  final _entries = ListQueue<String>();
  SharedPreferencesAsync? _preferences;
  Future<void> _restoring = Future.value();
  Future<void> _writing = Future.value();
  Timer? _saveTimer;
  bool _started = false;
  ({DiagnosticEvent event, int? count, String? error, String? frame})? _last;
  DateTime? _lastTime;

  void start() {
    if (_started) return;
    _started = true;
    try {
      final preferences = _preferences = SharedPreferencesAsync();
      _restoring = _restore(preferences);
    } catch (_) {
      // Other app features can start even when preferences are unavailable.
    }
    record(DiagnosticEvent.appStarted);
  }

  Future<void> _restore(SharedPreferencesAsync preferences) async {
    try {
      final saved = await preferences.getStringList(_storageKey) ?? const [];
      final limit = _capacity - _entries.length;
      for (final entry in saved.reversed.take(limit)) {
        _entries.addFirst(entry);
      }
    } catch (_) {
      // Diagnostics must remain available for this session if storage fails.
    }
  }

  void record(
    DiagnosticEvent event, {
    int? count,
    Object? error,
    StackTrace? stack,
  }) {
    final now = DateTime.now().toUtc();
    final kind = switch (error) {
      null => null,
      MissingPluginException() => 'missingPlugin',
      PlatformException() => 'platform',
      FlutterError() => 'flutter',
      StateError() => 'state',
      ArgumentError() => 'argument',
      FormatException() => 'format',
      TimeoutException() => 'timeout',
      UnsupportedError() => 'unsupported',
      TypeError() => 'type',
      _ => 'other',
    };
    final frame = stack == null
        ? null
        : _appFrame.firstMatch(stack.toString())?.group(1);
    final entry = (event: event, count: count, error: kind, frame: frame);
    if (_last == entry &&
        now.difference(_lastTime!) < const Duration(seconds: 2)) {
      return;
    }
    _last = entry;
    _lastTime = now;
    _entries.addLast(
      [
        now.toIso8601String(),
        event.name,
        if (count != null) 'count=$count',
        if (kind != null) 'error=$kind',
        if (frame != null) 'code=$frame',
      ].join(' '),
    );
    if (_entries.length > _capacity) _entries.removeFirst();
    if (_preferences != null) {
      _saveTimer ??= Timer(
        const Duration(seconds: 1),
        () => unawaited(flush()),
      );
    }
  }

  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final preferences = _preferences;
    if (preferences == null) return Future.value();
    return _writing = _writing.then((_) async {
      await _restoring;
      try {
        await preferences.setStringList(_storageKey, _entries.toList());
      } catch (_) {
        // Keep recording in memory when the device cannot save the history.
      }
    });
  }

  Future<List<String>> recentEvents() async {
    await _restoring;
    return List.unmodifiable(_entries);
  }
}
