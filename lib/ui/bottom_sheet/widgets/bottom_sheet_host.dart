import 'package:material_ui/material_ui.dart';

import '../constants.dart';
import '../host_layout_mode.dart';
import '../push_direction.dart';
import '../push_layout.dart';
import '../types.dart';

/// Transforms the app host based on active sheet mode.
class BottomSheetHost extends StatelessWidget {
  const BottomSheetHost({
    super.key,
    required this.hostLayoutMode,
    required this.progress,
    required this.sheetTopY,
    required this.pushProgressOpenY,
    required this.pushSheetHeight,
    required this.topInset,
    required this.screenHeight,
    required this.screenWidth,
    required this.layout,
    required this.child,
  });

  final ValueNotifier<int> hostLayoutMode;
  final ValueNotifier<double> progress;
  final ValueNotifier<double> sheetTopY;
  final ValueNotifier<double> pushProgressOpenY;
  final ValueNotifier<double> pushSheetHeight;
  final double topInset;
  final double screenHeight;
  final double screenWidth;
  final BottomSheetLayoutOptions layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        hostLayoutMode,
        progress,
        sheetTopY,
        pushProgressOpenY,
        pushSheetHeight,
      ]),
      builder: (context, _) {
        final mode = hostLayoutMode.value;
        if (mode == HostLayoutMode.pushBottom ||
            mode == HostLayoutMode.pushTop) {
          return _buildPush(mode);
        }
        if (mode == HostLayoutMode.presentation) {
          return _buildPresentation();
        }
        return child;
      },
    );
  }

  Widget _buildPresentation() {
    final p = progress.value;
    final scale = interpolateClamped(p, 0, 1, 1, layout.presentation.hostScale);
    final translateY = interpolateClamped(
      p,
      0,
      1,
      0,
      getPresentationHostTopInset(
        screenWidth,
        presentationHostScale: layout.presentation.hostScale,
        presentationHostTopInsetMin: layout.presentation.hostTopInsetMin,
      ),
    );
    final radius = getBottomSheetCornerRadius(
      p,
      maxRadius: layout.presentation.cornerRadius,
    );

    // Clip inside both transforms so the radius follows the scaled host edge.
    // Keeping this ordering local to presentation preserves push rendering.
    return Transform.translate(
      offset: Offset(0, translateY),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPush(int mode) {
    final pushDirectionJs = mode == HostLayoutMode.pushTop
        ? PushDirectionJs.top
        : PushDirectionJs.bottom;
    final pushLayoutTopInset = pushDirectionJs == PushDirectionJs.top
        ? 0.0
        : topInset;
    final topY = sheetTopY.value;
    final openY = pushProgressOpenY.value;
    final sheetHeight = pushDirectionJs == PushDirectionJs.top
        ? (pushSheetHeight.value > 0
              ? pushSheetHeight.value
              : getPushSheetHeightForDetent(
                  BottomSheetDetent.medium,
                  screenHeight,
                  0,
                ))
        : (screenHeight - topY).clamp(0.0, screenHeight);
    final pushProgress = getPushLayoutProgress(
      topY,
      openY,
      screenHeight,
      pushDirectionJs,
      pushLayoutTopInset,
    );
    final hostOffset = getPushHostOffsetFromSheetTopY(
      screenWidth,
      screenHeight,
      topY,
      openY,
      pushDirectionJs,
      pushLayoutTopInset,
      sheetHeight,
      targetInset: layout.push.hostHorizontalInset,
      verticalGap: layout.push.hostVerticalGap,
    );
    final scale = getPushScale(
      screenWidth,
      pushProgress,
      targetInset: layout.push.hostHorizontalInset,
    );
    // Fixed radius (not progress-lerped) so open state matches sheet.
    // Clip inside transforms — otherwise corners stay at screen edge while
    // the host translates away and look square when open.
    final corners = getPushHostCornerRadiusStyle(
      1,
      pushDirectionJs,
      maxRadius: layout.presentation.cornerRadius,
    );
    final alignment = pushDirectionJs == PushDirectionJs.top
        ? Alignment.topCenter
        : Alignment.bottomCenter;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(corners.topLeft ?? 0),
      topRight: Radius.circular(corners.topRight ?? 0),
      bottomLeft: Radius.circular(corners.bottomLeft ?? 0),
      bottomRight: Radius.circular(corners.bottomRight ?? 0),
    );

    return Transform.translate(
      offset: Offset(0, hostOffset),
      child: Transform.scale(
        scale: scale,
        alignment: alignment,
        child: ClipRRect(borderRadius: borderRadius, child: child),
      ),
    );
  }
}
