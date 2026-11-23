import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DeveloperOptionsPreference {
  static const _key = 'settings.developer_options_enabled';
  final _enabled = signal(false);
  Future<void>? _pendingEnable;
  bool _disposed = false;

  ReadonlySignal<bool> get enabled => _enabled;

  Future<void> restore() async {
    try {
      final stored = await SharedPreferencesAsync().getBool(_key);
      if (!_disposed && _pendingEnable == null) _enabled.value = stored == true;
    } catch (error) {
      debugPrint('Could not read developer options preference: $error');
    }
  }

  Future<void> enable() => _pendingEnable ??= _enable();

  Future<void> _enable() async {
    if (_disposed || _enabled.value) return;
    _enabled.value = true;
    try {
      await SharedPreferencesAsync().setBool(_key, true);
    } catch (error) {
      debugPrint('Could not save developer options preference: $error');
    }
  }

  void dispose() {
    _disposed = true;
    _enabled.dispose();
  }
}
