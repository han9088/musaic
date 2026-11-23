import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../storage/music/custom_artwork_store.dart';
import '../../../ui/dialogs/app_alert_dialog.dart';
import '../../../ui/dialogs/app_jelly_transition.dart';
import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_radius.dart';
import '../model/artwork_identity.dart';
import 'custom_artwork_scope.dart';

bool _editingCover = false;
final _menuVisible = ValueNotifier(false);
ValueListenable<bool> get customArtworkMenuVisible => _menuVisible;

enum _CoverAction { chooseImage, restore }

GestureLongPressStartCallback? customArtworkMenuAction(
  BuildContext context,
  String asset,
  ArtworkIdentity? identity,
) {
  final store = CustomArtworkScope.read(context);
  if (store == null) return null;
  return (details) => _showMenu(
    context,
    details.globalPosition,
    store,
    identity?.value ?? asset,
  );
}

Future<void> _showMenu(
  BuildContext context,
  Offset position,
  CustomArtworkStore store,
  String key,
) async {
  if (_editingCover) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final hasCustomCover = store.revisionOf(key) != null;
  _CoverAction? action;
  _editingCover = true;
  try {
    _menuVisible.value = true;
    action = await showAppDialog<_CoverAction>(
      context: context,
      waitForDismissal: true,
      layoutBuilder: (context, animation, child) {
        const margin = 12.0;
        final padding = MediaQuery.paddingOf(context);
        return SafeArea(
          minimum: const EdgeInsets.all(margin),
          child: CustomSingleChildLayout(
            delegate: _MenuPosition(
              position -
                  Offset(
                    math.max(margin, padding.left),
                    math.max(margin, padding.top),
                  ),
            ),
            child: AppJellyTransition(
              animation: animation,
              alignment: Alignment.topCenter,
              openingOffset: const Offset(0, -12),
              child: child,
            ),
          ),
        );
      },
      builder: (context) => AppDialogSurface(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.medium)),
        child: Material(
          type: MaterialType.transparency,
          child: ListTileTheme(
            iconColor: AppColors.dialogForeground,
            textColor: AppColors.dialogForeground,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(PhosphorIcons.image),
                  title: Text(
                    hasCustomCover
                        ? l10n.artworkChangeCover
                        : l10n.artworkAddCover,
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_CoverAction.chooseImage),
                ),
                if (hasCustomCover)
                  ListTile(
                    leading: const Icon(PhosphorIcons.arrowCounterClockwise),
                    title: Text(l10n.artworkRestoreCover),
                    onTap: () =>
                        Navigator.of(context).pop(_CoverAction.restore),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    _menuVisible.value = false;
    if (action == null) return;
    if (action == _CoverAction.restore) {
      await store.restore(key);
      return;
    }

    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    await store.save(key, await _coverBytes(file));
  } catch (_) {
    if (messenger?.mounted == true) {
      final message = action == _CoverAction.restore
          ? l10n.artworkRestoreFailed
          : l10n.artworkSaveFailed;
      messenger!.showSnackBar(SnackBar(content: Text(message)));
    }
  } finally {
    _menuVisible.value = false;
    _editingCover = false;
  }
}

Future<Uint8List> _coverBytes(PlatformFile file) async {
  const maxInputBytes = 64 * 1024 * 1024;
  final length = await file.length();
  if (length == null || length == 0 || length > maxInputBytes) {
    throw const FormatException('Unsupported cover file size');
  }

  // Keep the saved PNG below Android's SQLite cursor window limit.
  const maxEdge = 640;
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await file.readAsBytes(),
  );
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final landscape = descriptor.width >= descriptor.height;
    codec = await descriptor.instantiateCodec(
      targetWidth: landscape ? math.min(maxEdge, descriptor.width) : null,
      targetHeight: landscape ? null : math.min(maxEdge, descriptor.height),
    );
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw const FormatException('Invalid cover image');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

class _MenuPosition extends SingleChildLayoutDelegate {
  const _MenuPosition(this.position);

  final Offset position;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().tighten(width: math.min(220, constraints.maxWidth));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = position.dx - childSize.width / 2;
    final below = position.dy + 12;
    return Offset(
      x.clamp(0, size.width - childSize.width),
      (below + childSize.height <= size.height
              ? below
              : position.dy - childSize.height - 12)
          .clamp(0, size.height - childSize.height),
    );
  }

  @override
  bool shouldRelayout(_MenuPosition oldDelegate) =>
      position != oldDelegate.position;
}
