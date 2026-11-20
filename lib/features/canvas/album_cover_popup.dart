import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../artwork/presentation/directory_artwork.dart';
import '../artwork/presentation/xerox_palette.dart';

Future<void> showAlbumCoverPopup({
  required BuildContext source,
  required Widget artwork,
  required Widget playButton,
}) async {
  final navigator = Navigator.of(source, rootNavigator: true);
  final overlay = navigator.overlay!.context.findRenderObject()!;
  final tile = source.findRenderObject()! as RenderBox;
  final origin = MatrixUtils.transformRect(
    tile.getTransformTo(overlay),
    Offset.zero & tile.size,
  );
  final directories = DirectoryArtworkScope.watch(source).library;
  final palette = source
      .getInheritedWidgetOfExactType<XeroxPaletteScope>()
      ?.notifier;

  final route = RawDialogRoute<void>(
    barrierLabel: MaterialLocalizations.of(source).modalBarrierDismissLabel,
    barrierColor: const Color(0x99000000),
    transitionDuration: MediaQuery.disableAnimationsOf(source)
        ? Duration.zero
        : const Duration(milliseconds: 460),
    // The cover's transform is the complete transition. Skip the route fade.
    transitionBuilder: (_, _, _, child) => child,
    pageBuilder: (context, animation, _) {
      final content = _AlbumCoverPopup(
        origin: origin,
        animation: animation,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              artwork,
              AnimatedBuilder(
                animation: animation,
                child: playButton,
                builder: (_, child) =>
                    animation.isCompleted ? child! : const SizedBox.shrink(),
              ),
            ],
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
  await navigator.push(route);
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
      return AnimatedBuilder(
        animation: animation,
        child: RepaintBoundary(
          key: const ValueKey('album-cover-popup'),
          child: child,
        ),
        builder: (context, child) {
          final progress = Curves.easeInOutCubic.transform(animation.value);
          final rect = Rect.lerp(origin, square, progress)!;
          final offset = rect.center - square.center;
          final angle = math.pi * progress;
          // Swap faces at edge-on so the artwork always reads the right way.
          final faceAngle = progress < 0.5 ? angle : angle - math.pi;
          final perspective = Matrix4.identity()
            ..setEntry(3, 2, 0.7 / side)
            ..rotateY(-faceAngle);
          return Stack(
            children: [
              Positioned.fromRect(
                rect: square,
                child: IgnorePointer(
                  ignoring: animation.value < 1,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(offset.dx, offset.dy, 0, 1)
                      ..scaleByDouble(
                        rect.width / side,
                        rect.height / side,
                        1,
                        1,
                      )
                      ..multiply(perspective),
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
