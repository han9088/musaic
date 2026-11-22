import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
import 'package:musaic/ui/thinking_orbs/thinking_orb.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  final settingsTab = find.widgetWithIcon(Tab, PhosphorIcons.gearBold);
  final capsule = find.byType(NowPlayingCapsule);

  testWidgets('Support ends settings and shares the public Musaic link', (
    tester,
  ) async {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final messages = tester.binding.defaultBinaryMessenger;
    MethodCall? shareCall;
    messages.setMockMethodCallHandler(channel, (call) async {
      shareCall = call;
      return '';
    });
    addTearDown(() => messages.setMockMethodCallHandler(channel, null));

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
    await tester.drag(capsule, const Offset(0, -140));
    await tester.pumpAndSettle();
    final sheet = DeskBottomSheet.of(tester.element(find.byType(HomeSheet)));
    sheet.topSheetController!.expand();
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsSheet)),
    );
    final about = find.widgetWithText(ListTile, l10n.settingsAbout);
    final support = find.text(l10n.settingsSupport);
    final rate = find.widgetWithText(ListTile, l10n.settingsRateApp);
    final share = find.widgetWithText(ListTile, l10n.settingsShareApp);
    expect(tester.getTopLeft(support).dx - tester.getTopLeft(about).dx, 28);
    expect(
      tester.getTopLeft(support).dy,
      greaterThan(tester.getBottomLeft(about).dy),
    );
    expect(
      tester.getTopLeft(share).dy,
      greaterThan(tester.getTopLeft(rate).dy),
    );
    await tester.ensureVisible(share);
    await tester.pumpAndSettle();
    await tester.tap(share);
    await tester.pumpAndSettle();

    expect(shareCall?.method, 'share');
    expect(
      shareCall?.arguments,
      containsPair('uri', 'https://musaic.deskbtm.com'),
    );
    expect(shareCall?.arguments, containsPair('originWidth', greaterThan(0)));
    expect(find.byType(SettingsPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('About is the only page under About & help', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Musaic',
      packageName: 'com.deskbtm.musaic',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    late Future<http.Response> response;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppBottomSheetHost(
              child: HomeSheet(
                icons: _Icons(),
                child: ColoredBox(color: Colors.black),
              ),
            ),
          ),
        );
        await tester.drag(capsule, const Offset(0, -150));
        await tester.pumpAndSettle();
        final sheet = DeskBottomSheet.of(
          tester.element(find.byType(HomeSheet)),
        );
        sheet.topSheetController!.expand();
        await tester.pumpAndSettle();
        expect(find.text('About & help'), findsOneWidget);
        final diagnostics = find.widgetWithText(ListTile, 'Troubleshooting');
        expect(tester.widget<ListTile>(diagnostics).onTap, isNull);
        expect(tester.widget<ListTile>(diagnostics).trailing, isNull);
        final aboutEntry = find.widgetWithText(ListTile, 'About Musaic');
        final entryArrow = tester.widget<Icon>(
          find.descendant(
            of: aboutEntry,
            matching: find.byIcon(PhosphorIcons.caretUp),
          ),
        );
        expect(entryArrow.size, 12);
        expect(find.byType(SettingsPage), findsNothing);

        await tester.tap(aboutEntry);
        await tester.pumpAndSettle();
        final about = find.byWidgetPredicate(
          (widget) => widget is SettingsPage && widget.title == 'About Musaic',
        );
        expect(about, findsOneWidget);
        expect(
          find.byIcon(PhosphorIcons.caretDown).hitTestable(),
          findsOneWidget,
        );
        final aboutRows = tester.widgetList<ListTile>(
          find.descendant(of: about, matching: find.byType(ListTile)),
        );
        expect(aboutRows.map((row) => row.leading), everyElement(isNull));
        final versionLabel = find.text('Version');
        final versionValue = find.text('1.0.0 (1)');
        expect(tester.getTopLeft(versionLabel).dx, 28);
        expect(
          tester.getSize(about).width - tester.getTopRight(versionValue).dx,
          28,
        );
        expect(
          tester.getTopLeft(versionValue).dx,
          greaterThan(tester.getTopRight(versionLabel).dx),
        );
        final detailArrows = tester.widgetList<Icon>(
          find.descendant(
            of: about,
            matching: find.byIcon(PhosphorIcons.caretLeft),
          ),
        );
        expect(detailArrows.map((icon) => icon.size), [12, 12]);

        Future<void> closeDialog() async {
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
        }

        for (final (status, body, message) in [
          (404, '', 'No public releases are available yet.'),
          (
            200,
            '{"tag_name":"v1.0.0+1"}',
            'You’re on the latest published version.',
          ),
          (200, '{"tag_name":"v1.0.0+2"}', 'Version 1.0.0+2 is available.'),
          (503, '', 'Couldn’t check for updates. Try again later.'),
        ]) {
          final result = http.Response(body, status);
          final pending = status == 404 ? Completer<http.Response>() : null;
          response = pending?.future ?? Future.value(result);
          await tester.tap(find.widgetWithText(ListTile, 'Version'));
          final loader = find.byType(ThinkingOrb);
          if (pending != null) {
            await tester.pump();
            final orb = tester.widget<ThinkingOrb>(loader);
            expect(orb.state, ThinkingOrbState.working);
            expect(orb.size, ThinkingOrbSize.inline);
            expect(
              tester.getTopLeft(loader).dx,
              greaterThan(tester.getTopRight(versionValue).dx),
            );
            pending.complete(result);
          }
          await tester.pumpAndSettle();
          expect(loader, findsNothing);
          expect(find.text(message), findsOneWidget);
          if (body.contains('+2')) {
            expect(find.text('View release'), findsOneWidget);
          }
          await closeDialog();
        }

        for (final item in ['Privacy policy', 'What’s New']) {
          final detail = find.byWidgetPredicate(
            (widget) => widget is SettingsPage && widget.title == item,
          );
          final width = tester.getSize(about).width;
          await tester.tap(find.widgetWithText(ListTile, item));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 140));
          expect(tester.getTopLeft(about).dx, inExclusiveRange(-width, 0));
          expect(tester.getTopLeft(detail).dx, inExclusiveRange(0, width));
          expect(
            tester.getTopLeft(detail).dx - tester.getTopLeft(about).dx,
            closeTo(width, 0.01),
          );
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(detail), Offset.zero);
          final body = tester.getRect(
            find.descendant(of: detail, matching: find.byType(SelectableText)),
          );
          expect(body.left, 28);
          expect(width - body.right, 28);
          expect(
            find.byIcon(PhosphorIcons.caretLeft).hitTestable(),
            findsOneWidget,
          );
          await tester.tap(find.byTooltip('Back').hitTestable());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 140));
          expect(tester.getTopLeft(about).dx, inExclusiveRange(-width, 0));
          expect(tester.getTopLeft(detail).dx, inExclusiveRange(0, width));
          await tester.pumpAndSettle();
          expect(detail, findsNothing);
          expect(tester.getTopLeft(about), Offset.zero);
        }

        await tester.tap(find.widgetWithText(ListTile, 'What’s New'));
        await tester.pumpAndSettle();
        final detail = find.byWidgetPredicate(
          (widget) => widget is SettingsPage && widget.title == 'What’s New',
        );
        final width = tester.getSize(detail).width;

        Future<TestGesture> swipeBack(double distance) async {
          final gesture = await tester.startGesture(const Offset(150, 220));
          await gesture.moveBy(Offset(distance, 0));
          await tester.pump();
          expect(tester.getTopLeft(detail).dx, closeTo(distance, 2));
          expect(tester.getTopLeft(about).dx, closeTo(distance - width, 2));
          expect(tester.getTopLeft(detail).dy, 0);
          return gesture;
        }

        final shortSwipe = await swipeBack(width * 0.15);
        await shortSwipe.moveBy(Offset(-width * 0.05, 0));
        await tester.pump();
        expect(tester.getTopLeft(detail).dx, closeTo(width * 0.10, 2));
        await shortSwipe.up();
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(detail), Offset.zero);

        final canceledSwipe = await swipeBack(width * 0.30);
        await canceledSwipe.cancel();
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(detail), Offset.zero);

        final completedSwipe = await swipeBack(width * 0.30);
        await completedSwipe.up();
        await tester.pumpAndSettle();
        expect(detail, findsNothing);
        expect(tester.getTopLeft(about), Offset.zero);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient((request) {
        expect(request.url.path, '/repos/han9088/musaic/releases/latest');
        return response;
      }),
    );
  });

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

  testWidgets('capsule shows drag feedback without a provider track', (
    tester,
  ) async {
    final playback = AlbumPlayback();
    addTearDown(playback.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppBottomSheetHost(
          child: HomeSheet(playback: playback, child: const SizedBox.expand()),
        ),
      ),
    );

    for (final (dx, skip, seek) in [
      (56.0, PhosphorIcons.skipForwardFill, PhosphorIcons.fastForwardFill),
      (-56.0, PhosphorIcons.skipBackFill, PhosphorIcons.rewindFill),
    ]) {
      if (dx < 0) {
        playback.toggle('demo', 'Demo');
        await tester.pump();
      }
      final idleIcon = playback.playing
          ? PhosphorIcons.pauseFill
          : PhosphorIcons.playFill;
      final pull = await tester.startGesture(tester.getCenter(capsule));
      await pull.moveBy(Offset(dx, 0));
      await tester.pump();
      expect(find.widgetWithIcon(IconButton, skip), findsOneWidget);
      expect(find.byIcon(idleIcon), findsNothing);
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.widgetWithIcon(IconButton, seek), findsOneWidget);
      await pull.up();
      await tester.pumpAndSettle();
      expect(find.byIcon(seek), findsNothing);
      expect(find.widgetWithIcon(IconButton, idleIcon), findsOneWidget);
    }
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
    expect(
      tester.getTopLeft(toggle).dy,
      lessThan(tester.getTopLeft(appearance).dy),
    );
    final feedback = Theme.of(tester.element(appearance));
    expect(feedback.splashFactory, InkRipple.splashFactory);
    expect(feedback.splashColor, Colors.white.withValues(alpha: 0.10));
    expect(feedback.highlightColor, Colors.white.withValues(alpha: 0.10));
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
      const viewport = Size(320, 360);
      await tester.binding.setSurfaceSize(viewport);
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
      final initialScroll = position.maxScrollExtent.clamp(0.0, 80.0);
      expect(initialScroll, greaterThan(30));
      position.jumpTo(initialScroll);
      await tester.pump();
      final pull = await tester.startGesture(const Offset(160, 160));
      await pull.moveBy(const Offset(0, 25));
      await pull.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(position.pixels, inExclusiveRange(0, initialScroll));
      expect(tester.getTopLeft(page).dy, 0);

      final remainingScroll = position.pixels;
      await pull.moveBy(Offset(0, remainingScroll + 60));
      await tester.pump();
      expect(position.pixels, 0);
      expect(tester.getTopLeft(page).dy, closeTo(60, 2));
      expect(
        tester.getTopLeft(page).dy - sheetPosition.value,
        closeTo(viewport.height - originalTop, 0.01),
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
        await tester.pump();
        final dragStart = tester.getTopLeft(page).dy;
        await gesture.moveBy(const Offset(0, 130));
        await tester.pump();
        expect(tester.getTopLeft(page).dy - dragStart, closeTo(130, 2));
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
    final demoHeading = find.descendant(of: page, matching: find.text('Demo'));
    final demoIcon = find.descendant(
      of: mock2,
      matching: find.byIcon(PhosphorIcons.squaresFour),
    );
    expect(tester.widget<Text>(demoHeading).style?.fontSize, 13);
    expect(tester.getTopLeft(mock2).dx, tester.getTopLeft(page).dx);
    expect(tester.getTopLeft(demoHeading).dx, tester.getTopLeft(demoIcon).dx);
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

  testWidgets(
    'settings can be dragged closed after scrolling and expanding',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppBottomSheetHost(
            child: HomeSheet(icons: _Icons(), child: SizedBox.expand()),
          ),
        ),
      );

      await tester.drag(capsule, const Offset(0, -140));
      await tester.pumpAndSettle();
      final sheet = DeskBottomSheet.of(tester.element(find.byType(HomeSheet)));
      final handle = find.byType(BottomSheetHandle);
      final settings = find.byType(BottomSheetScrollView);
      final scrollable = find.descendant(
        of: settings,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      final index = BottomSheetContent.of(tester.element(handle)).animatedIndex;
      expect(index.value, 0);

      await tester.drag(settings, const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(index.value, 0);

      await tester.drag(handle, const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(index.value, 1);
      expect(position.pixels, 0);
      expect(position.maxScrollExtent, 0);

      await tester.dragFrom(
        tester.getTopLeft(settings) + const Offset(150, 32),
        const Offset(0, 260),
      );
      await tester.pumpAndSettle();
      expect(index.value, 0);
      expect(sheet.isPresented, isTrue);

      await tester.dragFrom(
        tester.getTopLeft(settings) + const Offset(150, 32),
        const Offset(0, 180),
      );
      await tester.pumpAndSettle();
      expect(sheet.isPresented, isFalse);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

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
