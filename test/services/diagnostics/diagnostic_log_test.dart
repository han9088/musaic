import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/services/diagnostics/diagnostic_log.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  test(
    'keeps the latest events on disk and restores them before new events',
    () async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);

      final first = DiagnosticLog()..start();
      for (var count = 0; count < 305; count++) {
        first.record(DiagnosticEvent.localLibraryLoaded, count: count);
      }
      await first.flush();

      final next = DiagnosticLog()..start();
      final history = await next.recentEvents();
      expect(history, hasLength(300));
      expect(history.first, endsWith('localLibraryLoaded count=6'));
      expect(history[298], endsWith('localLibraryLoaded count=304'));
      expect(history.last, endsWith('appStarted'));
      await next.flush();
    },
  );

  test(
    'retains only a normalized error and an application code location',
    () async {
      final log = DiagnosticLog();
      final error = PlatformException(
        code: 'person@example.com',
        message: 'Could not open /Users/someone/private-song.mp3',
        details: 'account=private',
      );
      final stack = StackTrace.fromString(
        '#0 loadFile (/Users/someone/private-song.dart:12:3)\n'
        '#1 scan (package:musaic/services/music/example.dart:24:5)',
      );
      for (var index = 0; index < 2; index++) {
        log.record(
          DiagnosticEvent.frameworkError,
          error: error,
          stack: stack,
          frameworkLibrary: '/Users/someone/private-song.dart',
        );
      }

      expect(await log.recentEvents(), [
        endsWith(
          'frameworkError error=platform code=services/music/example.dart:24:5',
        ),
      ]);
    },
  );

  test('samples an error burst before formatting stacks', () async {
    final log = DiagnosticLog();
    final error = StateError('layout failed');
    final stack = _CountingStack();
    for (var index = 0; index < 1000; index++) {
      log.record(
        DiagnosticEvent.frameworkError,
        error: error,
        stack: stack,
        frameworkLibrary: 'rendering library',
      );
      log.record(DiagnosticEvent.appResumed);
    }
    expect(stack.formats, 4);
    expect(
      log.talker.history.where(
        (entry) => entry.message?.startsWith('frameworkError ') ?? false,
      ),
      hasLength(4),
    );
    expect(
      log.record(
        DiagnosticEvent.frameworkError,
        error: error,
        stack: stack,
        frameworkLibrary: 'widgets library',
      ),
      isTrue,
    );
    expect(stack.formats, 5);
  });

  test(
    'slow storage coalesces repeated flushes and keeps new entries',
    () async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      final preferences = _BlockingPreferences();
      SharedPreferencesAsyncPlatform.instance = preferences;
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);

      final log = DiagnosticLog()..start();
      final initialFlush = log.flush();
      await preferences.started.future;
      final pending = <Future<void>>[];
      for (var count = 0; count < 100; count++) {
        log.record(DiagnosticEvent.localLibraryLoaded, count: count);
        pending.add(log.flush());
      }
      expect(preferences.snapshots, hasLength(1));
      expect(pending, everyElement(same(initialFlush)));
      preferences.finish.complete();
      await Future.wait(pending);
      expect(preferences.snapshots, hasLength(2));
      expect(
        preferences.snapshots.last.last,
        endsWith('localLibraryLoaded count=99'),
      );
      await log.flush();
      expect(preferences.snapshots, hasLength(2));
    },
  );

  test(
    'a pending flush tries the latest snapshot after a write fails',
    () async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      final preferences = _BlockingPreferences();
      SharedPreferencesAsyncPlatform.instance = preferences;
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);

      final log = DiagnosticLog()..start();
      unawaited(log.flush());
      await preferences.started.future;
      log.record(DiagnosticEvent.appHidden);
      final hiddenFlush = log.flush();
      preferences.finish.completeError(StateError('Storage unavailable'));
      await hiddenFlush;

      expect(preferences.snapshots, hasLength(2));
      expect(preferences.snapshots.last.last, endsWith('appHidden'));
      await log.flush();
      expect(preferences.snapshots, hasLength(2));
    },
  );

  test('retains known native codes with the failed operation', () async {
    final log = DiagnosticLog();
    log.record(
      DiagnosticEvent.directorySourceFailed,
      operation: DiagnosticOperation.addDirectory,
      error: PlatformException(
        code: 'permissionDenied',
        message: 'Cannot open /private/Music',
        details: 'token=private',
      ),
    );
    log.record(
      DiagnosticEvent.playbackCommandFailed,
      operation: DiagnosticOperation.playAlbum,
      error: PlatformException(
        code: 'AndroidAudioError',
        message: 'Failed to open content://private/song',
        details: 'MEDIA_ERROR_SYSTEM, file:///private/song.mp3',
      ),
    );
    expect(await log.recentEvents(), [
      endsWith(
        'directorySourceFailed operation=addDirectory '
        'error=platform platformCode=permissionDenied',
      ),
      endsWith(
        'playbackCommandFailed operation=playAlbum '
        'error=platform platformCode=AndroidAudioError '
        'nativeReason=MEDIA_ERROR_SYSTEM',
      ),
    ]);
  });

  test('retains macOS error codes without private paths', () async {
    final log = DiagnosticLog();
    log.record(
      DiagnosticEvent.localLibraryFailed,
      error: PlatformException(
        code: 'music_library',
        message: 'Cannot play /private/Music/Track.m4a',
      ),
    );
    log.record(
      DiagnosticEvent.directoryScanFailed,
      operation: DiagnosticOperation.restoreDirectory,
      error: PlatformException(
        code: 'directoryUnavailable',
        message: 'Cannot restore /private/Music',
      ),
    );
    expect(await log.recentEvents(), [
      endsWith('localLibraryFailed error=platform platformCode=music_library'),
      endsWith(
        'directoryScanFailed operation=restoreDirectory '
        'error=platform platformCode=directoryUnavailable',
      ),
    ]);
  });

  test(
    'retains the Flutter subsystem and source frame without app frames',
    () async {
      final log = DiagnosticLog();
      log.record(
        DiagnosticEvent.frameworkError,
        error: FlutterError('Private content in an exception'),
        frameworkLibrary: 'rendering library',
        stack: StackTrace.fromString(
          '#0 paint (/private/user/file.dart:1:2)\n'
          '#1 RenderObject.paint (package:flutter/src/rendering/object.dart:3300:7)',
        ),
      );
      expect(await log.recentEvents(), [
        endsWith(
          'frameworkError error=flutter library=rendering '
          'frameworkCode=rendering/object.dart:3300:7',
        ),
      ]);
    },
  );

  test(
    'keeps saving after Talker settings change and history is cleared',
    () async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);

      final log = DiagnosticLog()..start();
      await log.recentEvents();
      log.talker.configure(settings: log.talker.settings.copyWith());
      log.record(DiagnosticEvent.cameraAccessDenied);
      await log.flush();

      final restored = DiagnosticLog()..start();
      expect(
        await restored.recentEvents(),
        contains(endsWith('cameraAccessDenied')),
      );
      restored.talker.cleanHistory();
      await restored.flush();

      final reopened = DiagnosticLog()..start();
      expect(await reopened.recentEvents(), [endsWith('appStarted')]);
      await reopened.flush();
    },
  );
}

final class _CountingStack implements StackTrace {
  int formats = 0;

  @override
  String toString() {
    formats++;
    return '#0 paint (package:musaic/features/canvas/example.dart:17:3)';
  }
}

final class _BlockingPreferences extends InMemorySharedPreferencesAsync {
  _BlockingPreferences() : super.empty();

  final started = Completer<void>();
  final finish = Completer<void>();
  final snapshots = <List<String>>[];

  @override
  Future<bool> setStringList(
    String key,
    List<String> value,
    SharedPreferencesOptions options,
  ) async {
    snapshots.add(value);
    if (snapshots.length == 1) {
      started.complete();
      await finish.future;
    }
    return super.setStringList(key, value, options);
  }
}
