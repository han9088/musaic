import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

// Keep delightful_toast's bottom stack geometry.
const appNotificationDefaultDuration = Duration(milliseconds: 5000);
const appNotificationAnimationDuration = Duration(milliseconds: 700);
const appNotificationEnterDuration = Duration(milliseconds: 520);
const appNotificationExitDuration = Duration(milliseconds: 190);
const appNotificationBottomInset = 70.0;
const appNotificationStackGap = 15.0;
const appNotificationNoiseOpacity = 0.06;
const appNotificationIconOpacity = 0.68;
const appNotificationBorderColor = Color(0x14000000);
const _appNotificationNoiseAsset = 'assets/textures/dialog_noise.png';

enum AppNotificationType { info, success, warning, error }

/// A handle that can dismiss a notification before its timeout.
final class AppNotificationHandle {
  AppNotificationHandle._(this._controller, this._record);

  final _AppNotificationController _controller;
  final _AppNotificationRecord _record;

  void dismiss() {
    final state = _record.cardKey.currentState;
    if (state != null) {
      state.dismiss();
    } else {
      _controller.remove(_record);
    }
  }
}

/// Shows a bottom notification that replaces the app's former SnackBars.
///
/// Multiple notifications keep `delightful_toast`'s position and scale stack,
/// while motion and surface treatment match the app dialog.
AppNotificationHandle showAppNotification(
  BuildContext context, {
  required String message,
  String? title,
  AppNotificationType type = AppNotificationType.info,
  Duration duration = appNotificationDefaultDuration,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final controller = _controllers[overlay] ??= _AppNotificationController(
    overlay,
  );
  final record = _AppNotificationRecord(
    title: title,
    message: message,
    type: type,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  controller.add(record);
  return AppNotificationHandle._(controller, record);
}

final Expando<_AppNotificationController> _controllers =
    Expando<_AppNotificationController>('app notification controllers');

final class _AppNotificationRecord {
  _AppNotificationRecord({
    required this.title,
    required this.message,
    required this.type,
    required this.duration,
    required this.actionLabel,
    required this.onAction,
  });

  final String? title;
  final String message;
  final AppNotificationType type;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final GlobalKey<_AppNotificationCardState> cardKey = GlobalKey();
}

final class _AppNotificationController {
  _AppNotificationController(this.overlay);

  final OverlayState overlay;
  final ValueNotifier<List<_AppNotificationRecord>> records = ValueNotifier(
    const [],
  );
  OverlayEntry? _entry;

  void add(_AppNotificationRecord record) {
    _ensureOverlay();
    records.value = [...records.value, record];
  }

  void remove(_AppNotificationRecord record) {
    if (!records.value.contains(record)) return;
    records.value = records.value.where((item) => item != record).toList();
    if (records.value.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (records.value.isNotEmpty) return;
        _entry?.remove();
        _entry = null;
      });
    }
  }

  void _ensureOverlay() {
    if (_entry?.mounted ?? false) return;
    _entry = OverlayEntry(
      builder: (context) => _AppNotificationOverlay(controller: this),
    );
    overlay.insert(_entry!);
  }
}

/// 问题现象：纵向通知列表会把多条消息完全展开，和目标库的卡片堆栈不一致。
/// 问题原因：上一版只复用了“多条可见”的概念，没有复刻每层的位置与缩放公式。
/// 修复思路：使用与 delightful_toast 相同的 70px 底部基准、15px 层间距和
/// 缩放公式；层级变化只做平滑插值，新卡使用 Dialog 同款 Jelly 缩放。
class _AppNotificationOverlay extends StatelessWidget {
  const _AppNotificationOverlay({required this.controller});

