import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

enum UsageGuideIntro { playback, camera }

class UsageGuidePreference {
  static const _key = 'settings.usage_guide_hidden';
  static final _introReset = ValueNotifier(0);
  final _visible = signal(false);
  Future<void>? _pendingHide;
  bool _disposed = false;

  ReadonlySignal<bool> get visible => _visible;
  static ValueListenable<int> get introReset => _introReset;

  static String _introKey(UsageGuideIntro intro) =>
      'settings.usage_guide_${intro.name}_seen';

  static Future<bool> shouldPlayIntro(UsageGuideIntro intro) async {
    try {
      final preferences = SharedPreferencesAsync();
      final seen = await preferences.getBool(_introKey(intro));
      return switch (seen) {
        true => false,
        false => true,
        null => await preferences.getBool(_key) != true,
      };
    } catch (error) {
      debugPrint('Could not read usage guide intro preference: $error');
      return false;
    }
  }

  static Future<void> markIntroSeen(UsageGuideIntro intro) async {
    try {
      await SharedPreferencesAsync().setBool(_introKey(intro), true);
    } catch (error) {
      debugPrint('Could not save usage guide intro preference: $error');
    }
  }

  static Future<void> resetIntros() async {
    final preferences = SharedPreferencesAsync();
    await Future.wait([
      for (final intro in UsageGuideIntro.values)
        preferences.setBool(_introKey(intro), false),
    ]);
    _introReset.value++;
  }

  Future<void> restore() async {
    var hidden = false;
    try {
      hidden = await SharedPreferencesAsync().getBool(_key) ?? false;
    } on MissingPluginException {
      // The guide remains visible on hosts without a preference store.
    } catch (error) {
      debugPrint('Could not read usage guide preference: $error');
    }
    if (!_disposed && _pendingHide == null) _visible.value = !hidden;
  }

  Future<void> hide() => _pendingHide ??= _hide();

  Future<void> _hide() async {
    if (!_disposed) _visible.value = false;
    try {
      await SharedPreferencesAsync().setBool(_key, true);
    } on MissingPluginException {
      // The guide stays hidden for the current session.
    } catch (error) {
      debugPrint('Could not save usage guide preference: $error');
    }
  }

  void dispose() {
    _disposed = true;
    _visible.dispose();
  }
}
