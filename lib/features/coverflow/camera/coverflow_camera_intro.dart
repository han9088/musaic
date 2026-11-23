import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../storage/settings/usage_guide_preference.dart';
import '../../../ui/widgets/guide_touch_indicator.dart';
import '../../onboarding/first_use_gesture_guide.dart';
import '../../onboarding/gesture_guide_spotlight.dart';
import 'coverflow_camera_scene.dart';

class CoverFlowCameraIntro extends StatelessWidget {
  const CoverFlowCameraIntro({super.key, required this.builder});

  final Widget Function(
    VoidCallback? toggleCamera,
    Widget Function(Widget) decorateTitle,
  )
  builder;

  static final _fade = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 72),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 16),
  ]);
  static final _press = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.72, end: 1.15), weight: 18),
    TweenSequenceItem(tween: ConstantTween(1.15), weight: 48),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.72), weight: 34),
  ]);

  @override
  Widget build(BuildContext context) {
    Widget scene(GestureGuideAnimation? intro) => CoverFlowCameraScene(
      builder: (toggleCamera) => builder(toggleCamera, (title) {
        if (intro == null) return title;
        return GestureGuideSpotlight(
          opacity: intro.opacity,
          focus: intro.focus,
          caption: Text(AppLocalizations.of(context).usageGuideCameraHold),
          foreground: (_, target) => _buildTouch(target, intro.gesture),
          child: title,
        );
      }),
    );
    if (!CoverFlowCameraScene.supported) return scene(null);
    return FirstUseGestureGuide(
      intro: UsageGuideIntro.camera,
      enabled: true,
      duration: const Duration(seconds: 3),
      builder: (_, intro) => scene(intro),
    );
  }

  Widget _buildTouch(Rect target, Animation<double> intro) => Positioned(
    left: target.center.dx - GuideTouchIndicator.diameter / 2,
    top: target.center.dy - GuideTouchIndicator.diameter / 2,
    child: FadeTransition(
      opacity: intro.drive(_fade),
      child: ScaleTransition(
        scale: intro.drive(_press),
        child: const GuideTouchIndicator(
          key: ValueKey('coverflow-camera-intro-touch'),
        ),
      ),
    ),
  );
}
