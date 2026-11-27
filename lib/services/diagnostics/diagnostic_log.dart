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

enum DiagnosticOperation {
  addDirectory,
  loadDirectoryCache,
  saveDirectorySelection,
  restoreDirectory,
  scanDirectory,
  readAudioMetadata,
  publishDirectoryCatalog,
  disposePreviousSource,
  playAlbum,
  playTrack,
  pause,
  resume,
  next,
  previous,
  seek,
}

/// Bounded, local history of app events, counts, and sanitized error details.
class DiagnosticLog {
  static const _storageKey = 'diagnostics.recentEvents.v1';
  static const _capacity = 300;
  static const _errorWindow = Duration(seconds: 2);
  static const _errorsPerEventWindow = 4;
  static final _appFrame = RegExp(
    r'\(package:musaic/([a-z0-9_/]+\.dart:\d+:\d+)\)',
  );
  static final _frameworkFrame = RegExp(
    r'\(package:flutter/src/([a-z0-9_/]+\.dart:\d+:\d+)\)',
  );
  // Plugin errors can carry file paths even in fields intended for error codes.
  static const _platformCodes = {
    'busy',
    'cancelled',
    'detached',
    'directoryError',
    'directoryUnavailable',
    'fileChanged',
    'invalidArgument',
    'metadataFailed',
    'music_library',
    'notFound',
    'permissionDenied',
    'pickerFailed',
    'unavailable',
    'NoActivity',
    'PermissionRequestFailed',
    'QueryCancelled',
    'QueryFailed',
    'AndroidAudioError',
    'DarwinAudioError',
  };
  static const _androidAudioReasons = {
    'MEDIA_ERROR_IO',
    'MEDIA_ERROR_MALFORMED',
    'MEDIA_ERROR_SERVER_DIED',
    'MEDIA_ERROR_SYSTEM',
    'MEDIA_ERROR_TIMED_OUT',
    'MEDIA_ERROR_UNSUPPORTED',
    'FileNotFoundException',
    'IOException',
    'IllegalArgumentException',
    'IllegalStateException',
    'SecurityException',
  };
  static const _frameworkLibraries = {
    'gesture': 'gestures',
    'gesture library': 'gestures',
    'gestures library': 'gestures',
    'image resource service': 'images',
    'painting library': 'painting',
    'rendering library': 'rendering',
    'scheduler library': 'scheduler',
    'services library': 'services',
    'widgets': 'widgets',
    'widgets library': 'widgets',
    'music source transition': 'musicSourceTransition',
    'Xerox mode transition': 'xeroxModeTransition',
    'Xerox raster preparation': 'xeroxRasterPreparation',
  };

  late final _talker = _DiagnosticTalker(_capacity, _historyChanged);
  Talker get talker => _talker;

  final _errorClock = Stopwatch()..start();
  final _errorSamples = <DiagnosticEvent, ({int untilMs, int count})>{};
  SharedPreferencesAsync? _preferences;
  Future<void>? _restoring;
  Future<void>? _writing;
  Timer? _saveTimer;
  bool _dirty = false;
  bool _flushAgain = false;
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

