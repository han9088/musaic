// 文件职责：对话框、通知及其转场和展示管理。

part of 'app_notification.dart';

/// 封装或定义应用通知覆层相关类型与行为，负责对话框、通知及其转场和展示管理。
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

/// 封装或定义应用通知stackitem相关类型与行为，负责对话框、通知及其转场和展示管理。
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

/// 封装或定义应用通知card相关类型与行为，负责对话框、通知及其转场和展示管理。
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

/// 封装或定义应用通知card状态相关类型与行为，负责对话框、通知及其转场和展示管理。
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

  /// 执行当前模块中的dismiss操作，用于对话框、通知及其转场和展示管理。
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
                  color: AppColors.dialogShadow,
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
                        color: AppColors.dialogSurface,
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
                                            color: AppColors.dialogForeground,
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
                                        ?.copyWith(
                                          color: AppColors.dialogForeground,
                                        ),
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

/// 封装或定义通知果冻弹簧curve相关类型与行为，负责对话框、通知及其转场和展示管理。
class _NotificationJellySpringCurve extends Curve {
  const _NotificationJellySpringCurve();

  @override
  double transformInternal(double t) {
    if (t == 0 || t == 1) return t;
    return 1 - (math.exp(-7.5 * t) * math.cos(12 * t));
  }
}

Color _accentColor(AppNotificationType type) => switch (type) {
  AppNotificationType.info => AppColors.dialogForeground,
  AppNotificationType.success => AppColors.notificationSuccess,
  AppNotificationType.warning => AppColors.notificationWarning,
  AppNotificationType.error => AppColors.notificationError,
};

IconData _icon(AppNotificationType type) => switch (type) {
  AppNotificationType.info => Icons.info_outline_rounded,
  AppNotificationType.success => Icons.check_rounded,
  AppNotificationType.warning => Icons.warning_amber_rounded,
  AppNotificationType.error => Icons.error_outline_rounded,
};
