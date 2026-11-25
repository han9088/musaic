import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

class ScreensaverDelayPreference {
  static const options = [10, 20, 30, 40, 60, 80, 90];
  static const _key = 'settings.screensaver_delay_seconds';

  final _seconds = signal(30);
  Future<void> _pendingWrite = Future<void>.value();
  bool _changed = false;
  bool _disposed = false;

  ReadonlySignal<int> get seconds => _seconds;

  Future<void> restore() async {
    try {
      final stored = await SharedPreferencesAsync().getInt(_key);
      if (!_disposed &&
          !_changed &&
          stored != null &&
          options.contains(stored)) {
        _seconds.value = stored;
      }
    } on MissingPluginException {
      // The default remains available without a preference store.
    } catch (error) {
      debugPrint('Could not read screensaver delay: $error');
    }
  }

  Future<void> select(int seconds) {
    if (_disposed || seconds == _seconds.value || !options.contains(seconds)) {
      return _pendingWrite;
    }
    _changed = true;
    _seconds.value = seconds;
    return _pendingWrite = _pendingWrite.then((_) async {
      try {
        await SharedPreferencesAsync().setInt(_key, seconds);
      } on MissingPluginException {
        // Keep the in-memory setting available.
      } catch (error) {
        debugPrint('Could not save screensaver delay: $error');
      }
    });
  }

  void dispose() {
    _disposed = true;
    _seconds.dispose();
  }
}
