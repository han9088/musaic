import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../features/settings/settings_back_scroll_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/bottom_sheet/bottom_sheet.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/transitions/directional_push_route.dart';
import '../../ui/widgets/app_navigation_back_button.dart';

PageRoute<void> pushSettingsPage({
  required BuildContext source,
  required NavigatorState navigator,
  required String path,
  required String Function(AppLocalizations) title,
  required Widget body,
  bool bodyIsSliver = false,
  Widget? footer,
  Widget? fixedFooter,
}) {
  final sheet = BottomSheetContent.of(source);
  final distance = navigator.overlay!.context.size!.height;
  late final DirectionalPushRoute<void> route;
  route = DirectionalPushRoute<void>(
    direction: AxisDirection.up,
    opaque: false,
    settings: RouteSettings(name: path),
    animate: !MediaQuery.disableAnimationsOf(source),
    builder: (context) => SettingsPage(
      title: title(AppLocalizations.of(context)),
      body: body,
      bodyIsSliver: bodyIsSliver,
      footer: footer,
      fixedFooter: fixedFooter,
      backIcon: PhosphorIcons.caretDownBold,
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
          backIcon: PhosphorIcons.caretLeftBold,
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
    this.bodyIsSliver = false,
    this.footer,
    this.fixedFooter,
    this.pullToDismiss,
  });

  final String title;
  final Widget body;
  final IconData backIcon;
  final bool bodyIsSliver;
  final Widget? footer;
  final Widget? fixedFooter;
  final ({
    double distance,
    ValueChanged<double> onPull,
    void Function(double fraction, {required bool canceled}) onRelease,
  })?
  pullToDismiss;

  @override
  Widget build(BuildContext context) {
    const backPadding =
        settingsContentInset -
        (AppNavigationBackButton.hitSize -
                AppNavigationBackButton.circleDiameter) /
            2;
    final bottomAction = fixedFooter;
    final slivers = <Widget>[
      SliverAppBar(
        pinned: true,
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leadingWidth: backPadding + AppNavigationBackButton.hitSize,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: backPadding),
          child: AppNavigationBackButton(
            icon: backIcon,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      SliverSafeArea(
        top: false,
        bottom: footer == null && !bodyIsSliver,
        sliver: SettingsInteractionTheme(
          child: bodyIsSliver ? body : SliverToBoxAdapter(child: body),
        ),
      ),
      if (footer case final pageFooter?)
        SliverFillRemaining(
          hasScrollBody: false,
          child: SafeArea(
            top: false,
            child: Align(alignment: Alignment.bottomCenter, child: pageFooter),
          ),
        ),
    ];
    final pull = pullToDismiss;
    final scrollView = pull == null
        ? CustomScrollView(slivers: slivers)
        : SettingsBackScrollView(
            distance: pull.distance,
            onPull: pull.onPull,
            onRelease: pull.onRelease,
            slivers: slivers,
          );
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
        extendBody: bottomAction != null,
        bottomNavigationBar: bottomAction == null
            ? null
            : SafeArea(top: false, child: bottomAction),
        // Keep filling slivers above the system inset even while scrolling.
        body: bodyIsSliver
            ? SafeArea(top: false, left: false, right: false, child: scrollView)
            : scrollView,
      ),
    );
  }
}
