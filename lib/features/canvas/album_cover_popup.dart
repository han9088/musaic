import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../ui/transitions/rect_flip_transition.dart';
import '../artwork/presentation/directory_artwork.dart';
import '../artwork/presentation/xerox_palette.dart';

Future<void> showAlbumCoverPopup({
  required BuildContext source,
  required Widget artwork,
  required VoidCallback onReturned,
  Widget? trackList,
  GestureLongPressStartCallback? onCoverLongPress,
}) async {
  final navigator = Navigator.of(source, rootNavigator: true);
  final origin = RectFlipTransition.originOf(source, navigator);
  final directories = DirectoryArtworkScope.watch(source).library;
  final palette = source
      .getInheritedWidgetOfExactType<XeroxPaletteScope>()
      ?.notifier;

  final route = RawDialogRoute<void>(
    barrierLabel: MaterialLocalizations.of(source).modalBarrierDismissLabel,
    barrierColor: const Color(0x99000000),
    transitionDuration: MediaQuery.disableAnimationsOf(source)
        ? Duration.zero
        : RectFlipTransition.duration,
    // The cover's transform is the complete transition. Skip the route fade.
    transitionBuilder: (_, _, _, child) => child,
    pageBuilder: (context, animation, _) {
      final front = ColoredBox(color: Colors.black, child: artwork);
      final content = _AlbumCoverPopup(
        origin: origin,
        animation: animation,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: onCoverLongPress,
          child: trackList == null
              ? front
              : AnimatedBuilder(
                  animation: animation,
                  child: front,
                  builder: (_, child) =>
                      RectFlipTransition.curve.transform(animation.value) >= 0.5
                      ? trackList
                      : child!,
                ),
        ),
      );
      return DirectoryArtworkScope(
        library: directories,
        child: palette == null
            ? content
            : XeroxPaletteScope(notifier: palette, child: content),
      );
    },
  );
  final popped = navigator.push(route);
  // Restore the grid in the same frame that removes the popup.
  route.animation!.addStatusListener((status) {
    if (status == AnimationStatus.dismissed) onReturned();
  });
  await popped;
  await route.completed;
}

class _AlbumCoverPopup extends StatelessWidget {
  const _AlbumCoverPopup({
    required this.origin,
    required this.animation,
    required this.child,
  });

  final Rect origin;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final padding = MediaQuery.viewPaddingOf(context);
      final safeWidth = size.width - 2 * math.max(padding.left, padding.right);
      final safeHeight =
          size.height - 2 * math.max(padding.top, padding.bottom);
      final side = math.min(math.min(safeWidth, safeHeight) * 0.88, 440.0);
      if (side <= 0) return const SizedBox.shrink();
      final square = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: side,
        height: side,
      );
      return Stack(
        children: [
          Positioned.fromRect(
            rect: square,
            child: RectFlipTransition(
              origin: origin,
              target: square,
              animation: animation,
              child: RepaintBoundary(
                key: const ValueKey('album-cover-popup'),
                child: child,
              ),
            ),
          ),
        ],
      );
    },
  );
}
