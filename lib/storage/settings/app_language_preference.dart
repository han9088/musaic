import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

enum AppLanguage {
  system(null),
  simplifiedChinese(Locale('zh')),
  english(Locale('en'));

  const AppLanguage(this.locale);

  final Locale? locale;
}

class AppLanguagePreference {
  AppLanguagePreference(AppLanguage initial) : _selected = signal(initial);

  static const _key = 'settings.app_language';
  final Signal<AppLanguage> _selected;
  Future<void> _pendingWrite = Future<void>.value();

  ReadonlySignal<AppLanguage> get selected => _selected;

  static Future<AppLanguage> load() async {
    try {
      final stored = await SharedPreferencesAsync().getString(_key);
      return AppLanguage.values.firstWhere(
        (language) => language.name == stored,
        orElse: () => AppLanguage.system,
      );
    } on MissingPluginException {
      return AppLanguage.system;
    } catch (error) {
      debugPrint('Could not read app language preference: $error');
      return AppLanguage.system;
    }
  }

  void select(AppLanguage language) {
    if (language == _selected.value) return;
    _selected.value = language;
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await SharedPreferencesAsync().setString(_key, language.name);
      } on MissingPluginException {
        // Keep the in-memory setting available.
      } catch (error) {
        debugPrint('Could not save app language preference: $error');
      }
    });
  }

  void dispose() => _selected.dispose();
}
