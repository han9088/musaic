import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/settings/playback_drag_demo.dart';
import 'package:musaic/features/settings/usage_guide_settings.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  testWidgets('The guide loops separate short and long drags on both sides', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: UsageGuideSettings()),
        ),
      ),
    );
    await tester.pump();

    for (final title in ['浏览专辑', '播放音乐', '音乐源', '切换布局', '相机背景']) {
      final heading = tester.widget<Text>(find.text(title));
      expect(heading.style?.color, Colors.white);
      expect(heading.style?.fontSize, 18);
    }

    final demo = find.byType(PlaybackDragDemo);
    final pill = find.byKey(const ValueKey('playback-drag-pill'));
    final touch = find.byKey(const ValueKey('playback-drag-touch'));
    expect(demo, findsOneWidget);
    expect(find.text('短拉松手切歌，拉住可快进或快退'), findsNothing);
    final card = tester.widget<Material>(
      find.descendant(of: demo, matching: find.byType(Material)),
    );
    expect((card.shape as RoundedRectangleBorder).side, BorderSide.none);
    final pillDecoration =
        tester.widget<DecoratedBox>(pill).decoration as ShapeDecoration;
    expect((pillDecoration.shape as StadiumBorder).side, BorderSide.none);
    await tester.ensureVisible(demo);
    final rest = tester.getRect(pill);
    await tester.pump(const Duration(milliseconds: 700));
    final shortRight = tester.getRect(pill);
    expect(shortRight.left, rest.left);
    expect(shortRight.right, greaterThan(rest.right));
    expect(tester.getCenter(touch).dx, closeTo(shortRight.right - 5, 0.5));
    expect(find.byIcon(PhosphorIcons.skipForwardFill), findsOneWidget);
    final touchCircle = tester.widget<DecoratedBox>(
      find.descendant(of: touch, matching: find.byType(DecoratedBox)),
    );
    final touchDecoration = touchCircle.decoration as BoxDecoration;
    expect(touchDecoration.shape, BoxShape.circle);
    expect(touchDecoration.color?.a, inExclusiveRange(0, 1));
    expect(touchDecoration.border, isNull);
    expect(touchCircle.child, isNull);

    await tester.pump(const Duration(milliseconds: 300));
    expect(touch, findsNothing);
    expect(tester.getRect(pill).width, lessThan(shortRight.width));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.getRect(pill), rest);
    expect(touch, findsNothing);

    await tester.pump(const Duration(milliseconds: 1000));
    final longRight = tester.getRect(pill);
    expect(longRight.left, rest.left);
    expect(longRight.right, greaterThan(shortRight.right));
    expect(find.byIcon(PhosphorIcons.fastForwardFill), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1550));
    final shortLeft = tester.getRect(pill);
    expect(shortLeft.right, rest.right);
    expect(shortLeft.left, lessThan(rest.left));
    expect(tester.getCenter(touch).dx, closeTo(shortLeft.left + 5, 0.5));
    expect(find.byIcon(PhosphorIcons.skipBackFill), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 650));
    expect(tester.getRect(pill), rest);
    expect(touch, findsNothing);

    await tester.pump(const Duration(milliseconds: 1000));
    final longLeft = tester.getRect(pill);
    expect(longLeft.right, rest.right);
    expect(longLeft.left, lessThan(shortLeft.left));
    expect(find.byIcon(PhosphorIcons.rewindFill), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 850));
    expect(tester.getRect(pill), rest);
    expect(touch, findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.getRect(pill), shortRight);
    expect(find.byIcon(PhosphorIcons.skipForwardFill), findsOneWidget);

    await tester.tap(demo);
    await tester.pump();
    expect(tester.getRect(pill), rest);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
