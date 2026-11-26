import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/services/diagnostics/diagnostic_log.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
        log.record(DiagnosticEvent.frameworkError, error: error, stack: stack);
      }

      expect(await log.recentEvents(), [
        endsWith(
          'frameworkError error=platform code=services/music/example.dart:24:5',
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
