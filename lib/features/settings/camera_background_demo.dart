import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/widgets/guide_touch_indicator.dart';
import '../coverflow/coverflow_flip_card.dart';
import '../coverflow/coverflow_geometry.dart';
import 'usage_guide_demo_card.dart';

class CameraBackgroundDemo extends StatelessWidget {
  const CameraBackgroundDemo({super.key});

  static const _previewHeight = 164.0;

  @override
  Widget build(BuildContext context) => UsageGuideDemoCard(
    label: AppLocalizations.of(context).usageGuideCamera,
    duration: const Duration(milliseconds: 5600),
    builder: (context, animation) => SizedBox(
      height: _previewHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return AnimatedBuilder(
            animation: animation,
            child: _CoverFlowForeground(viewport: size),
            builder: (context, foreground) =>
                _scene(animation.value, size, foreground!),
          );
        },
      ),
    ),
  );

  static Widget _scene(double time, Size size, Widget foreground) {
    final previewOpacity =
        _progress(time, 0.28, 0.40) * (1 - _progress(time, 0.93, 0.99));
    final holdingTitle = time >= 0.09 && time < 0.32;
    final tappingBackground = time >= 0.54 && time < 0.62;
    final flash = time >= 0.62 ? 0.85 * (1 - _progress(time, 0.62, 0.65)) : 0.0;
    const touchRadius = GuideTouchIndicator.diameter / 2;
    final touchTarget = holdingTitle
        ? Offset(size.width / 2 + 28, 28)
        : Offset(size.width * 0.80, size.height - 19);

    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          key: const ValueKey('camera-demo-preview'),
          opacity: previewOpacity,
          child: const _CameraBackdrop(),
        ),
        foreground,
        if (time >= 0.65 && time < 0.93)
          Positioned.fromRect(
            rect: _photoBounds(time, size),
            child: FittedBox(
              key: const ValueKey('camera-demo-thumbnail'),
              child: SizedBox.fromSize(
                size: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [const _CameraBackdrop(), foreground],
                ),
              ),
            ),
          ),
        if (holdingTitle || tappingBackground)
          Positioned(
            left: touchTarget.dx - touchRadius,
            top: touchTarget.dy - touchRadius,
            child: const GuideTouchIndicator(
              key: ValueKey('camera-demo-touch'),
            ),
          ),
        if (flash > 0)
          Opacity(
            key: const ValueKey('camera-demo-flash'),
            opacity: flash,
            child: const ColoredBox(color: Colors.white),
          ),
      ],
    );
  }

  static Rect _photoBounds(double time, Size size) {
    final width = math.min(104.0, size.width * 0.19);
    final thumbnail = Rect.fromLTWH(
      size.width - 12 - width,
      12,
      width,
      size.height * width / size.width,
    );
    if (time >= 0.88) {
      final slide = Curves.easeInCubic.transform(_progress(time, 0.88, 0.93));
      return thumbnail.shift(Offset((size.width - thumbnail.left) * slide, 0));
    }
    final shrink = Curves.easeOutCubic.transform(_progress(time, 0.65, 0.72));
    return Rect.lerp(Offset.zero & size, thumbnail, shrink)!;
  }

  static double _progress(double time, double start, double end) =>
      ((time - start) / (end - start)).clamp(0.0, 1.0);
}

class _CameraBackdrop extends StatelessWidget {
  const _CameraBackdrop();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xB5141416), Color(0x30141416), Color(0x80141416)],
      ),
    ),
    child: Image.asset(
      'assets/usage_guide/camera_sky.jpg',
      cacheWidth: 1080,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    ),
  );
}

class _CoverFlowForeground extends StatelessWidget {
  const _CoverFlowForeground({required this.viewport});

  static const _selected = 26;
  static const _indices = [23, 24, 25, _selected, 27, 28, 29];

  final Size viewport;

  Widget _cover(int index, double size, Offset center) {
    final artwork = Image.asset(
      'assets/albums/$index.jpg',
      width: size,
      height: size,
      cacheWidth: 260,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    );
    return Positioned(
      key: ValueKey('camera-demo-cover-$index'),
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          artwork,
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x70FFFFFF), Colors.transparent],
            ).createShader(rect),
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: CoverFlowFlipCard.reflectionFraction,
                child: Transform.flip(flipY: true, child: artwork),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = CoverFlowGeometry.coverSize(
      Size(viewport.width, viewport.height - 36),
    );
    final geometry = CoverFlowGeometry.calculate(
      indices: _indices,
      position: _selected.toDouble(),
      size: size,
    );
    final center = CoverFlowGeometry.alignment(
      portrait: false,
      height: viewport.height,
      coverSize: size,
      bottomPadding: 0,
    ).alongSize(viewport);
    return Stack(
      children: [
        for (final index in _indices)
          _cover(
            index,
            geometry.widths[index]!,
            center.translate(geometry.centers[index]! - geometry.anchor, 0),
          ),
        const Positioned(
          left: 12,
          right: 12,
          top: 8,
          child: Column(
            children: [
              Text(
                'Ed Sheeran',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Color(0xFFBFC6CE), fontSize: 10),
              ),
              Text(
                '÷ (Deluxe)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