  bool record(
    DiagnosticEvent event, {
    int? count,
    int? failedCount,
    Duration? duration,
    DiagnosticOperation? operation,
    Object? error,
    StackTrace? stack,
    String? frameworkLibrary,
  }) {
    if (error != null && !_sampleError(event)) return false;
    final now = DateTime.timestamp();
    var message = event.name;
    if (count != null ||
        failedCount != null ||
        duration != null ||
        operation != null) {
      message = [
        message,
        if (count != null) 'count=$count',
        if (failedCount != null) 'failedCount=$failedCount',
        if (duration != null) 'durationMs=${duration.inMilliseconds}',
        if (operation != null) 'operation=${operation.name}',
      ].join(' ');
    }
    if (error != null) {
      message = _withErrorDetails(message, error, stack, frameworkLibrary);
    }
    final last = talker.history.lastOrNull;
    if (last != null &&
        last.message == message &&
        now.difference(last.time) < _errorWindow) {
      return false;
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
    return true;
  }

  bool _sampleError(DiagnosticEvent event) {
    final nowMs = _errorClock.elapsedMilliseconds;
    final sample = _errorSamples[event];
    if (sample == null || nowMs >= sample.untilMs) {
      _errorSamples[event] = (
        untilMs: nowMs + _errorWindow.inMilliseconds,
        count: 1,
      );
      return true;
    }
    if (sample.count >= _errorsPerEventWindow) return false;
    _errorSamples[event] = (untilMs: sample.untilMs, count: sample.count + 1);
    return true;
  }

  static String _withErrorDetails(
    String message,
    Object error,
    StackTrace? stack,
    String? frameworkLibrary,
  ) {
    final kind = switch (error) {
      DioException(:final type) => type.name,
      MissingPluginException() => 'missingPlugin',
      PlatformException() => 'platform',
      FlutterError() => 'flutter',
      AssertionError() => 'assertion',
      StateError() => 'state',
      RangeError() => 'range',
      ArgumentError() => 'argument',
      FormatException() => 'format',
      TimeoutException() => 'timeout',
      UnsupportedError() => 'unsupported',
      TypeError() => 'type',
      _ => 'other',
    };
    final platformCode = switch (error) {
      PlatformException(code: 'Unexpected AndroidAudioError') =>
        'UnexpectedAndroidAudioError',
      PlatformException(:final code) when _platformCodes.contains(code) => code,
      _ => null,
    };
    final reasons = switch (error) {
      PlatformException(
        code: 'AndroidAudioError' || 'Unexpected AndroidAudioError',
        :final message,
        :final details,
      ) =>
        {
          if (_androidAudioReasons.contains(message)) message!,
          if (details is String && details.length <= 128)
            ...details.split(', ').where(_androidAudioReasons.contains),
        },
      _ => const <String>{},
    };
    final trace = stack ?? (error is Error ? error.stackTrace : null);
    final frames = trace?.toString();
    final frame = frames == null
        ? null
        : _appFrame.firstMatch(frames)?.group(1);
    final frameworkFrame = frames == null
        ? null
        : _frameworkFrame.firstMatch(frames)?.group(1);
    final library = _frameworkLibraries[frameworkLibrary];
    return [
      message,
      'error=$kind',
      if (platformCode != null) 'platformCode=$platformCode',
      if (reasons.isNotEmpty) 'nativeReason=${reasons.join(',')}',
      if (library != null) 'library=$library',
      if (frame != null) 'code=$frame',
      if (frameworkFrame != null) 'frameworkCode=$frameworkFrame',
    ].join(' ');
  }

  void _historyChanged(bool cleared) {
    if (cleared) _errorSamples.clear();
    _dirty = true;
    _scheduleSave();
  }

  void _scheduleSave() {
    if (_preferences != null && _writing == null && _dirty) {
      _saveTimer ??= Timer(
        const Duration(seconds: 1),
        () => unawaited(flush()),
      );
    }
  }

  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_writing case final writing?) {
      if (_dirty) _flushAgain = true;
      return writing;
    }
    final preferences = _preferences;
    if (preferences == null || !_dirty) return Future.value();
    return _writing = _save(preferences);
  }

  Future<void> _save(SharedPreferencesAsync preferences) async {
    var scheduleFollowUp = true;
    try {
      await _restoring;
      do {
        _flushAgain = false;
        _dirty = false;
        try {
          await preferences.setStringList(_storageKey, _serializeHistory());
        } catch (_) {
          // Leave a failed snapshot pending without retrying on a timer loop.
          scheduleFollowUp = _dirty;
          _dirty = true;
          return;
        }
      } while (_flushAgain && _dirty);
    } finally {
      _writing = null;
      if (scheduleFollowUp) _scheduleSave();
    }
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

  final void Function(bool cleared) onChange;
  bool wasCleared = false;

  @override
  void logCustom(TalkerLog data) {
    // Pass only diagnostic metadata to Talker's history, stream and console.
    final entry = switch (data) {
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
    };
    super.logCustom(entry);
    if (identical(history.lastOrNull, entry)) onChange(false);
  }

  @override
  void cleanHistory() {
    if (!settings.useHistory) return;
    super.cleanHistory();
    wasCleared = true;
    onChange(true);
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
