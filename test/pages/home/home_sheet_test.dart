import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender_method_channel/flutter_email_sender_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/bottom_sheet_host.dart';
import 'package:musaic/features/artwork/presentation/xerox_palette.dart';
import 'package:musaic/features/artwork/presentation/xerox_palette_picker.dart';
import 'package:musaic/features/music/playback/album_playback.dart';
import 'package:musaic/features/music/playback/now_playing_capsule.dart';
import 'package:musaic/features/onboarding/gesture_guide_spotlight.dart';
import 'package:musaic/features/settings/developer_options_unlock.dart';
import 'package:musaic/features/settings/settings_sheet.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/pages/home/home_sheet.dart';
import 'package:musaic/pages/settings/settings_page.dart';
import 'package:musaic/services/app_icon_service.dart';
import 'package:musaic/services/diagnostics/diagnostic_log.dart';
import 'package:musaic/services/music/music_source_controller.dart';
import 'package:musaic/storage/settings/app_language_preference.dart';
import 'package:musaic/storage/settings/usage_guide_preference.dart';
import 'package:musaic/ui/bottom_sheet/bottom_sheet.dart';
import 'package:musaic/ui/dialogs/app_alert_dialog.dart';
import 'package:musaic/ui/theme/app_colors.dart';
import 'package:musaic/ui/thinking_orbs/thinking_orb.dart';
import 'package:musaic/ui/widgets/app_navigation_back_button.dart';
import 'package:musaic/ui/widgets/app_selection_dot.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:signals_flutter/signals_flutter.dart';