  final _AppNotificationController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ValueListenableBuilder<List<_AppNotificationRecord>>(
        valueListenable: controller.records,
        builder: (context, records, _) {
          return Stack(
            key: const Key('app-notification-stack'),
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < records.length; index++)
                _AppNotificationStackItem(
                  key: ObjectKey(records[index]),
                  depth: records.length - index - 1,
                  record: records[index],
                  onDismissed: () => controller.remove(records[index]),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AppNotificationStackItem extends StatelessWidget {
  const _AppNotificationStackItem({
    super.key,
    required this.depth,
    required this.record,
    required this.onDismissed,
  });

  final int depth;
  final _AppNotificationRecord record;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final scale = depth == 0 ? 1.0 : (0.97 - (depth / 25)).clamp(0.0, 1.0);

    return AnimatedPositioned(
      key: const Key('app-notification-position'),
      duration: appNotificationAnimationDuration,
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: appNotificationBottomInset + (appNotificationStackGap * depth),
      child: Material(
        color: Colors.transparent,
        child: AnimatedScale(
          key: const Key('app-notification-scale'),
          duration: appNotificationAnimationDuration,
          curve: Curves.easeOutCubic,
          scale: scale,
          child: _AppNotificationCard(
            key: record.cardKey,
            record: record,
            onDismissed: onDismissed,
          ),
        ),
      ),
    );
  }
}

class _AppNotificationCard extends StatefulWidget {
  const _AppNotificationCard({
    super.key,
    required this.record,
    required this.onDismissed,
  });

  final _AppNotificationRecord record;
  final VoidCallback onDismissed;

  @override
  State<_AppNotificationCard> createState() => _AppNotificationCardState();
}

class _AppNotificationCardState extends State<_AppNotificationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _jelly;
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _jelly = AnimationController(
      vsync: this,
      duration: appNotificationEnterDuration,
      reverseDuration: appNotificationExitDuration,
    )..forward();
    if (widget.record.duration > Duration.zero) {
      _timer = Timer(widget.record.duration, dismiss);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _jelly.value = 1;
    }
  }

  Future<void> dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _timer?.cancel();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!disableAnimations) await _jelly.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _jelly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(widget.record.type);
    final icon = _icon(widget.record.type);

    return AnimatedBuilder(
      animation: _jelly,
      builder: (context, child) {
        final t = _jelly.value;
        final closing = _jelly.status == AnimationStatus.reverse;

        final double scaleX;
        final double scaleY;
        final double opacity;

        if (closing) {
          final eased = Curves.easeOutCubic.transform(t);
          scaleX = 0.94 + (0.06 * eased);
          scaleY = 0.96 + (0.04 * eased);
          opacity = t;
        } else {
          final spring = const _NotificationJellySpringCurve().transform(t);
          final wobble = math.sin(t * math.pi * 3) * math.exp(-5.8 * t) * 0.032;
          final baseScale = 0.84 + (0.16 * spring);
          scaleX = baseScale + wobble;
          scaleY = baseScale - wobble;
          opacity = const Interval(0, 0.22, curve: Curves.easeOut).transform(t);
        }

        return Opacity(
          opacity: opacity.clamp(0, 1),
          child: Transform(
            key: const Key('app-notification-jelly-transform'),
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: ValueKey(widget.record),
        direction: DismissDirection.horizontal,
        resizeDuration: appNotificationExitDuration,
        onDismissed: (_) {
          _dismissing = true;
          _timer?.cancel();
          widget.onDismissed();
        },
        child: Semantics(
          container: true,
          liveRegion: true,
          label: [
            if (widget.record.title != null) widget.record.title,
            widget.record.message,
          ].join(', '),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.large),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.large),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Stack(
                  children: [
                    DecoratedBox(
                      key: const Key('app-notification-surface'),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(242, 255, 255, 255),
                        borderRadius: BorderRadius.circular(AppRadius.large),
                        border: Border.all(color: appNotificationBorderColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Container(
                                key: const Key('app-notification-leading'),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  icon,
                                  color: accent.withValues(
                                    alpha: appNotificationIconOpacity,
                                  ),
                                  size: 20,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.record.title
                                      case final title?) ...[
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    widget.record.message,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.record.actionLabel case final label?)
                              TextButton(
                                onPressed: () {
                                  widget.record.onAction?.call();
                                  dismiss();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: accent,
                                ),
                                child: Text(label),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          key: const Key('app-notification-noise'),
                          opacity: appNotificationNoiseOpacity,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Image(
                                image: ResizeImage(
                                  const AssetImage(_appNotificationNoiseAsset),
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
          ),
        ),
      ),
    );
  }
}

class _NotificationJellySpringCurve extends Curve {
  const _NotificationJellySpringCurve();

  @override
  double transformInternal(double t) {
    if (t == 0 || t == 1) return t;
    return 1 - (math.exp(-7.5 * t) * math.cos(12 * t));
  }
}

Color _accentColor(AppNotificationType type) => switch (type) {
  AppNotificationType.info => AppColors.primary,
  AppNotificationType.success => AppColors.success,
  AppNotificationType.warning => AppColors.warning,
  AppNotificationType.error => AppColors.danger,
};

IconData _icon(AppNotificationType type) => switch (type) {
  AppNotificationType.info => Icons.info_outline_rounded,
  AppNotificationType.success => Icons.check_rounded,
  AppNotificationType.warning => Icons.warning_amber_rounded,
  AppNotificationType.error => Icons.error_outline_rounded,
};
