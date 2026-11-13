import 'package:musaic/ui/dialogs/app_notification.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHarness(
    WidgetTester tester, {
    required void Function(BuildContext context) onPressed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => onPressed(context),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('uses the bottom stack with smooth layer movement', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      onPressed: (context) => showAppNotification(
        context,
        title: 'Connected',
        message: 'Vehicle is online',
        type: AppNotificationType.success,
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Vehicle is online'), findsOneWidget);
    expect(find.byKey(const Key('app-notification-surface')), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    final statusIcon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    expect(statusIcon.color?.a, closeTo(appNotificationIconOpacity, 0.001));

    final position = tester.widget<AnimatedPositioned>(
      find.byKey(const Key('app-notification-position')),
    );
    final scale = tester.widget<AnimatedScale>(
      find.byKey(const Key('app-notification-scale')),
    );
    expect(position.bottom, appNotificationBottomInset);
    expect(position.duration, appNotificationAnimationDuration);
    expect(position.curve, Curves.easeOutCubic);
    expect(scale.scale, 1);
    expect(scale.duration, appNotificationAnimationDuration);
    expect(scale.curve, Curves.easeOutCubic);
  });

  testWidgets('opens with dialog jelly scaling and no vertical translation', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      onPressed: (context) => showAppNotification(
        context,
        message: 'Jelly',
        duration: Duration.zero,
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    Transform transform() => tester.widget<Transform>(
      find.byKey(const Key('app-notification-jelly-transform')),
    );

    expect(transform().transform.storage[0], closeTo(0.84, 0.001));
    expect(transform().transform.storage[5], closeTo(0.84, 0.001));
    expect(find.byKey(const Key('app-notification-translation')), findsNothing);

    await tester.pump(const Duration(milliseconds: 110));
    expect(transform().transform.storage[0], greaterThan(1));
    expect(transform().transform.storage[5], greaterThan(1));
    expect(
      (transform().transform.storage[0] - transform().transform.storage[5])
          .abs(),
      greaterThan(0.012),
    );

    await tester.pumpAndSettle();
    expect(transform().transform.storage[0], closeTo(1, 0.001));
    expect(transform().transform.storage[5], closeTo(1, 0.001));
  });

  testWidgets('uses the same frosted noise surface as dialogs', (tester) async {
    await pumpHarness(
      tester,
      onPressed: (context) => showAppNotification(
        context,
        message: 'Surface',
        duration: Duration.zero,
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    final surface = tester.widget<DecoratedBox>(
      find.byKey(const Key('app-notification-surface')),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.color, const Color.fromARGB(242, 255, 255, 255));
    expect(decoration.border, Border.all(color: appNotificationBorderColor));

    final noise = tester.widget<Opacity>(
      find.byKey(const Key('app-notification-noise')),
    );
    expect(noise.opacity, appNotificationNoiseOpacity);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect(image.color, Colors.white);
    expect(image.colorBlendMode, BlendMode.difference);
  });

  testWidgets(
    'stacks older notifications upward with the exact scale formula',
    (tester) async {
      var count = 0;
      await pumpHarness(
        tester,
        onPressed: (context) {
          count += 1;
          showAppNotification(
            context,
            message: 'Message $count',
            duration: Duration.zero,
          );
        },
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Message 1'), findsOneWidget);
      expect(find.text('Message 2'), findsOneWidget);
      final oldPosition = tester.widget<AnimatedPositioned>(
        find.ancestor(
          of: find.text('Message 1'),
          matching: find.byKey(const Key('app-notification-position')),
        ),
      );
      final newPosition = tester.widget<AnimatedPositioned>(
        find.ancestor(
          of: find.text('Message 2'),
          matching: find.byKey(const Key('app-notification-position')),
        ),
      );
      final oldScale = tester.widget<AnimatedScale>(
        find.ancestor(
          of: find.text('Message 1'),
          matching: find.byKey(const Key('app-notification-scale')),
        ),
      );
      final newScale = tester.widget<AnimatedScale>(
        find.ancestor(
          of: find.text('Message 2'),
          matching: find.byKey(const Key('app-notification-scale')),
        ),
      );

      expect(oldPosition.bottom, 85);
      expect(newPosition.bottom, 70);
      expect(oldScale.scale, closeTo(0.93, 0.001));
      expect(newScale.scale, 1);
    },
  );

  testWidgets('automatically dismisses after the requested duration', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      onPressed: (context) => showAppNotification(
        context,
        message: 'Temporary',
        duration: const Duration(milliseconds: 2000),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(appNotificationEnterDuration);
    expect(find.text('Temporary'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1479));
    expect(find.text('Temporary'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Temporary'), findsNothing);
  });

  testWidgets('supports swipe dismissal', (tester) async {
    await pumpHarness(
      tester,
      onPressed: (context) => showAppNotification(
        context,
        message: 'Swipe me',
        duration: Duration.zero,
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Swipe me'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Swipe me'), findsNothing);
  });

  testWidgets('runs an action and dismisses', (tester) async {
    var acted = false;
    await pumpHarness(
      tester,
      onPressed: (context) => showAppNotification(
        context,
        message: 'Saved',
        duration: Duration.zero,
        actionLabel: 'Undo',
        onAction: () => acted = true,
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(acted, isTrue);
    expect(find.text('Saved'), findsNothing);
  });
}
