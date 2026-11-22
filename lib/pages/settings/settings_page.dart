import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../features/settings/settings_back_scroll_view.dart';
import '../../ui/bottom_sheet/bottom_sheet.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/transitions/directional_push_route.dart';

PageRoute<void> pushSettingsPage({
  required BuildContext source,
  required NavigatorState navigator,
  required String path,
  required String title,
  required Widget body,
}) {
  final sheet = BottomSheetContent.of(source);
  final distance = navigator.overlay!.context.size!.height;
  late final DirectionalPushRoute<void> route;
  route = DirectionalPushRoute<void>(
    direction: AxisDirection.up,
    opaque: false,
    settings: RouteSettings(name: path),
    animate: !MediaQuery.disableAnimationsOf(source),
    builder: (_) => SettingsPage(
      title: title,
      body: body,
      backIcon: PhosphorIcons.caretDown,
      pullToDismiss: (
        distance: distance,
        onPull: route.updateDismissGesture,
        onRelease: route.finishDismissGesture,
      ),
    ),
  );
  unawaited(navigator.push(route));
  final restoreSheet = sheet.slideOutForRoute(
    route.pushProgress,
    distance: distance,
  );
  unawaited(route.completed.whenComplete(restoreSheet));
  return route;
}

void pushSettingsDetail(BuildContext source, String title, Widget body) {
  unawaited(
    Navigator.of(source, rootNavigator: true).push(
      DirectionalPushRoute<void>(
        direction: AxisDirection.left,
        swipeToDismiss: true,
        animate: !MediaQuery.disableAnimationsOf(source),
        builder: (_) => SettingsPage(
          title: title,
          body: body,
          backIcon: PhosphorIcons.caretLeft,
        ),
      ),
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.body,
    required this.backIcon,
    this.pullToDismiss,
  });

  final String title;
  final Widget body;
  final IconData backIcon;
  final ({
    double distance,
    ValueChanged<double> onPull,
    void Function(double fraction, {required bool canceled}) onRelease,
  })?
  pullToDismiss;

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[
      SliverAppBar(
        pinned: true,
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          iconSize: appNavigationBackIconSize,
          icon: Icon(backIcon),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      SliverSafeArea(
        top: false,
        sliver: SliverToBoxAdapter(
          child: SettingsInteractionTheme(child: body),
        ),
      ),
    ];
    final pull = pullToDismiss;
    return Theme(
      data: Theme.of(context).copyWith(
        listTileTheme: const ListTileThemeData(
          contentPadding: settingsItemPadding,
          horizontalTitleGap: settingsItemTitleGap,
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
        body: pull == null
            ? CustomScrollView(slivers: slivers)
            : SettingsBackScrollView(
                distance: pull.distance,
                onPull: pull.onPull,
                onRelease: pull.onRelease,
                slivers: slivers,
              ),
      ),
    );
  }
}
