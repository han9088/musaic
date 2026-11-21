import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../features/settings/settings_back_scroll_view.dart';
import '../../ui/bottom_sheet/bottom_sheet.dart';

const _slideCurve = Curves.easeInOutCubic;

PageRoute<void> pushSettingsPage({
  required BuildContext source,
  required NavigatorState navigator,
  required String path,
  required String title,
  required Widget body,
}) {
  final sheet = BottomSheetContent.of(source);
  final distance = navigator.overlay!.context.size!.height;
  final slide = CurveTween(curve: _slideCurve);
  final duration = MediaQuery.disableAnimationsOf(source)
      ? Duration.zero
      : const Duration(milliseconds: 420);
  late final _SettingsPageRoute route;
  route = _SettingsPageRoute(
    settings: RouteSettings(name: path),
    duration: duration,
    pageBuilder: (_, _, _) => SettingsPage(
      title: title,
      body: body,
      distance: distance,
      onPull: route.updatePull,
      onRelease: route.finishPull,
    ),
    transitionsBuilder: (_, animation, _, child) => AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, child) => ClipRect(
        child: Transform.translate(
          offset: Offset(0, distance * (1 - slide.evaluate(animation))),
          child: IgnorePointer(ignoring: !animation.isCompleted, child: child),
        ),
      ),
    ),
  );
  unawaited(navigator.push(route));
  final restoreSheet = sheet.slideOutForRoute(
    route.sheetAnimation.drive(slide),
    distance: distance,
  );
  unawaited(route.completed.whenComplete(restoreSheet));
  return route;
}

class _SettingsPageRoute extends PageRouteBuilder<void> {
  _SettingsPageRoute({
    required super.settings,
    required super.pageBuilder,
    required super.transitionsBuilder,
    required Duration duration,
  }) : super(
         // Keep the sheet visible behind the sliding page.
         opaque: false,
         transitionDuration: duration,
         reverseTransitionDuration: duration,
       );

  // ModalRoute temporarily reports a completed animation during offstage layout.
  Animation<double> get sheetAnimation => controller!.view;

  // Invert the easing so the page and sheet track the finger in pixels.
  static final _inverseSlide = Cubic(
    _slideCurve.b,
    _slideCurve.a,
    _slideCurve.d,
    _slideCurve.c,
  );

  void updatePull(double fraction) {
    if (!isCurrent) return;
    controller!.value = _inverseSlide.transform(1 - fraction);
  }

  void finishPull(bool dismiss) {
    if (!isCurrent) return;
    if (dismiss) {
      navigator!.pop();
    } else {
      unawaited(controller!.forward());
    }
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.body,
    required this.distance,
    required this.onPull,
    required this.onRelease,
  });

  final String title;
  final Widget body;
  final double distance;
  final ValueChanged<double> onPull;
  final ValueChanged<bool> onRelease;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white70,
        selectedColor: Colors.white,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
        ),
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SettingsBackScrollView(
        distance: distance,
        onPull: onPull,
        onRelease: onRelease,
        slivers: [
          SliverAppBar(
            pinned: true,
            centerTitle: true,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            scrolledUnderElevation: 0,
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              iconSize: 20,
              icon: const Icon(PhosphorIcons.caretDown),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(title, style: const TextStyle(color: Colors.white)),
          ),
          SliverSafeArea(top: false, sliver: SliverToBoxAdapter(child: body)),
        ],
      ),
    ),
  );
}
