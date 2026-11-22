import 'package:musaic/ui/dialogs/app_alert_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester,
    Size size, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppDialog<void>(
              context: context,
              builder: (_) => const AppAlertDialog(
                title: Text('Title'),
                content: Text('Content'),
                actions: [TextButton(onPressed: null, child: Text('OK'))],
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('uses wider responsive dimensions and frosted layers', (
    tester,
  ) async {
    await pumpDialog(tester, const Size(800, 600));

    final surface = find.byKey(const Key('app-alert-dialog-surface'));
    expect(tester.getSize(surface).width, 460);
    final decorations = tester.widgetList<DecoratedBox>(
      find.descendant(of: surface, matching: find.byType(DecoratedBox)),
    );
    expect(
      decorations.map((box) => (box.decoration as BoxDecoration).color),
      contains(const Color.fromARGB(197, 0, 0, 0)),
    );
    for (final text in ['Title', 'Content']) {
      final style = DefaultTextStyle.of(tester.element(find.text(text))).style;
      expect(style.color, Colors.white);
    }
    expect(find.byType(BackdropFilter), findsOneWidget);
    final noise = tester.widget<Image>(find.byType(Image));
    expect(noise.fit, BoxFit.cover);
    expect(noise.color, Colors.white);
    expect(noise.colorBlendMode, BlendMode.difference);
    expect(noise.image, isA<ResizeImage>());
    final noiseOpacity = tester.widget<Opacity>(
      find.byKey(const Key('app-alert-dialog-noise')),
    );
    expect(noiseOpacity.opacity, appDialogNoiseOpacity);
    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color, appDialogBarrierColor);
  });

  testWidgets('keeps 40 pixel side margins on a phone', (tester) async {
    await pumpDialog(tester, const Size(400, 800));

    final surface = find.byKey(const Key('app-alert-dialog-surface'));
    expect(tester.getSize(surface).width, 320);
  });

  testWidgets('opens with an asymmetric jelly overshoot', (tester) async {
    await pumpDialog(tester, const Size(400, 800), settle: false);

    Transform transform() => tester.widget<Transform>(
      find.byKey(const Key('app-alert-dialog-jelly-transform')),
    );

    expect(transform().transform.storage[0], closeTo(0.84, 0.001));
    expect(transform().transform.storage[5], closeTo(0.84, 0.001));

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

  testWidgets('dismisses substantially faster than it opens', (tester) async {
    await pumpDialog(tester, const Size(400, 800));

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(find.text('Title'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Title'), findsNothing);
  });

  testWidgets('applies keyboard inset only to the dialog', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);

    await pumpDialog(tester, const Size(400, 800));

    final padding = tester.widget<AnimatedPadding>(
      find.byKey(const Key('app-alert-dialog-keyboard-padding')),
    );
    expect(padding.padding.resolve(TextDirection.ltr).bottom, 300);

    final dialogContext = tester.element(
      find.byKey(const Key('app-alert-dialog-surface')),
    );
    expect(MediaQuery.viewInsetsOf(dialogContext).bottom, 0);
  });

  testWidgets('does not automatically focus dialog inputs', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppDialog<void>(
              context: context,
              builder: (_) =>
                  AppAlertDialog(content: TextField(focusNode: focusNode)),
            ),
            child: const Text('Open input'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open input'));
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
