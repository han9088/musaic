// 文件职责：专辑墙布局切换及过渡效果。

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../artwork/artwork_renderer.dart';
import '../artwork/model/artwork_identity.dart';
import '../canvas/album_grid_snapshot.dart';
import '../cover_flow/cover_flow_geometry.dart';

/// 封装或定义专辑布局过渡相关类型与行为，负责专辑墙布局切换及过渡效果。
class AlbumLayoutTransition extends StatelessWidget {
  const AlbumLayoutTransition({
    super.key,
    required this.albums,
    required this.snapshot,
    required this.position,
    required this.tilt,
    required this.gridOffset,
    required this.progress,
    this.xerox = false,
  });

  final List<Map<String, dynamic>> albums;
  final AlbumGridSnapshot snapshot;
  final double position;
  final double tilt;
  final int gridOffset;
  final Animation<double> progress;
  final bool xerox;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final selected = albums[position.round() % albums.length];
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, child) => ColoredBox(
              color: Color.lerp(
                const Color(0xff171715),
                Colors.black,
                progress.value,
              )!,
              child: child,
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = math.min(
                    constraints.maxHeight * 0.65,
                    constraints.maxWidth * 0.31,
                  );
                  final center = position.round();
                  final first = math.min(center - 7, gridOffset);
                  final last = math.max(
                    center + 7,
                    gridOffset + snapshot.cells.length - 1,
                  );
                  final indices = List.generate(
                    last - first + 1,
                    (i) => first + i,
                  );
                  final geometry = CoverFlowGeometry.calculate(
                    indices: indices,
                    position: position,
                    size: size,
                  );
                  final widths = geometry.widths;
                  final centers = geometry.centers;
                  final anchor = geometry.anchor;
                  final paintOrder = indices.toList()
                    ..sort(
                      (a, b) =>
                          (b - position).abs().compareTo((a - position).abs()),
                    );
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: progress,
                          builder: (context, child) => Transform(
                            alignment: const Alignment(0, 0.04),
                            transform: Matrix4.identity()
                              ..setEntry(
                                3,
                                2,
                                0.88 / constraints.maxWidth * progress.value,
                              )
                              ..rotateY(tilt * progress.value),
                            child: child,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (final index in paintOrder)
                                _tile(
                                  index,
                                  Rect.fromLTWH(
                                    constraints.maxWidth / 2 +
                                        centers[index]! -
                                        anchor -
                                        widths[index]! / 2,
                                    constraints.maxHeight * 0.52 -
                                        widths[index]! / 2,
                                    widths[index]!,
                                    widths[index]!,
                                  ),
                                  constraints.biggest,
                                  padding,
                                ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 20,
                        right: 20,
                        child: FadeTransition(
                          opacity: progress.drive(
                            CurveTween(curve: const Interval(0.55, 1)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                selected['artist'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xffbfc6ce),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                selected['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(int index, Rect destination, Size size, EdgeInsets padding) {
    final cell = index - gridOffset;
    final hasSource = cell >= 0 && cell < snapshot.cells.length;
    final source = hasSource
        ? snapshot.rectFor(
            cell,
            Size(
              size.width + padding.horizontal,
              size.height + padding.vertical,
            ),
            padding,
          )
        : destination.translate(0, size.height * 0.2);
    final album = albums[index % albums.length];
    final asset = album['asset'] as String;
    final rawIdentity = album['id'] as String?;
    Widget image() => albumArtwork(
      asset,
      artworkIdentity: rawIdentity == null ? null : ArtworkIdentity(rawIdentity),
      width: 142,
      height: 142,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      xerox: xerox,
    );
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: progress,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 142,
            height: 142 * 1.36,
            child: Column(
              children: [
                RepaintBoundary(child: image()),
                if ((index - position).abs() <= 7)
                  SizedBox(
                    height: 142 * 0.36,
                    child: FadeTransition(
                      opacity: progress.drive(
                        CurveTween(curve: const Interval(0.65, 1)),
                      ),
                      child: RepaintBoundary(
                        child: ClipRect(
                          child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (rect) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x70ffffff), Color(0x00ffffff)],
                            ).createShader(rect),
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              maxHeight: 142,
                              child: Transform.flip(
                                flipY: true,
                                child: image(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        builder: (context, child) {
          final rect = Rect.lerp(source, destination, progress.value)!;
          return Opacity(
            opacity: hasSource ? 1 : progress.value,
            child: Transform(
              alignment: Alignment.topLeft,
              transform: Matrix4.identity()
                ..translateByDouble(rect.left, rect.top, 0, 1)
                ..scaleByDouble(rect.width / 142, rect.height / 142, 1, 1),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
