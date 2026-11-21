import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

class ManualRotationPreference {
  static const _key = 'settings.manual_rotation';
  final _enabled = signal(false);
  Future<void> _pendingWrite = Future<void>.value();
  bool _changed = false;
  bool _disposed = false;

  ReadonlySignal<bool> get enabled => _enabled;

  Future<void> restore() async {
    try {
      final stored = await SharedPreferencesAsync().getBool(_key);
      if (!_disposed && !_changed && stored != null) _enabled.value = stored;
    } on MissingPluginException {
      // The default still works on hosts without a preference store.
    } catch (error) {
      debugPrint('Could not read manual rotation preference: $error');
    }
  }

  void setEnabled(bool enabled) {
    if (_disposed || enabled == _enabled.value) return;
    _changed = true;
    _enabled.value = enabled;
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await SharedPreferencesAsync().setBool(_key, enabled);
      } on MissingPluginException {
        // Keep the in-memory setting available.
      } catch (error) {
        debugPrint('Could not save manual rotation preference: $error');
      }
    });
  }

  void dispose() {
    _disposed = true;
    _enabled.dispose();
  }
}
