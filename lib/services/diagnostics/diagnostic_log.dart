import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_dio_logger/dio_logs.dart';
import 'package:talker_flutter/talker_flutter.dart';

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

  late final _talker = _DiagnosticTalker(_capacity, _scheduleSave);
  Talker get talker => _talker;

  SharedPreferencesAsync? _preferences;
  Future<void>? _restoring;
  Future<void> _writing = Future.value();
  Timer? _saveTimer;
  bool _started = false;

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
      if (_talker.wasCleared) return;
      final entries = talker.history;
      final limit = _capacity - entries.length;
      entries.insertAll(
        0,
        saved.reversed
            .map(_restoreEntry)
            .nonNulls
            .take(limit)
            .toList()
            .reversed,
      );
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
      DioException(:final type) => type.name,
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
    final message = [
      event.name,
      if (count != null) 'count=$count',
      if (kind != null) 'error=$kind',
      if (frame != null) 'code=$frame',
    ].join(' ');
    final last = talker.history.lastOrNull;
    if (last != null &&
        last.message == message &&
        now.difference(last.time) < const Duration(seconds: 2)) {
      return;
    }
    final level = error == null ? LogLevel.info : LogLevel.error;
    talker.logCustom(
      TalkerLog(
        message,
        time: now,
        logLevel: level,
        key: TalkerKey.fromLogLevel(level),
      ),
    );
  }

  void _scheduleSave() {
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
        await preferences.setStringList(_storageKey, _serializeHistory());
      } catch (_) {
        // Keep recording in memory when the device cannot save the history.
      }
    });
  }

  Future<List<String>> recentEvents() async {
    await _restoring;
    return _serializeHistory();
  }

  List<String> _serializeHistory() => [
    for (final entry in talker.history)
      '${entry.time.toUtc().toIso8601String()} ${entry.message}',
  ];

  TalkerLog? _restoreEntry(String line) {
    final separator = line.indexOf(' ');
    if (separator < 0) return null;
    final time = DateTime.tryParse(line.substring(0, separator));
    if (time == null) return null;
    final message = line.substring(separator + 1);
    final key = switch (message.split(' ').first) {
      TalkerKey.httpRequest => TalkerKey.httpRequest,
      TalkerKey.httpResponse => TalkerKey.httpResponse,
      TalkerKey.httpError => TalkerKey.httpError,
      _ => message.contains(' error=') ? TalkerKey.error : TalkerKey.info,
    };
    return TalkerLog(
      message,
      time: time,
      key: key,
      title: talker.settings.getTitleByKey(key),
      logLevel: switch (key) {
        TalkerKey.error || TalkerKey.httpError => LogLevel.error,
        TalkerKey.info => LogLevel.info,
        _ => LogLevel.debug,
      },
    );
  }
}

class _DiagnosticTalker extends Talker {
  _DiagnosticTalker(int capacity, this.onChange)
    : super(
        settings:
            TalkerSettings(maxHistoryItems: capacity, useConsoleLogs: false)
              ..registerKeys([
                TalkerKey.httpRequest,
                TalkerKey.httpResponse,
                TalkerKey.httpError,
              ]),
      );

  final VoidCallback onChange;
  bool wasCleared = false;

  @override
  void logCustom(TalkerLog data) {
    // Pass only diagnostic metadata to Talker's history, stream and console.
    super.logCustom(switch (data) {
      DioRequestLog(:final requestOptions) => _networkLog(data, requestOptions),
      DioResponseLog(:final response, :final responseTime) => _networkLog(
        data,
        response.requestOptions,
        status: response.statusCode,
        duration: responseTime,
      ),
      DioErrorLog(:final dioException, :final responseTime) => _networkLog(
        data,
        dioException.requestOptions,
        status: dioException.response?.statusCode,
        duration: responseTime,
        error: dioException.type,
      ),
      _ => data,
    });
    onChange();
  }

  @override
  void cleanHistory() {
    if (!settings.useHistory) return;
    super.cleanHistory();
    wasCleared = true;
    onChange();
  }

  TalkerLog _networkLog(
    TalkerLog data,
    RequestOptions request, {
    int? status,
    int? duration,
    DioExceptionType? error,
  }) => TalkerLog(
    [
      data.key,
      request.method,
      request.uri.host,
      if (status != null) 'status=$status',
      if (duration != null) 'durationMs=$duration',
      if (error != null) 'error=${error.name}',
    ].join(' '),
    time: data.time,
    key: data.key,
    title: data.title,
    logLevel: data.logLevel,
  );
}
