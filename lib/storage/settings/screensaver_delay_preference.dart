import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

class ScreensaverDelayPreference {
  static const options = [10, 20, 30, 40, 60, 80, 90];
  static const _enabledKey = 'settings.screensaver_enabled';
  static const _key = 'settings.screensaver_delay_seconds';

  final _enabled = signal(true);
  final _seconds = signal(30);
  Future<void> _pendingWrite = Future<void>.value();
  bool _enabledChanged = false;
  bool _changed = false;
  bool _disposed = false;

  ReadonlySignal<bool> get enabled => _enabled;
  ReadonlySignal<int> get seconds => _seconds;

  Future<void> restore() async {
    try {
      final preferences = SharedPreferencesAsync();
      final enabled = await preferences.getBool(_enabledKey);
      if (!_disposed && !_enabledChanged && enabled != null) {
        _enabled.value = enabled;
      }
      final stored = await preferences.getInt(_key);
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

  Future<void> setEnabled(bool enabled) {
    if (_disposed || enabled == _enabled.value) return _pendingWrite;
    _enabledChanged = true;
    _enabled.value = enabled;
    return _save((preferences) => preferences.setBool(_enabledKey, enabled));
  }

  Future<void> select(int seconds) {
    if (_disposed || seconds == _seconds.value || !options.contains(seconds)) {
      return _pendingWrite;
    }
    _changed = true;
    _seconds.value = seconds;
    return _save((preferences) => preferences.setInt(_key, seconds));
  }

  Future<void> _save(Future<void> Function(SharedPreferencesAsync) write) {
    return _pendingWrite = _pendingWrite.then((_) async {
      try {
        await write(SharedPreferencesAsync());
      } on MissingPluginException {
        // Keep the in-memory setting available.
      } catch (error) {
        debugPrint('Could not save screensaver settings: $error');
      }
    });
  }

  void dispose() {
    _disposed = true;
    _enabled.dispose();
    _seconds.dispose();
  }
}
