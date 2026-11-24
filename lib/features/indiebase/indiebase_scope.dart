import 'package:flutter/widgets.dart';
import 'package:indiebase/indiebase.dart';

import '../../services/indiebase_runtime.dart';

class IndiebaseScope extends InheritedWidget {
  const IndiebaseScope({
    super.key,
    required this.runtime,
    required super.child,
  });

  final IndiebaseRuntime runtime;

  /// Creates the client on first use and returns null without project configuration.
  static IndiebaseClient? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<IndiebaseScope>()?.runtime.client;

  @override
  bool updateShouldNotify(IndiebaseScope oldWidget) =>
      runtime != oldWidget.runtime;
}
