import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/bottom_sheet_host.dart';
import 'package:musaic/features/artwork/presentation/xerox_palette.dart';
import 'package:musaic/features/artwork/presentation/xerox_palette_picker.dart';
import 'package:musaic/features/music/playback/album_playback.dart';
import 'package:musaic/features/music/playback/now_playing_capsule.dart';
import 'package:musaic/features/settings/settings_sheet.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/pages/home/home_sheet.dart';
import 'package:musaic/pages/settings/settings_page.dart';
import 'package:musaic/services/app_icon_service.dart';
import 'package:musaic/services/music/music_source_controller.dart';
import 'package:musaic/ui/bottom_sheet/bottom_sheet.dart';
import 'package:musaic/ui/dialogs/app_alert_dialog.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  final settingsTab = find.widgetWithIcon(Tab, PhosphorIcons.gearBold);
  final capsule = find.byType(NowPlayingCapsule);
  testWidgets(
    'handle fades after idle, wakes on touch, stays hidden in CoverFlow',
    (tester) async {
      Widget app(bool enabled) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppBottomSheetHost(
          child: HomeSheet(
            enabled: enabled,
            icons: const _Icons(),
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      );
      final opacity = find.descendant(
        of: capsule,
        matching: find.byType(Opacity),
      );
      final backdrop = find.descendant(
        of: capsule,
        matching: find.byType(BackdropFilter),
      );
      DecorationImage? noise() {
        final surface =
            tester.widget<BackdropFilter>(backdrop).child! as DecoratedBox;
        return (surface.decoration as ShapeDecoration).image;
      }

      await tester.pumpWidget(app(true));
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      expect(noise()?.image, const AssetImage(appDialogNoiseAsset));
      final noiseOpacity = noise()!.opacity;
      expect(noiseOpacity, 0.08);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<Opacity>(opacity).opacity, closeTo(0.5, 0.01));
      expect(noise()?.opacity, closeTo(noiseOpacity / 2, 0.001));
      expect(tester.widget<BackdropFilter>(backdrop).enabled, isTrue);
      expect(find.ancestor(of: backdrop, matching: opacity), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<Opacity>(opacity).opacity, 0);
      expect(noise(), isNull);
      expect(tester.widget<BackdropFilter>(backdrop).enabled, isFalse);
      await tester.tapAt(const Offset(100, 100));
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      await tester.pumpWidget(app(false));
      await tester.tapAt(const Offset(100, 100));
      await tester.pump();
      expect(capsule, findsNothing);
      await tester.pumpWidget(app(true));
      expect(tester.widget<Opacity>(opacity).opacity, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('capsule controls playback without extending its hit area', (
    tester,
  ) async {
    final playback = AlbumPlayback();
    addTearDown(playback.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppBottomSheetHost(
          child: HomeSheet(
            playback: playback,
            icons: const _Icons(),
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );
    final sheet = DeskBottomSheet.of(tester.element(find.byType(HomeSheet)));
    expect(find.text('Not playing'), findsOneWidget);
    playback.toggle('demo', 'Demo', artist: 'Demo artist');
    await tester.pump();
    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('Demo artist'), findsOneWidget);
    final rect = tester.getRect(capsule);
    await tester.tapAt(rect.topLeft + const Offset(1, 1));
    await tester.tapAt(rect.bottomCenter + const Offset(0, 1));
    expect(sheet.isPresented, isFalse);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(playback.playing, isFalse);
    expect(sheet.isPresented, isFalse);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Play').hitTestable(), findsNothing);
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(playback.playing, isTrue);
    await tester.tap(find.text('Demo'));
    await tester.pumpAndSettle();
    expect(sheet.isPresented, isFalse);

    final labels = find.descendant(of: capsule, matching: find.byType(Text));
    for (final artist in [
      null,
      '  ',
      ' UnKnOwN ',
      '<unknown>',
      'Unknown Artist',
    ]) {
      playback.toggle('song', 'Song', artist: artist);
      await tester.pump();
      expect(find.text('Song'), findsOneWidget);
      expect(labels, findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Xerox opens in place and closes the sheet when turned off', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final xeroxEnabled = ValueNotifier(false);
    addTearDown(xeroxEnabled.dispose);
    final modeChanges = <({bool enabled, bool homeCurrent, int sheets})>[];
    late final ModalRoute<dynamic> homeRoute;
    late final DeskBottomSheet sheet;
    final palette = ValueNotifier(XeroxPalette.original);
    addTearDown(palette.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppBottomSheetHost(
          child: HomeSheet(
            icons: const _Icons(),
            xeroxEnabled: xeroxEnabled,
            xeroxPalettePicker: XeroxPalettePicker(
              selection: palette,
              onChanged: (value) => palette.value = value,
            ),
            onXeroxChanged: (enabled) {
              modeChanges.add((
                enabled: enabled,
                homeCurrent: homeRoute.isCurrent,
                sheets: sheet.presentedSheetCount,
              ));
              xeroxEnabled.value = enabled;
            },
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    final home = tester.element(find.byType(HomeSheet));
    homeRoute = ModalRoute.of(home)!;
    sheet = DeskBottomSheet.of(home);
    final size = tester.getSize(find.byType(HomeSheet));
    final gesture = await tester.startGesture(tester.getCenter(capsule));
    await gesture.moveBy(const Offset(0, -25));
    await gesture.moveBy(const Offset(0, -50));
    await gesture.moveBy(const Offset(0, -75));
    await gesture.up();
    await tester.pumpAndSettle();

    sheet.topSheetController!.expand();
    await tester.pumpAndSettle();
    final sheetPosition = BottomSheetContent.of(
      tester.element(find.byType(SettingsSheet)),
    ).animatedPosition;
    final originalTop = sheetPosition.value;
    final originalContentTop = tester.getTopLeft(find.byType(SettingsSheet)).dy;

    final toggle = find.byKey(const ValueKey('xerox-toggle'));
    expect(toggle, findsOneWidget);
    final appearance = find.widgetWithText(ListTile, 'Appearance & display');
    await tester.tap(appearance);
    expect(sheetPosition.value, originalTop);
    await tester.pump();
    expect(
      tester.getTopLeft(find.byType(SettingsSheet)).dy,
      originalContentTop,
    );
    await tester.pump();

    final page = find.byType(SettingsPage);
    final pageDistance = size.height - originalTop;
    expect(tester.getTopLeft(page), Offset(0, size.height));
    await tester.pump(const Duration(milliseconds: 120));
    expect(sheetPosition.value, inExclusiveRange(-pageDistance, originalTop));
    expect(
      tester.getTopLeft(page).dy - sheetPosition.value,
      closeTo(pageDistance, 0.1),
    );
    await tester.pumpAndSettle();
    expect(sheetPosition.value, closeTo(-pageDistance, 0.1));
    expect(tester.getRect(page), Offset.zero & size);

    expect(find.descendant(of: page, matching: toggle), findsNothing);
    expect(find.text('App icon'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(sheetPosition.value, inExclusiveRange(-pageDistance, originalTop));
    expect(
      tester.getTopLeft(page).dy - sheetPosition.value,
      closeTo(pageDistance, 0.1),
    );
    await tester.pumpAndSettle();
    expect(sheetPosition.value, originalTop);
    expect(page, findsNothing);
    expect(sheet.isPresented, isTrue);

    expect(tester.widget<ListTile>(toggle).selected, isFalse);
    final picker = find.byType(XeroxPalettePicker);
    expect(picker, findsNothing);
    final sheetId = sheet.topSheetId;
    await tester.tap(toggle);
    await tester.pump();
    expect(modeChanges, [(enabled: true, homeCurrent: true, sheets: 1)]);
    await tester.pumpAndSettle();
    expect(xeroxEnabled.value, isTrue);
    expect(page, findsNothing);
    expect(sheet.topSheetId, sheetId);
    expect(sheetPosition.value, originalTop);

    Future<void> reopenSettings() async {
      await tester.drag(capsule, const Offset(0, -140));
      await tester.pumpAndSettle();
      sheet.topSheetController!.expand();
      await tester.pumpAndSettle();
    }

    expect(tester.widget<ListTile>(toggle).selected, isTrue);
    for (final preset in XeroxPalette.values) {
      final swatch = find.byKey(ValueKey(preset));
      await tester.ensureVisible(swatch);
      await tester.tap(swatch);
      await tester.pump();
      expect(palette.value, preset);
    }
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    final switchOff = tester.widget<ListTile>(toggle).onTap!;
    sheet.present(const SizedBox.expand());
    await tester.pumpAndSettle();
    expect(sheet.presentedSheetCount, 2);
    switchOff();
    await tester.pump();
    expect(modeChanges, hasLength(1));
    await tester.pumpAndSettle();
    expect(modeChanges, [
      (enabled: true, homeCurrent: true, sheets: 1),
      (enabled: false, homeCurrent: true, sheets: 0),
    ]);
    expect(xeroxEnabled.value, isFalse);
    expect(page, findsNothing);
    expect(sheet.isPresented, isFalse);

    await reopenSettings();
    expect(tester.widget<ListTile>(toggle).selected, isFalse);
    expect(picker, findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'settings pull continues past the top to return to its sheet',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppBottomSheetHost(
            child: HomeSheet(icons: _Icons(), child: SizedBox.expand()),
          ),
        ),
      );
      final sheet = DeskBottomSheet.of(tester.element(find.byType(HomeSheet)));
      await tester.drag(capsule, const Offset(0, -140));
      await tester.pumpAndSettle();
      sheet.topSheetController!.expand();
      await tester.pumpAndSettle();
      final sheetPosition = BottomSheetContent.of(
        tester.element(find.byType(SettingsSheet)),
      ).animatedPosition;
      final originalTop = sheetPosition.value;
      await tester.tap(settingsTab);
      await tester.pumpAndSettle();
      final appearance = find.widgetWithText(ListTile, 'Appearance & display');
      await tester.tap(appearance);
      await tester.pumpAndSettle();

      final page = find.byType(SettingsPage);
      final scrollable = find.descendant(
        of: page,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(80);
      await tester.pump();
      final pull = await tester.startGesture(const Offset(160, 160));
      await pull.moveBy(const Offset(0, 25));
      await pull.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(position.pixels, inExclusiveRange(0, 80));
      expect(tester.getTopLeft(page).dy, 0);

      final remainingScroll = position.pixels;
      await pull.moveBy(Offset(0, remainingScroll + 60));
      await tester.pump();
      expect(position.pixels, 0);
      expect(tester.getTopLeft(page).dy, closeTo(60, 2));
      expect(
        tester.getTopLeft(page).dy - sheetPosition.value,
        420 - originalTop,
      );
      await pull.moveBy(const Offset(0, -30));
      await tester.pump();
      expect(position.pixels, 0);
      expect(tester.getTopLeft(page).dy, closeTo(30, 2));
      await pull.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(page).dy, 0);

      Future<TestGesture> pullPastThreshold() async {
        final gesture = await tester.startGesture(const Offset(160, 160));
        await gesture.moveBy(const Offset(0, 25));
        await gesture.moveBy(const Offset(0, 130));
        await tester.pump();
        expect(tester.getTopLeft(page).dy, closeTo(130, 2));
        return gesture;
      }

      final interrupted = await pullPastThreshold();
      await interrupted.cancel();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(page).dy, 0);

      final commit = await pullPastThreshold();
      await commit.up();
      await tester.pumpAndSettle();
      expect(page, findsNothing);
      expect(sheetPosition.value, originalTop);
      expect(appearance, findsOneWidget);
      expect(sheet.isPresented, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('music settings group demo and local sources before switching', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sources = MusicSourceController();
    addTearDown(sources.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppBottomSheetHost(
          child: HomeSheet(
            icons: const _Icons(),
            sources: sources,
            onSourceSelection: (select) async {
              final context = tester.element(find.byType(HomeSheet));
              expect(DeskBottomSheet.of(context).isPresented, isFalse);
              await select();
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    await tester.drag(capsule, const Offset(0, -140));
    await tester.pumpAndSettle();
    final mock2 = find.byKey(const ValueKey('music-source-mock2'));
    expect(mock2, findsOneWidget);
    expect(find.text('Local music'), findsNothing);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.indicatorColor, Colors.transparent);
    expect(tabBar.dividerColor, Colors.transparent);
    expect(find.text('Settings'), findsNothing);
    await tester.tap(settingsTab);
    await tester.pumpAndSettle();
    expect(mock2, findsNothing);
    await tester.tap(find.text('Music source'));
    await tester.pumpAndSettle();
    final page = find.byType(SettingsPage);
    expect(
      find.descendant(of: page, matching: find.text('Demo')),
      findsOneWidget,
    );
    expect(find.text('Device music'), findsOneWidget);
    expect(find.text('Local music'), findsOneWidget);

    final lowerPull = await tester.startGesture(const Offset(180, 650));
    await lowerPull.moveBy(const Offset(0, 24));
    await tester.pump();
    final lowerStart = tester.getTopLeft(page).dy;
    await lowerPull.moveBy(const Offset(0, 215));
    await tester.pump();
    expect(tester.getTopLeft(page).dy - lowerStart, closeTo(215, 2));
    await lowerPull.up();
    await tester.pumpAndSettle();
    expect(page, findsNothing);
    await tester.tap(find.text('Music source'));
    await tester.pumpAndSettle();

    final headerPull = await tester.startGesture(const Offset(180, 28));
    await headerPull.moveBy(const Offset(0, 24));
    await tester.pump();
    final headerStart = tester.getTopLeft(page).dy;
    await headerPull.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(tester.getTopLeft(page).dy - headerStart, closeTo(60, 2));
    await headerPull.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(page).dy, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(page, findsNothing);
    expect(settingsTab, findsOneWidget);
    expect(find.text('Music source'), findsOneWidget);
    expect(mock2, findsNothing);
    await tester.tap(find.text('Music source'));
    await tester.pumpAndSettle();
    await tester.tap(mock2);
    await tester.pumpAndSettle();
    expect(sources.mock2Selected.value, isTrue);
    expect(settingsTab, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dragging the sheet to the bottom restores canvas input', (
    tester,
  ) async {
    const canvasKey = ValueKey('canvas');
    var canvasTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppBottomSheetHost(
          child: HomeSheet(
            icons: const _Icons(),
            child: GestureDetector(
              key: canvasKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => canvasTaps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(HomeSheet));
    final sheet = DeskBottomSheet.of(context);
    final handle = find.byType(BottomSheetHandle);
    final bottom = MediaQuery.sizeOf(context).height;
    for (final (index, cancel) in [false, true].indexed) {
      await tester.drag(capsule, const Offset(0, -140));
      await tester.pumpAndSettle();
      expect(sheet.isPresented, isTrue);

      final position = BottomSheetContent.of(tester.element(handle))
          .animatedPosition;
      final handleBounds = tester.getRect(handle);
      final start = handleBounds.topCenter + const Offset(0, 2);
      final drag = await tester.startGesture(start);
      await drag.moveBy(const Offset(0, 24));
      final nearlyClosed = bottom - handleBounds.height - 49;
      await drag.moveBy(Offset(0, nearlyClosed - position.value));
      await tester.pump();
      expect(position.value, closeTo(nearlyClosed, 0.1));
      expect(tester.takeException(), isNull);
      await drag.moveTo(Offset(start.dx, bottom - 1));
      await tester.pump();
      expect(bottom - position.value, lessThan(handleBounds.height + 8));
      if (cancel) {
        await drag.cancel();
      } else {
        await drag.up();
      }
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byKey(canvasKey)));
      expect(canvasTaps, index + 1);
      expect(sheet.isPresented, isFalse);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'the sheet opens only after releasing a long pull on $platform',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppBottomSheetHost(
              child: HomeSheet(icons: _Icons(), child: SizedBox.expand()),
            ),
          ),
        );
        final context = tester.element(find.byType(HomeSheet));
        final sheet = DeskBottomSheet.of(context);
        await tester.fling(capsule, const Offset(0, -55), 1500);
        await tester.pumpAndSettle();
        expect(sheet.isPresented, isFalse);

        final origin = tester.getCenter(capsule);
        final gesture = await tester.startGesture(origin);
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump();
        expect(tester.getCenter(capsule).dy, lessThan(origin.dy - 12));
        expect(sheet.isPresented, isFalse);
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump();
        expect(sheet.isPresented, isFalse);
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
        expect(sheet.isPresented, isFalse);
        await gesture.moveBy(const Offset(0, 25));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(sheet.isPresented, isFalse);

        final longPull = await tester.startGesture(origin);
        await longPull.moveBy(const Offset(0, -140));
        await tester.pumpAndSettle();
        expect(sheet.isPresented, isFalse);
        await longPull.up();
        expect(sheet.presentedSheetCount, 1);
        await tester.pumpAndSettle();
        expect(sheet.presentedSheetCount, 1);
        sheet.dismiss();
        await tester.pumpAndSettle();
        expect(sheet.isPresented, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}

class _Icons extends AppIconService {
  const _Icons();

  @override
  Future<AppIconSnapshot> read() async =>
      (supported: true, current: AppIconChoice.text);
}
