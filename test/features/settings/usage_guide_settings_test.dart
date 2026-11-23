import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/settings/camera_background_demo.dart';
import 'package:musaic/features/settings/playback_drag_demo.dart';
import 'package:musaic/features/settings/usage_guide_settings.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  const guide = MaterialApp(
    locale: Locale('zh'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: UsageGuideSettings())),
  );

  testWidgets('The guide loops separate short and long drags on both sides', (
    tester,
  ) async {
    await tester.pumpWidget(guide);
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

  testWidgets(
    'The camera guide captures the full Cover Flow and shrinks it into a thumbnail',
    (tester) async {
      await tester.pumpWidget(guide);
      await tester.pump();

      final demo = find.byType(CameraBackgroundDemo);
      await tester.ensureVisible(demo);
      await tester.pump();
      expect(
        tester.getTopLeft(demo).dy,
        greaterThan(
          tester.getBottomLeft(find.textContaining('长按 Cover Flow')).dy,
        ),
      );
      final preview = find.byKey(const ValueKey('camera-demo-preview'));
      final touch = find.byKey(const ValueKey('camera-demo-touch'));
      final flash = find.byKey(const ValueKey('camera-demo-flash'));
      final thumbnail = find.byKey(const ValueKey('camera-demo-thumbnail'));
      final coverKeys = [
        for (var index = 23; index <= 29; index++)
          ValueKey('camera-demo-cover-$index'),
      ];
      final covers = [
        for (final key in coverKeys) tester.getRect(find.byKey(key)),
      ];
      final selected = covers[3];
      expect(selected.center.dx, closeTo(tester.getCenter(demo).dx, 0.01));
      for (var i = 1; i < covers.length; i++) {
        final cover = covers[i];
        expect(cover.left - covers[i - 1].right, closeTo(6, 0.01));
        expect(
          cover.top + cover.width / 2,
          closeTo(selected.top + selected.width / 2, 0.01),
        );
      }
      expect(covers[2].width, closeTo(selected.width * 0.7, 0.01));

      await tester.pump(const Duration(milliseconds: 750));
      expect(tester.getCenter(touch).dy, lessThan(tester.getCenter(demo).dy));
      expect(tester.widget<Opacity>(preview).opacity, 0);

      await tester.pump(const Duration(milliseconds: 1550));
      expect(tester.widget<Opacity>(preview).opacity, 1);
      expect(touch, findsNothing);

      await tester.pump(const Duration(milliseconds: 900));
      expect(
        tester.getCenter(touch).dy,
        greaterThan(tester.getCenter(demo).dy),
      );
      expect(thumbnail, findsNothing);

      await tester.pump(const Duration(milliseconds: 330));
      expect(flash, findsOneWidget);

      await tester.pump(const Duration(milliseconds: 130));
      final shrinkingPhoto = tester.getRect(thumbnail);
      final scene = tester.getRect(demo);
      expect(shrinkingPhoto.width, lessThan(scene.width));
      expect(
        shrinkingPhoto.size.aspectRatio,
        closeTo(scene.size.aspectRatio, 0.01),
      );
      for (final key in coverKeys) {
        expect(
          find.descendant(of: thumbnail, matching: find.byKey(key)),
          findsOneWidget,
        );
      }

      await tester.pump(const Duration(milliseconds: 570));
      final restingPhoto = tester.getRect(thumbnail);
      expect(restingPhoto.width, lessThan(shrinkingPhoto.width));
      expect(restingPhoto.top, closeTo(scene.top + 12, 0.01));
      expect(restingPhoto.right, closeTo(scene.right - 12, 0.01));

      await tester.pump(const Duration(milliseconds: 810));
      expect(tester.getRect(thumbnail).left, greaterThan(restingPhoto.left));

      await tester.pump(const Duration(milliseconds: 560));
      expect(tester.widget<Opacity>(preview).opacity, 0);
      expect(thumbnail, findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
