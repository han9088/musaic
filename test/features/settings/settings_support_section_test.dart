import 'package:flutter/services.dart';
import 'package:flutter_email_sender_method_channel/flutter_email_sender_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/settings/settings_support_section.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  const app = MaterialApp(
    locale: Locale('zh'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SettingsSupportSection()),
  );

  testWidgets('Contact us opens email and links for a mainland device locale', (
    tester,
  ) async {
    final dispatcher = tester.binding.platformDispatcher;
    dispatcher.localeTestValue = const Locale('en', 'CN');
    addTearDown(dispatcher.clearLocaleTestValue);
    MethodChannelFlutterEmailSender.registerWith();
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    const emailChannel = MethodChannel('flutter_email_sender');
    final messenger = tester.binding.defaultBinaryMessenger;
    final opened = <String>[];
    final drafts = <Map<Object?, Object?>>[];
    var canCompose = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'launch');
      opened.add(call.arguments['url'] as String);
      return true;
    });
    messenger.setMockMethodCallHandler(emailChannel, (call) async {
      if (call.method == 'getCapabilities') return {'canSend': canCompose};
      expect(call.method, 'send');
      drafts.add(call.arguments as Map<Object?, Object?>);
      return 'cancelled';
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(emailChannel, null);
    });

    await tester.pumpWidget(app);
    final contact = find.widgetWithText(ListTile, '联系我们');
    expect(
      find.descendant(
        of: contact,
        matching: find.byIcon(PhosphorIcons.chatCircleDots),
      ),
      findsOneWidget,
    );
    await tester.tap(contact);
    await tester.pumpAndSettle();

    for (final (address, logo) in [
      (
        'deskbtm@gmail.com',
        find.image(const AssetImage('assets/branding/gmail.png')),
      ),
      ('x.com/deskbtm', find.byIcon(PhosphorIcons.xLogo)),
      ('github.com/deskbtm/musaic', find.byIcon(PhosphorIcons.githubLogo)),
      ('小红书', find.image(const AssetImage('assets/branding/xiaohongshu.png'))),
    ]) {
      final entry = find.widgetWithText(ListTile, address);
      expect(find.descendant(of: entry, matching: logo), findsOneWidget);
      await tester.tap(entry);
      await tester.pumpAndSettle();
    }
    expect(drafts.single['recipients'], ['deskbtm@gmail.com']);
    expect(drafts.single['attachments'], isEmpty);
    expect(opened, [
      'https://x.com/deskbtm',
      'https://github.com/deskbtm/musaic',
      'https://xhslink.cn/o/5Od3qtTfSu0',
    ]);

    final unavailable = find.text('邮件操作未完成，请检查邮件应用后重试。');
    expect(unavailable, findsNothing);
    canCompose = false;
    await tester.tap(find.text('deskbtm@gmail.com'));
    await tester.pumpAndSettle();
    expect(unavailable, findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Xiaohongshu follows the device locale with a Chinese fallback', (
    tester,
  ) async {
    final dispatcher = tester.binding.platformDispatcher;
    addTearDown(dispatcher.clearLocaleTestValue);
    await tester.pumpWidget(app);

    for (final (locale, showsXiaohongshu) in const [
      (Locale('zh'), true),
      (Locale('zh', 'SG'), false),
      (Locale('zh', 'TW'), false),
      (Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), false),
      (Locale('en', 'US'), false),
    ]) {
      dispatcher.localeTestValue = locale;
      await tester.tap(find.text('联系我们'));
      await tester.pumpAndSettle();
      expect(
        find.text('小红书'),
        showsXiaohongshu ? findsOneWidget : findsNothing,
        reason: locale.toLanguageTag(),
      );
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
    }
  });
}
