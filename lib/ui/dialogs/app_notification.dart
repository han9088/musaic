import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

part 'app_notification_overlay.dart';

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

