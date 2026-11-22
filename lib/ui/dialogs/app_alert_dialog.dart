// 文件职责：对话框、通知及其转场和展示管理。

import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'app_jelly_transition.dart';

const appDialogBarrierColor = Color(0x0A000000);
const appDialogNoiseOpacity = 0.06;
const appDialogSurfaceColor = AppColors.dialogSurface;
const appDialogBorderColor = Color(0x1FFFFFFF);
const appDialogBlurSigma = 4.0;
const appDialogNoiseAsset = 'assets/textures/dialog_noise.png';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Widget Function(BuildContext, Animation<double>, Widget)? layoutBuilder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  Duration? autoDismissAfter,
  T? autoDismissResult,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final disableAnimations =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  final route = _AppDialogRoute<T>(
    pageBuilder: (_, animation, _) {
      final content = Builder(builder: builder);
      return themes.wrap(
        layoutBuilder == null
            ? SafeArea(child: content)
            : Builder(
                builder: (context) => layoutBuilder(
                  context,
                  disableAnimations ? kAlwaysCompleteAnimation : animation,
                  content,
                ),
              ),
      );
    },
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: appDialogBarrierColor,
    transitionDuration: disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 520),
    reverseTransitionDuration: disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 190),
    transitionBuilder: (context, animation, _, child) {
      if (disableAnimations || layoutBuilder != null) return child;
      return AppJellyTransition(
        animation: animation,
        transformKey: const Key('app-alert-dialog-jelly-transform'),
        child: child,
      );
    },
  );
  final result = navigator.push<T>(route);
  final dismissTimer = autoDismissAfter == null
      ? null
      : Timer(autoDismissAfter, () {
          // 只关闭当前路由。如果此路由上方又出现了其他路由，
          // 定时器触发时不能误关闭那个无关界面。
          if (route.isCurrent) navigator.pop<T>(autoDismissResult);
        });
  return result.whenComplete(() => dismissTimer?.cancel());
}

/// 封装或定义应用对话框route相关类型与行为，负责对话框、通知及其转场和展示管理。
class _AppDialogRoute<T> extends RawDialogRoute<T> {
  _AppDialogRoute({
    required super.pageBuilder,
    required super.barrierDismissible,
    required super.barrierLabel,
    required super.barrierColor,
    required super.transitionDuration,
    required super.transitionBuilder,
    required this.reverseTransitionDuration,
  });

  @override
  final Duration reverseTransitionDuration;
}

/// 封装或定义应用提示对话框相关类型与行为，负责对话框、通知及其转场和展示管理。
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const <Widget>[],
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogTheme = theme.dialogTheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    // 问题现象：输入弹窗拉起键盘时，背景页和弹窗一起响应 Insets。
    // 问题原因：Dialog 默认在内部处理 viewInsets，背景 Scaffold 也会处理一次。
    // 修复思路：移除 Dialog 的默认 IME Insets，只在弹窗外层增加避让间距；
    // 底层页面保持原尺寸，键盘只把弹窗向上顶。
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: AnimatedPadding(
        key: const Key('app-alert-dialog-keyboard-padding'),
        padding: EdgeInsets.only(bottom: keyboardInset),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: ConstrainedBox(
            key: const Key('app-alert-dialog-surface'),
            constraints: const BoxConstraints(maxWidth: 460),
            child: AppDialogSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: DefaultTextStyle(
                        style:
                            dialogTheme.titleTextStyle ??
                            theme.textTheme.headlineSmall!.copyWith(
                              color: AppColors.dialogForeground,
                            ),
                        child: title!,
                      ),
                    ),
                  if (content != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        title == null ? 24 : 16,
                        24,
                        actions.isEmpty ? 24 : 16,
                      ),
                      child: DefaultTextStyle(
                        style:
                            dialogTheme.contentTextStyle ??
                            theme.textTheme.bodyMedium!.copyWith(
                              color: AppColors.dialogForeground,
                            ),
                        child: content!,
                      ),
                    ),
                  if (actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextButtonTheme(
                        data: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.dialogForeground,
                            disabledForegroundColor: Colors.white38,
                          ).merge(theme.textButtonTheme.style),
                        ),
                        child: OverflowBar(
                          alignment: MainAxisAlignment.end,
                          spacing: 8,
                          overflowAlignment: OverflowBarAlignment.end,
                          overflowSpacing: 4,
                          children: actions,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The frosted surface shared by dialogs and popup menus.
class AppDialogSurface extends StatelessWidget {
  const AppDialogSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppRadius.large),
    ),
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: borderRadius,
      boxShadow: const [
        BoxShadow(
          color: AppColors.dialogShadow,
          blurRadius: 32,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: appDialogBlurSigma,
          sigmaY: appDialogBlurSigma,
        ),
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: appDialogSurfaceColor,
                borderRadius: borderRadius,
                border: Border.all(color: appDialogBorderColor),
              ),
              child: SizedBox(width: double.infinity, child: child),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  key: const Key('app-alert-dialog-noise'),
                  opacity: appDialogNoiseOpacity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Image(
                        image: ResizeImage(
                          const AssetImage(appDialogNoiseAsset),
                          width: constraints.maxWidth.ceil(),
                          height: constraints.maxHeight.ceil(),
                        ),
                        fit: BoxFit.cover,
                        color: Colors.white,
                        colorBlendMode: BlendMode.difference,
                        filterQuality: FilterQuality.low,
                        excludeFromSemantics: true,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
