import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/bottom_sheet_host.dart';
import 'package:musaic/features/canvas/album_canvas_viewport.dart';
import 'package:musaic/features/desktop_shortcuts/desktop_shortcuts_settings.dart';
import 'package:musaic/features/music/playback/now_playing_capsule.dart';
import 'package:musaic/features/settings/settings_sheet.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/pages/home/home_page.dart';
import 'package:musaic/pages/home/home_sheet.dart';
import 'package:musaic/services/mock_album_cache.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _AlbumCache extends MockAlbumCache {
  @override
  Future<List<Map<String, dynamic>>> load() async => [
    {'asset': 'assets/albums/0.jpg', 'title': 'Album', 'artist': 'Artist'},
  ];
}

void main() {
  testWidgets(
    'wallpaper mode closes keyboard settings, keeps the canvas, and restores controls',
    (tester) async {
      final preferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = preferences);
      const channel = MethodChannel('com.deskbtm.musaic/desktop_wallpaper');
      final messenger = tester.binding.defaultBinaryMessenger;
      Object? menuTitles;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'setCloseToBackground') return null;
        expect(call.method, 'setMenuTitles');
        menuTitles = call.arguments;
        return null;
      });
      Future<Object?> platformCall(String method) async {
        Object? response;
        final handled = messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method)),
          (data) => response = channel.codec.decodeEnvelope(data!),
        );
        await tester.pumpAndSettle();
        await handled;
        return response;
      }

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: AppBottomSheetHost(child: HomePage(albumCache: _AlbumCache())),
        ),
      );
      await tester.pump();
      tester.element(find.byType(HomePage)).markNeedsBuild();
      await tester.pump();

      final canvas = find.byType(AlbumCanvasViewport);
      final canvasState = tester.state(canvas);
      expect(menuTitles, {
        'set': '设置成壁纸',
        'restore': '恢复窗口',
        'quit': '退出 Musaic',
      });

      expect(await platformCall('prepare'), isTrue);
      expect(tester.widget<HomeSheet>(find.byType(HomeSheet)).enabled, isFalse);
      expect(tester.state(canvas), same(canvasState));

      await platformCall('didRestore');
      expect(tester.widget<HomeSheet>(find.byType(HomeSheet)).enabled, isTrue);
      expect(tester.state(canvas), same(canvasState));

      await tester.drag(find.byType(NowPlayingCapsule), const Offset(0, -135));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(Tab, PhosphorIcons.gearBold));
      await tester.pumpAndSettle();
      final shortcuts = find.widgetWithText(ListTile, '键盘快捷键');
      await tester.ensureVisible(shortcuts);
      await tester.tap(shortcuts);
      await tester.pumpAndSettle();
      expect(find.byType(DesktopShortcutsSettings), findsOneWidget);

      expect(await platformCall('prepare'), isTrue);
      expect(find.byType(DesktopShortcutsSettings), findsNothing);
      expect(find.byType(SettingsSheet), findsNothing);
      expect(tester.state(canvas), same(canvasState));
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );
}
