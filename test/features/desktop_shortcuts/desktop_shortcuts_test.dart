import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/desktop_shortcuts/desktop_shortcuts.dart';
import 'package:musaic/features/desktop_shortcuts/desktop_shortcuts_settings.dart';
import 'package:musaic/features/music/playback/album_playback.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Playback extends AlbumPlayback {
  final actions = <DesktopShortcut>[];

  @override
  void toggleCurrent() => actions.add(DesktopShortcut.playPause);

  @override
  void seekStep({required bool forward}) => actions.add(
    forward ? DesktopShortcut.seekForward : DesktopShortcut.seekBackward,
  );

  @override
  void skip({required bool forward}) => actions.add(
    forward ? DesktopShortcut.nextTrack : DesktopShortcut.previousTrack,
  );
}

class _HotKeys extends HotKeyManagerPlatform {
  final events = StreamController<Map<Object?, Object?>>.broadcast(sync: true);
  final registered = <String, HotKey>{};
  PhysicalKeyboardKey? occupied = PhysicalKeyboardKey.keyR;

  @override
  Stream<Map<Object?, Object?>> get onKeyEventReceiver => events.stream;

  @override
  Future<void> register(HotKey hotKey) async {
    if (hotKey.physicalKey == occupied) {
      throw PlatformException(code: 'register_failed');
    }
    registered[hotKey.identifier] = hotKey;
  }

  @override
  Future<void> unregister(HotKey hotKey) async {
    registered.remove(hotKey.identifier);
  }

  @override
  Future<void> unregisterAll() async => registered.clear();

  void press(DesktopShortcut action) {
    events.add({
      'type': defaultTargetPlatform == TargetPlatform.macOS
          ? 'onKeyUp'
          : 'onKeyDown',
      'data': {'identifier': action.defaultBinding.identifier},
    });
  }
}

void main() {
  testWidgets(
    'routes actions and persists a conflict-free recovery shortcut',
    (tester) async {
      final priorPlatform = HotKeyManagerPlatform.instance;
      final priorPreferences = SharedPreferencesAsyncPlatform.instance;
      final hotkeys = _HotKeys();
      HotKeyManagerPlatform.instance = hotkeys;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final calls = <MethodCall>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      const windowChannel = MethodChannel(
        'com.deskbtm.musaic/desktop_wallpaper',
      );
      messenger.setMockMethodCallHandler(windowChannel, (call) async {
        calls.add(call);
        return null;
      });
      final playback = _Playback();
      final shortcuts = DesktopShortcuts(playback);
      await shortcuts.ready;
      try {
        const restore = DesktopShortcut.restoreWindow;
        expect(shortcuts.isRegistered(restore), isFalse);
        expect(calls.last.arguments, isFalse);

        const playbackActions = [
          DesktopShortcut.playPause,
          DesktopShortcut.seekBackward,
          DesktopShortcut.seekForward,
          DesktopShortcut.previousTrack,
          DesktopShortcut.nextTrack,
        ];
        playbackActions.forEach(hotkeys.press);
        expect(playback.actions, playbackActions);
        hotkeys.press(DesktopShortcut.embedWindow);
        expect(calls.last.method, 'embedWindow');

        expect(
          await shortcuts.change(
            restore,
            DesktopShortcut.playPause.defaultBinding,
          ),
          ShortcutChange.duplicate,
        );
        final custom = restore.binding(PhysicalKeyboardKey.keyF, [
          HotKeyModifier.control,
          HotKeyModifier.shift,
        ]);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DesktopShortcutsSettings(shortcuts: shortcuts),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Restore Window'));
        await tester.pumpAndSettle();
        hotkeys.press(DesktopShortcut.playPause);
        await tester.pumpAndSettle();
        expect(playback.actions, playbackActions);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(
          find.text('Another Musaic action already uses this shortcut.'),
          findsOneWidget,
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.text(desktopShortcutLabel(custom)), findsOneWidget);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(calls.last.arguments, isTrue);
        expect(
          await shortcuts.change(restore, null),
          ShortcutChange.unavailable,
        );
        expect(shortcuts.binding(restore).physicalKey, custom.physicalKey);
        expect(shortcuts.isRegistered(restore), isTrue);
        hotkeys.press(restore);
        expect(calls.last.method, 'restoreWindow');

        await shortcuts.dispose();
        final reopened = DesktopShortcuts(playback);
        try {
          await reopened.ready;
          expect(reopened.binding(restore).physicalKey, custom.physicalKey);
          hotkeys.occupied = null;
          expect(await reopened.change(restore, null), ShortcutChange.saved);
          expect(reopened.binding(restore).physicalKey, restore.defaultKey);
        } finally {
          await reopened.dispose();
        }
      } finally {
        await shortcuts.dispose();
        playback.dispose();
        await hotkeys.events.close();
        HotKeyManagerPlatform.instance = priorPlatform;
        SharedPreferencesAsyncPlatform.instance = priorPreferences;
      }
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );

  test('desktop shortcuts are unavailable on mobile', () {
    expect(DesktopShortcuts.isAvailable, isFalse);
  });
}
