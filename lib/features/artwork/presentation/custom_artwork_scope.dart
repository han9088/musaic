import 'package:flutter/widgets.dart';

import '../../../storage/music/custom_artwork_store.dart';

class CustomArtworkScope extends InheritedNotifier<CustomArtworkStore> {
  const CustomArtworkScope({
    super.key,
    required CustomArtworkStore store,
    required super.child,
  }) : super(notifier: store);

  static CustomArtworkStore? watch(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CustomArtworkScope>()
      ?.notifier;

  static CustomArtworkStore? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CustomArtworkScope>()?.notifier;
}
