import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/coverflow_photo_library.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/glass_icon_button.dart';

class CoverFlowPhotoViewer extends StatefulWidget {
  const CoverFlowPhotoViewer({
    super.key,
    required this.image,
    required this.assetId,
  });

  final ui.Image image;
  final String assetId;

  @override
  State<CoverFlowPhotoViewer> createState() => _CoverFlowPhotoViewerState();
}

class _CoverFlowPhotoViewerState extends State<CoverFlowPhotoViewer> {
  bool _deleting = false;

  Future<void> _deletePhoto() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      final deleted = await deleteCoverFlowPhoto(widget.assetId);
      if (mounted && deleted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).coverFlowPhotoDeleteFailed,
            ),
          ),
        );
      }
      debugPrint('Cover Flow photo deletion: $error');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_deleting,
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RawImage(image: widget.image, fit: BoxFit.contain),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassIconButton(
                    icon: PhosphorIcons.arrowLeft,
                    iconSize: appNavigationBackIconSize,
                    label: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () {
                      if (!_deleting) Navigator.pop(context);
                    },
                  ),
                  GlassIconButton(
                    icon: PhosphorIcons.trash,
                    label: AppLocalizations.of(context).coverFlowPhotoDelete,
                    onPressed: _deletePhoto,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
