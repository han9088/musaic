import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/settings/desktop_settings_window.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/pages/home/home_sheet.dart';
import 'package:musaic/pages/settings/settings_page.dart';
import 'package:musaic/services/app_icon_service.dart';
import 'package:musaic/services/music/music_source_controller.dart';
import 'package:musaic/storage/settings/app_language_preference.dart';
import 'package:musaic/ui/dialogs/app_alert_dialog.dart';
import 'package:musaic/ui/widgets/app_navigation_back_button.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    final previous = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
    PackageInfo.setMockInitialValues(
      appName: 'Musaic',
      packageName: 'com.deskbtm.musaic',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('only the desktop settings tab uses split navigation', (
    tester,
  ) async {
    final window = DesktopSettingsWindow();
    final sources = MusicSourceController();
    final language = AppLanguagePreference(AppLanguage.system);
    final xeroxEnabled = ValueNotifier(false);
    addTearDown(window.dispose);
    addTearDown(sources.dispose);
    addTearDown(language.dispose);
    addTearDown(xeroxEnabled.dispose);
    Widget app(Widget home) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
    Widget root({WidgetBuilder? settings}) => Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        app(
          HomeSheet(
            icons: const _Icons(),
            settingsWindow: window,
            sources: sources,
            language: language,
            xeroxEnabled: xeroxEnabled,
            onXeroxChanged: (value) => xeroxEnabled.value = value,
            xeroxPalettePicker: const Text('Test Xerox palette'),
            child: const SizedBox.expand(),
          ),
        ),
        if (settings != null) app(Builder(builder: settings)),
      ],
    );

    await tester.pumpWidget(root());
    await tester.pumpWidget(root(settings: window.content!));
    await tester.pumpAndSettle();
    final tabs = find.descendant(
      of: find.byType(TabBar),
      matching: find.byType(Tab),
    );
    final sidebar = find.byKey(const ValueKey('desktop-settings-sidebar'));
    final demoSource = find.byKey(const ValueKey('music-source-mock2'));
    expect(tabs, findsNWidgets(2));
    expect(sidebar, findsNothing);
    expect(demoSource.hitTestable(), findsOneWidget);

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.black,
    );

    await tester.tap(tabs.at(1));
    await tester.pumpAndSettle();
    final appearance = find.text('Appearance & display');
    final aboutAndHelp = find.text('About & help');
    final xerox = find.byKey(const ValueKey('xerox-toggle'));
    final system = find.widgetWithText(ListTile, 'System');
    final details = find.byType(SettingsPage);
    final languageRow = find.widgetWithText(ListTile, 'Language');
    expect(tester.widget<ListTile>(system).selected, isTrue);
    expect(tester.widget<SettingsPage>(details).title, 'System');
    expect(find.widgetWithText(ListTile, 'Appearance & display'), findsNothing);
    expect(find.widgetWithText(ListTile, 'About & help'), findsNothing);
    final systemIcon = find.descendant(of: system, matching: find.byType(Icon));
    final iconLeft = tester.getTopLeft(systemIcon).dx;
    final xeroxLabel = find.descendant(of: xerox, matching: find.text('Xerox'));
    expect(tester.getTopLeft(appearance).dx, iconLeft);
    expect(tester.getTopLeft(aboutAndHelp).dx, iconLeft);
    expect(tester.getTopLeft(xeroxLabel).dx, iconLeft);
    expect(find.descendant(of: details, matching: languageRow), findsOneWidget);
    await tester.tap(languageRow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    expect(language.selected.value, AppLanguage.simplifiedChinese);
    expect(find.descendant(of: sidebar, matching: xerox), findsOneWidget);
    expect(
      tester.getTopLeft(xerox).dy,
      lessThan(tester.getTopLeft(appearance).dy),
    );
    await tester.tap(xerox);
    await tester.pumpAndSettle();
    expect(xeroxEnabled.value, isTrue);
    expect(tester.getTopLeft(xeroxLabel).dx, iconLeft);
    expect(
      find.descendant(of: sidebar, matching: find.text('Test Xerox palette')),
      findsOneWidget,
    );
    expect(tester.widget<SettingsPage>(details).title, 'System');

    final source = find.widgetWithText(ListTile, 'Music source');
    await tester.tap(source);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tabs, findsNWidgets(2));
    expect(tester.widget<ListTile>(source).selected, isTrue);
    expect(find.text('Language'), findsNothing);
    expect(
      tester.getRect(source).right,
      lessThan(tester.getRect(find.byType(SettingsPage)).left),
    );

    await tester.tap(demoSource);
    await tester.pumpAndSettle();
    expect(sources.mock2Selected.value, isTrue);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(HomeSheet), findsOneWidget);

    await tester.tap(tabs.at(0));
    await tester.pumpAndSettle();
    expect(sidebar.hitTestable(), findsNothing);
    expect(demoSource.hitTestable(), findsOneWidget);
    await tester.tap(tabs.at(1));
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(source).selected, isTrue);

    final sidebarScroll = find.descendant(
      of: sidebar,
      matching: find.byType(Scrollable),
    );
    final support = find.text('Support');
    final rate = find.widgetWithText(ListTile, 'Rate Musaic');
    final share = find.widgetWithText(ListTile, 'Share Musaic');
    final contact = find.widgetWithText(ListTile, 'Contact us');
    await tester.scrollUntilVisible(contact, 100, scrollable: sidebarScroll);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Support'), findsNothing);
    expect(tester.getTopLeft(support).dx, iconLeft);
    for (final action in [rate, share, contact]) {
      expect(find.descendant(of: sidebar, matching: action), findsOneWidget);
      expect(
        tester.getTopLeft(action).dy,
        greaterThan(tester.getTopLeft(support).dy),
      );
    }
    await tester.tap(contact);
    await tester.pumpAndSettle();
    expect(find.byType(AppAlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    expect(tester.widget<SettingsPage>(details).title, 'Music source');

    await tester.binding.setSurfaceSize(const Size(460, 380));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
    final about = find.widgetWithText(ListTile, 'About Musaic');
    await tester.scrollUntilVisible(about, 100, scrollable: sidebarScroll);
    await tester.pumpAndSettle();
    await tester.tap(about);
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(about).selected, isTrue);
    final terms = find.widgetWithText(ListTile, 'Terms of Service');
    await tester.scrollUntilVisible(
      terms,
      100,
      scrollable: find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(terms);
    await tester.pumpAndSettle();
    expect(
      tester.widget<SettingsPage>(find.byType(SettingsPage)).title,
      'Terms of Service',
    );
    expect(tester.widget<ListTile>(about).selected, isTrue);

    await tester.tap(find.byType(AppNavigationBackButton));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SettingsPage>(find.byType(SettingsPage)).title,
      'About Musaic',
    );
    expect(tester.widget<ListTile>(about).selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _Icons extends AppIconService {
  const _Icons();

  @override
  Future<AppIconSnapshot> read() async =>
      (supported: false, current: AppIconChoice.vinylPrimary);
}
