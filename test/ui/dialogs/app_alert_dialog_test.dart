import 'package:musaic/ui/dialogs/app_alert_dialog.dart';
import 'package:musaic/ui/widgets/app_dropdown_menu.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void expectFrostedOpening(WidgetTester tester) {
    final filter = find.descendant(
      of: find.byType(AppDialogSurface),
      matching: find.byType(BackdropFilter),
    );
    expect(tester.widget<BackdropFilter>(filter).enabled, isTrue);
    final opacityLayers = tester.widgetList<Opacity>(
      find.ancestor(of: filter, matching: find.byType(Opacity)),
    );
    expect(opacityLayers.map((layer) => layer.opacity), everyElement(1.0));
  }

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
    final noise = tester.widget<Image>(
      find.byKey(const Key('app-alert-dialog-noise')),
    );
    expect(noise.fit, BoxFit.cover);
    expect(noise.image, const AssetImage(appDialogNoiseAsset));
    expect(noise.opacity?.value, appDialogNoiseOpacity);
    expect(noise.color, isNull);
    expect(noise.colorBlendMode, isNull);
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
    expectFrostedOpening(tester);

    await tester.pump(const Duration(milliseconds: 110));
    expect(transform().transform.storage[0], greaterThan(1));
    expect(transform().transform.storage[5], greaterThan(1));
    expect(
      (transform().transform.storage[0] - transform().transform.storage[5])
          .abs(),
      greaterThan(0.012),
    );
    expectFrostedOpening(tester);

    await tester.pumpAndSettle();
    expect(transform().transform.storage[0], closeTo(1, 0.001));
    expect(transform().transform.storage[5], closeTo(1, 0.001));
    expectFrostedOpening(tester);
  });

  testWidgets('dropdowns open with the same frosted surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDropdownMenu<String>(
            title: 'Select',
            value: 'one',
            entries: const [
              AppDropdownMenuEntry('one', 'One'),
              AppDropdownMenuEntry('two', 'Two'),
            ],
            onSelected: (_) {},
            searchLabel: 'Search',
            emptyLabel: 'No results',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Select'));
    await tester.pump();
    expectFrostedOpening(tester);
    await tester.pump(const Duration(milliseconds: 60));
    expectFrostedOpening(tester);
    await tester.pumpAndSettle();
    expectFrostedOpening(tester);
  });

  testWidgets('dismisses substantially faster than it opens', (tester) async {
    await pumpDialog(tester, const Size(400, 800));

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(find.text('Title'), findsOneWidget);
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isTrue,
    );

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
