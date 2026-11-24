import 'package:shared_preferences/shared_preferences.dart';

class DesktopShortcutPreferences {
  final _preferences = SharedPreferencesAsync();

  String _key(String action) => 'settings.desktop_shortcut.$action';

  Future<String?> read(String action) => _preferences.getString(_key(action));

  Future<void> write(String action, String? value) => value == null
      ? _preferences.remove(_key(action))
      : _preferences.setString(_key(action), value);
}