void main() {
  final settingsTab = find.widgetWithIcon(Tab, PhosphorIcons.gearBold);
  final capsule = find.byType(NowPlayingCapsule);
  Finder dotIn(Finder item) =>
      find.descendant(of: item, matching: find.byType(AppSelectionDot));

  void expectDotAligned(WidgetTester tester, Finder item, Finder title) {
    final dot = dotIn(item);
    expect(dot, findsOneWidget);
    expect(
      tester.getCenter(dot).dy,
      closeTo(tester.getCenter(title).dy + 1, 0.01),
    );
  }

  setUp(() {
    final previous = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
  });

  testWidgets('first-use guide demonstrates two pulls on the playback bar', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final playback = AlbumPlayback();
    addTearDown(playback.dispose);
    final app = MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppBottomSheetHost(
        child: HomeSheet(playback: playback, child: const SizedBox.expand()),
      ),
    );
    await tester.pumpWidget(app);
    final center = tester.getCenter(capsule);
    final touch = find.byKey(const ValueKey('playback-intro-touch'));
    final spotlight = find.byType(GestureGuideSpotlight);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1700));
    expect(spotlight, findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 680));
    expect(spotlight, findsOneWidget);
    expect(touch, findsNothing);
    expect(tester.getCenter(capsule), center);

    await tester.pump(const Duration(milliseconds: 650));
    expect(find.text('Previous track'), findsOneWidget);
    expect(tester.getCenter(touch).dx, lessThan(center.dx));
    expect(tester.getCenter(capsule).dx, lessThan(center.dx));

    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('Fast-forward'), findsOneWidget);
    expect(tester.getCenter(touch).dx, greaterThan(center.dx));
    expect(tester.getCenter(capsule).dx, greaterThan(center.dx));
    expect(playback.currentTrack, isNull);

    await tester.tapAt(const Offset(100, 100));
    await tester.pump();
    expect(touch, findsNothing);
    expect(spotlight, findsNothing);
    expect(tester.getCenter(capsule), center);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(spotlight, findsNothing);
    expect(touch, findsNothing);
    expect(find.text('Previous track'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('first-use guide reveals and closes the first settings detent', (
    tester,
  ) async {
    const viewport = Size(402, 874);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final playback = AlbumPlayback();
    addTearDown(playback.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppBottomSheetHost(
          child: HomeSheet(playback: playback, child: const SizedBox.expand()),
        ),
      ),
    );

    final host = DeskBottomSheet.of(tester.element(find.byType(HomeSheet)));
    final spotlight = find.byType(GestureGuideSpotlight);
    final settingsCaption = find.text('Swipe Up for Settings');
    final touch = find.byKey(const ValueKey('playback-intro-touch'));
    GestureGuideSpotlight mask() => tester.widget(spotlight);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 680));
    final playbackCaption = find.text('Playback Controls');
    expect(tester.getCenter(playbackCaption), viewport.center(Offset.zero));
    final capsuleCenter = tester.getCenter(capsule);
    await tester.pump(const Duration(milliseconds: 3860));
    expect(tester.getCenter(settingsCaption), viewport.center(Offset.zero));
    expect(mask().expansion!.progress.value, inExclusiveRange(0, 1));
    expect(host.isPresented, isFalse);

    await tester.pump(const Duration(milliseconds: 510));
    expect(mask().expansion!.progress.value, 1);
    expect(tester.getCenter(touch).dy, lessThan(capsuleCenter.dy - 20));
    expect(host.isPresented, isFalse);

    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    expect(host.presentedSheetCount, 1);
    final sheetTop = tester.getTopLeft(find.byType(BottomSheetHandle)).dy;
    expect(sheetTop, closeTo(874 * 0.62, 1));
    expect(mask().expansion!.shape(viewport).top, closeTo(sheetTop, 1));

    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pump(const Duration(milliseconds: 80));
    expect(host.isPresented, isTrue);
    expect(mask().focus.value, closeTo(1, 0.00001));
    expect(mask().expansion!.progress.value, 1);
    for (var i = 0; i < 60 && host.isPresented; i++) {
      expect(mask().focus.value, closeTo(1, 0.00001));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(host.isPresented, isFalse);
    await tester.pump(const Duration(milliseconds: 340));
    expect(mask().focus.value, inExclusiveRange(0, 1));
    expect(mask().expansion!.progress.value, 1);
    await tester.pumpAndSettle();
    expect(spotlight, findsNothing);
    expect(settingsCaption, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'five quick About icon taps unlock options and reset both demos',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      for (final intro in UsageGuideIntro.values) {
        await UsageGuidePreference.markIntroSeen(intro);
      }
      final wizard = UsageGuidePreference();
      await wizard.hide();
      wizard.dispose();
      final playback = AlbumPlayback();
      addTearDown(playback.dispose);
      final app = MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppBottomSheetHost(
          child: HomeSheet(playback: playback, child: const SizedBox.expand()),
        ),
      );
      Future<DeskBottomSheet> openSettings() async {
        await tester.drag(capsule, const Offset(0, -150));
        await tester.pumpAndSettle();
        final sheet = DeskBottomSheet.of(
          tester.element(find.byType(HomeSheet)),
        );
        sheet.topSheetController!.expand();
        await tester.pumpAndSettle();
        return sheet;
      }

      await tester.pumpWidget(app);
      final sheet = await openSettings();
      final options = find.widgetWithText(ListTile, 'Developer options');
      expect(options, findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'About Musaic'));
      await tester.pumpAndSettle();

      final logo = find.byType(DeveloperOptionsUnlock);
      for (var tap = 0; tap < 4; tap++) {
        await tester.tap(logo);
      }
      await tester.pump(const Duration(seconds: 1));
      for (var tap = 0; tap < 4; tap++) {
        await tester.tap(logo);
      }
      await tester.pump();
      expect(find.text('Reset demos'), findsNothing);
      await tester.tap(logo);
      await tester.pumpAndSettle();
      expect(find.text('Developer options'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Reset demos'));
      await tester.pumpAndSettle();
      expect(
        find.text('Demos reset. Return home to see them again.'),
        findsOneWidget,
      );
      expect(
        await UsageGuidePreference.shouldPlayIntro(UsageGuideIntro.camera),
        isTrue,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(options, findsOneWidget);
      expect(find.text('Wizard'), findsNothing);
      sheet.dismiss();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(GestureGuideSpotlight), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app);
      await openSettings();
      expect(options, findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Pro opens the annual subscription page without a fixed price', (
    tester,
  ) async {
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

    final entry = find.widgetWithText(ListTile, 'Pro');
    await tester.tap(entry);
    await tester.pumpAndSettle();
    final page = find.byType(SettingsPage);
    expect(tester.widget<SettingsPage>(page).title, 'Pro');
    expect(find.text('Annual subscription'), findsOneWidget);
    expect(find.text('Price unavailable'), findsOneWidget);
    final restore = find.widgetWithText(TextButton, 'Restore purchases');
    expect(tester.widget<TextButton>(restore).onPressed, isNull);

    Navigator.of(tester.element(page)).pop();
    await tester.pumpAndSettle();
    expect(page, findsNothing);
    expect(entry.hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Appearance language updates the open settings page', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.view.resetViewInsets);
    final preference = AppLanguagePreference(AppLanguage.system);
    addTearDown(preference.dispose);

    await tester.pumpWidget(
      SignalBuilder(
        builder: (_) => MaterialApp(
          locale: preference.selected.value.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppBottomSheetHost(
            child: HomeSheet(
              icons: const _Icons(),
              language: preference,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.drag(capsule, const Offset(0, -140));
    await tester.pumpAndSettle();
    final appearance = find.widgetWithText(ListTile, 'Appearance & display');
    expect(
      find.descendant(
        of: appearance,
        matching: find.byIcon(PhosphorIcons.monitor),
      ),
      findsOneWidget,
    );
    await tester.tap(appearance);
    await tester.pumpAndSettle();

    final page = find.byType(SettingsPage);
    Future<void> selectLanguage(
      String label,
      String query,
      String choice,
      String emptyLabel,
    ) async {
      final trigger = find.widgetWithText(ListTile, label);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      final menu = find.byType(AppDialogSurface);
      expect(
        tester.getTopLeft(menu).dy,
        greaterThan(tester.getBottomLeft(trigger).dy),
      );
      final search = find.descendant(
        of: menu,
        matching: find.byType(TextField),
      );
      final options = find.descendant(
        of: menu,
        matching: find.byType(ListTile),
      );
      expect(options, findsNWidgets(3));
      final marker = find.descendant(
        of: menu,
        matching: find.byType(AppSelectionDot),
      );
      expect(marker, findsOneWidget);
      final selected = find.ancestor(of: marker, matching: options);
      expect(tester.widget<ListTile>(selected).selected, isTrue);
      expectDotAligned(
        tester,
        selected,
        find.descendant(of: selected, matching: find.byType(Text)),
      );
      await tester.enterText(search, 'missing language');
      await tester.pumpAndSettle();
      expect(find.text(emptyLabel), findsOneWidget);
      expect(options, findsNothing);
      await tester.enterText(search, query);
      final devicePixelRatio = tester.view.devicePixelRatio;
      tester.view.viewInsets = FakeViewPadding(bottom: 420 * devicePixelRatio);
      await tester.pumpAndSettle();
      expect(options, findsOneWidget);
      expect(marker, findsNothing);
      expect(
        find.descendant(of: menu, matching: find.text(choice)),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(menu).dy,
        lessThan(tester.view.physicalSize.height / devicePixelRatio - 420),
      );
      await tester.tap(options);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(menu, findsNothing);
    }

    await selectLanguage(
      'Language',
      '  CHINESE  ',
      '简体中文',
      'No languages found',
    );
    expect(tester.widget<SettingsPage>(page).title, '外观与显示');
    expect(find.widgetWithText(ListTile, '语言'), findsOneWidget);
    expect(preference.selected.value, AppLanguage.simplifiedChinese);

    await selectLanguage('语言', '英文', 'English', '未找到匹配的语言');
    expect(tester.widget<SettingsPage>(page).title, 'Appearance & display');
    expect(preference.selected.value, AppLanguage.english);

    await selectLanguage(
      'Language',
      '跟随系统',
      'System default',
      'No languages found',
    );
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).locale, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Only the guide dismissal button permanently hides its entry', (
    tester,
  ) async {
    const bottomInset = 34.0;
    tester.view.padding = FakeViewPadding(
      bottom: bottomInset * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    const app = MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppBottomSheetHost(
        child: HomeSheet(icons: _Icons(), child: SizedBox.expand()),
      ),
    );
    await tester.pumpWidget(app);
    await tester.drag(capsule, const Offset(0, -140));
    await tester.pumpAndSettle();

    final guide = find.widgetWithText(ListTile, '使用说明');
    expect(
      tester.getTopLeft(guide).dy,
      greaterThan(tester.getBottomLeft(find.text('关于与帮助')).dy),
    );
    await tester.ensureVisible(guide);
    await tester.pumpAndSettle();
    Future<void> openGuide() async {
      await tester.tap(guide);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await openGuide();

    final page = find.byType(SettingsPage);
    expect(tester.widget<SettingsPage>(page).title, '使用说明');
    expect(find.text('浏览专辑'), findsOneWidget);
    expect(find.text('相机背景'), findsOneWidget);
    await tester.tap(find.byIcon(PhosphorIcons.caretDownBold).hitTestable());
    await tester.pumpAndSettle();

    expect(page, findsNothing);
    expect(guide, findsOneWidget);

    await openGuide();
    final dismiss = find.widgetWithText(FilledButton, '关闭并不再显示');
    expect(dismiss.hitTestable(), findsOneWidget);
    final dismissBounds = tester.getRect(dismiss);
    expect(
      tester.getRect(page).bottom - dismissBounds.bottom,
      closeTo(bottomInset + 24, 0.5),
    );
    final heading = find.text('浏览专辑');
    final headingTop = tester.getTopLeft(heading).dy;
    final scrollView = find.descendant(
      of: page,
      matching: find.byType(CustomScrollView),
    );
    expect(tester.getRect(scrollView).bottom, tester.getRect(page).bottom);
    await tester.drag(scrollView, const Offset(0, -180));
    await tester.pump();
    expect(tester.getTopLeft(heading).dy, lessThan(headingTop));
    expect(tester.getRect(dismiss), dismissBounds);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: scrollView, matching: find.byType(Scrollable)),
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    final l10n = AppLocalizations.of(tester.element(page));
    expect(
      tester.getBottomLeft(find.text(l10n.usageGuideCamera)).dy,
      lessThan(dismissBounds.top),
    );
    expect(tester.getSize(dismiss).height, greaterThanOrEqualTo(56));
    await tester.tap(dismiss);
    await tester.pumpAndSettle();
    expect(page, findsNothing);
    expect(guide, findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app);
    await tester.drag(capsule, const Offset(0, -140));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, '问题诊断'), findsOneWidget);
    expect(guide, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

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

  testWidgets('Troubleshooting exports a log and attaches it to feedback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const bottomInset = 34.0;
    tester.view.padding = FakeViewPadding(
      bottom: bottomInset * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    MethodChannelFlutterEmailSender.registerWith();
    const device = MethodChannel('dev.fluttercommunity.plus/device_info');
    const email = MethodChannel('flutter_email_sender');
    final messenger = tester.binding.defaultBinaryMessenger;
    final originalPicker = FilePickerPlatform.instance;
    final picker = _DiagnosticFilePicker();
    FilePickerPlatform.instance = picker;
    addTearDown(() {
      FilePickerPlatform.instance = originalPicker;
      messenger.setMockMethodCallHandler(device, null);
      messenger.setMockMethodCallHandler(email, null);
    });
    messenger.setMockMethodCallHandler(
      device,
      (_) async => <String, Object>{
        'name': 'Private phone name',
        'systemName': 'iOS',
        'systemVersion': '26.1',
        'model': 'iPhone',
        'modelName': 'iPhone 17 Pro',
        'localizedModel': 'iPhone',
        'identifierForVendor': 'private-device-id',
        'freeDiskSize': 1,
        'totalDiskSize': 1,
        'isPhysicalDevice': true,
        'physicalRamSize': 1,
        'availableRamSize': 1,
        'isiOSAppOnMac': false,
        'isiOSAppOnVision': false,
        'utsname': {
          'sysname': 'Darwin',
          'nodename': 'private-host',
          'release': '',
          'version': '',
          'machine': 'iPhone18,1',
        },
      },
    );
    final drafts = <Map<Object?, Object?>>[];
    messenger.setMockMethodCallHandler(email, (call) async {
      if (call.method == 'getCapabilities') return {'canSend': true};
      expect(call.method, 'send');
      drafts.add(call.arguments as Map<Object?, Object?>);
      return 'cancelled';
    });
    PackageInfo.setMockInitialValues(
      appName: 'Musaic',
      packageName: 'com.deskbtm.musaic',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    diagnosticLog.record(DiagnosticEvent.cameraAccessDenied);
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
    await tester.drag(capsule, const Offset(0, -150));
    await tester.pumpAndSettle();
    final sheet = DeskBottomSheet.of(tester.element(find.byType(HomeSheet)));
    sheet.topSheetController!.expand();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Troubleshooting'));
    await tester.pumpAndSettle();
    final page = find.byType(SettingsPage);
    expect(page, findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(page));
    expect(find.text(l10n.diagnosticsPrivacy), findsOneWidget);

    final mail = find.widgetWithText(FilledButton, l10n.diagnosticsEmail);
    final export = find.widgetWithText(ListTile, l10n.diagnosticsExport);
    final field = find.byType(TextField);
    final button = tester.widget<FilledButton>(mail);
    expect(
      button.style!.backgroundColor!.resolve({}),
      AppColors.settingsAccent,
    );
    expect(button.style!.shape!.resolve({}), isA<StadiumBorder>());
    final mailRect = tester.getRect(mail);
    final pageRect = tester.getRect(page);
    expect(mailRect.height, greaterThanOrEqualTo(56));
    expect(mailRect.width, greaterThan(pageRect.width * 0.8));
    expect(pageRect.bottom - mailRect.bottom, closeTo(bottomInset + 24, 0.5));
    final scrollView = find.descendant(
      of: page,
      matching: find.byType(CustomScrollView),
    );
    expect(tester.getRect(scrollView).bottom, pageRect.bottom - bottomInset);
    await tester.ensureVisible(mail);
    await tester.tap(mail);
    await tester.pumpAndSettle();
    final details = l10n.diagnosticsEmailDetails(
      'iPhone 17 Pro',
      'iOS 26.1',
      '1.0.0 (1)',
    );
    expect(drafts.single['body'], details);

    const description = 'Camera stopped after returning to Cover Flow.';
    await tester.ensureVisible(field);
    await tester.enterText(field, description);
    await tester.ensureVisible(mail);
    await tester.tap(mail);
    await tester.pumpAndSettle();
    expect(drafts.last['subject'], 'Musaic feedback');
    expect(drafts.last['body'], '$description\n\n$details');
    final attachments = drafts.last['attachments']! as List<Object?>;
    final attachment = attachments.single! as Map<Object?, Object?>;
    expect(
      attachment['file_name'],
      matches(r'^musaic-diagnostics-\d{14}\.txt$'),
    );
    final report = utf8.decode(attachment['data']! as Uint8List);
    expect(report, contains('Device model: iPhone 17 Pro'));
    expect(report, contains('System: iOS 26.1'));
    expect(report, contains('Musaic version: 1.0.0 (1)'));
    expect(report, contains('cameraAccessDenied'));
    expect(report, isNot(contains(description)));
    expect(report, isNot(contains('private-')));
    expect(report, isNot(contains('Private phone name')));

    await tester.ensureVisible(export);
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(picker.fileName, endsWith('.txt'));
    expect(picker.content, contains('cameraAccessDenied'));
    expect(picker.content, isNot(contains(description)));
    expect(find.text(l10n.diagnosticsExported), findsOneWidget);
    await tester.tap(find.byIcon(PhosphorIcons.caretDownBold).hitTestable());
    await tester.pumpAndSettle();
    expect(page, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('About opens its detail pages and uses the settings routes', (
    tester,
  ) async {
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
        final copyright = find.text('© ${DateTime.now().year} deskbtm');
        expect(tester.widget<Text>(copyright).style?.color, Colors.white38);
        expect(tester.getCenter(copyright).dx, tester.getCenter(about).dx);
        expect(
          tester.getBottomRight(about).dy - tester.getBottomRight(copyright).dy,
          24,
        );
        expect(
          find.byIcon(PhosphorIcons.caretDownBold).hitTestable(),
          findsOneWidget,
        );
        final back = find.descendant(
          of: about,
          matching: find.byType(AppNavigationBackButton),
        );
        final circle = find.descendant(
          of: back,
          matching: find.byType(DecoratedBox),
        );
        expect(tester.getSize(circle), const Size.square(22));
        expect(
          tester.widget<DecoratedBox>(circle).decoration,
          const BoxDecoration(
            color: AppColors.settingsAccent,
            shape: BoxShape.circle,
          ),
        );
        expect(tester.getSize(back).width, greaterThanOrEqualTo(44));
        final aboutRows = tester.widgetList<ListTile>(
          find.descendant(of: about, matching: find.byType(ListTile)),
        );
        expect(aboutRows.map((row) => row.leading), everyElement(isNull));
        final versionLabel = find.text('Version');
        final versionValue = find.text('1.0.0 (1)');
        expect(tester.getTopLeft(versionLabel).dx, 28);
        expect(
          tester.getTopLeft(circle).dx,
          tester.getTopLeft(versionLabel).dx,
        );
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
        expect(detailArrows.map((icon) => icon.size), [12, 12, 12]);

        Future<void> closeDialog() async {
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
        }

        for (final (status, body, message) in [
          (404, '', 'There are no public releases yet.'),
          (200, '{"tag_name":"v1.0.0+1"}', 'You’re up to date.'),
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
            expect(find.text('View on GitHub'), findsOneWidget);
          }
          await closeDialog();
        }

        for (final item in [
          'Privacy policy',
          'Terms of Service',
          'What’s New',
        ]) {
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
            find.byIcon(PhosphorIcons.caretLeftBold).hitTestable(),
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
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      await tester.pump(const Duration(milliseconds: 100));
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

  testWidgets('Xerox waits for an expanded sheet to reach the first detent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final xeroxEnabled = ValueNotifier(false);
    addTearDown(xeroxEnabled.dispose);
    final modeChanges = <({bool enabled, bool homeCurrent, int sheets})>[];
    final togglePositions = <double>[];
    late final ModalRoute<dynamic> homeRoute;
    late final DeskBottomSheet sheet;
    late final ValueNotifier<double> sheetPosition;
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
              if (sheet.isPresented) togglePositions.add(sheetPosition.value);
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

    sheetPosition = BottomSheetContent.of(
      tester.element(find.byType(SettingsSheet)),
    ).animatedPosition;
    final firstDetentTop = sheetPosition.value;
    sheet.topSheetController!.expand();
    await tester.pumpAndSettle();
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

    Future<void> toggleFromExpanded(bool enabled) async {
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      final previousCount = modeChanges.length;
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        sheetPosition.value,
        inExclusiveRange(originalTop, firstDetentTop),
      );
      expect(modeChanges, hasLength(previousCount));
      await tester.pumpAndSettle();
      expect(modeChanges, hasLength(previousCount + 1));
      expect(modeChanges.last, (
        enabled: enabled,
        homeCurrent: true,
        sheets: 1,
      ));
      expect(togglePositions.last, closeTo(firstDetentTop, 0.1));
      expect(xeroxEnabled.value, enabled);
      expect(sheet.topSheetId, sheetId);
    }

    await toggleFromExpanded(true);
    sheet.topSheetController!.expand();
    await tester.pumpAndSettle();

    Future<void> reopenSettings() async {
      await tester.drag(capsule, const Offset(0, -140));
      await tester.pumpAndSettle();
      sheet.topSheetController!.expand();
      await tester.pumpAndSettle();
    }

    expect(tester.widget<ListTile>(toggle).selected, isTrue);
    expectDotAligned(tester, toggle, find.text('Xerox'));
    for (final preset in XeroxPalette.values) {
      final swatch = find.byKey(ValueKey(preset));
      await tester.ensureVisible(swatch);
      await tester.tap(swatch);
      await tester.pump();
      expect(palette.value, preset);
      expect(
        find.descendant(of: swatch, matching: find.byType(AppSelectionDot)),
        findsOneWidget,
      );
    }
    await toggleFromExpanded(false);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pump();
    expect(xeroxEnabled.value, isTrue);
    expect(togglePositions.last, closeTo(firstDetentTop, 0.1));
    final switchOff = tester.widget<ListTile>(toggle).onTap!;
    sheet.present(const SizedBox.expand());
    await tester.pumpAndSettle();
    expect(sheet.presentedSheetCount, 2);
    switchOff();
    await tester.pump();
    expect(modeChanges, hasLength(3));
    await tester.pumpAndSettle();
    expect(modeChanges, [
      (enabled: true, homeCurrent: true, sheets: 1),
      (enabled: false, homeCurrent: true, sheets: 1),
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
    'settings requires a deliberate pull starting at the top to return',
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
      final coveredSheetTop = sheetPosition.value;

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

      await pull.moveBy(Offset(0, position.pixels + 100));
      await tester.pump();
      expect(position.pixels, 0);
      expect(tester.getTopLeft(page).dy, 0);
      expect(sheetPosition.value, coveredSheetTop);
      await pull.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(page).dy, 0);

      for (var attempt = 0; attempt < 2; attempt++) {
        final shortPull = await tester.startGesture(const Offset(160, 160));
        await shortPull.moveBy(const Offset(0, 25));
        await shortPull.moveBy(const Offset(0, 12));
        await tester.pump();
        expect(tester.getTopLeft(page).dy, 0);
        expect(sheetPosition.value, coveredSheetTop);
        await shortPull.up();
        await tester.pumpAndSettle();
      }

      Future<TestGesture> pullPastThreshold() async {
        final gesture = await tester.startGesture(const Offset(160, 160));
        await gesture.moveBy(const Offset(0, 25));
        await gesture.moveBy(const Offset(0, 15));
        await tester.pump();
        expect(tester.getTopLeft(page).dy, 0);
        await gesture.moveBy(const Offset(0, 130));
        await tester.pump();
        expect(tester.getTopLeft(page).dy, inInclusiveRange(103, 132));
        expect(
          tester.getTopLeft(page).dy - sheetPosition.value,
          closeTo(viewport.height - originalTop, 0.01),
        );
        return gesture;
      }

      final reversed = await pullPastThreshold();
      final pullDistance = tester.getTopLeft(page).dy;
      await reversed.moveBy(const Offset(0, -100));
      await tester.pump();
      expect(position.pixels, 0);
      expect(tester.getTopLeft(page).dy, closeTo(pullDistance - 100, 2));
      await reversed.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(page).dy, 0);

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
    final appleMusic = find.byKey(const ValueKey('music-source-apple-music'));
    expect(mock2, findsOneWidget);
    final mock = find.byKey(const ValueKey('music-source-mock'));
    expectDotAligned(
      tester,
      mock,
      find.descendant(of: mock, matching: find.byType(Text)),
    );
    expect(dotIn(mock2), findsNothing);
    expect(appleMusic, findsNothing);
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
    expect(find.text('On this device'), findsOneWidget);
    expect(find.text('Local music'), findsOneWidget);
    expect(find.text('Apple Music'), findsOneWidget);
    final appleMusicTile = tester.widget<ListTile>(appleMusic);
    expect(appleMusicTile.enabled, isTrue);
    expect(appleMusicTile.onTap, isNotNull);
    final appleMusicIcon = tester.widget<Icon>(
      find.descendant(
        of: appleMusic,
        matching: find.byIcon(PhosphorIcons.appleLogoFill),
      ),
    );
    expect(appleMusicIcon.color, Colors.white);
    await tester.tap(appleMusic);
    await tester.pumpAndSettle();
    expect(page, findsOneWidget);
    expect(sources.catalog.value, isNull);
    expect(sources.provider, isNull);

    sources.catalog.value = const [];
    await tester.pumpAndSettle();
    expectDotAligned(
      tester,
      find.byKey(const ValueKey('music-source-local')),
      find.text('Local music'),
    );
    sources.catalog.value = null;
    await tester.pumpAndSettle();

    final lowerPull = await tester.startGesture(const Offset(180, 650));
    await lowerPull.moveBy(const Offset(0, 24));
    await tester.pump();
    expect(tester.getTopLeft(page).dy, 0);
    await lowerPull.moveBy(const Offset(0, 255));
    await tester.pump();
    expect(tester.getTopLeft(page).dy, inInclusiveRange(213, 241));
    await lowerPull.up();
    await tester.pumpAndSettle();
    expect(page, findsNothing);
    await tester.tap(find.text('Music source'));
    await tester.pumpAndSettle();

    final headerPull = await tester.startGesture(const Offset(180, 28));
    await headerPull.moveBy(const Offset(0, 24));
    await tester.pump();
    expect(tester.getTopLeft(page).dy, 0);
    await headerPull.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(tester.getTopLeft(page).dy, inInclusiveRange(18, 46));
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

class _DiagnosticFilePicker extends FilePickerPlatform {
  String? fileName;
  String? content;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    ValueChanged<FilePickerStatus>? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    expect(mimeType, 'text/plain');
    this.fileName = fileName;
    content = utf8.decode(bytes);
    return Uri.file('/test/$fileName');
  }
}
