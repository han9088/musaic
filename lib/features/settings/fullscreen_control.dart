import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/browser/fullscreen.dart';

class FullscreenControl extends StatefulWidget {
  const FullscreenControl({super.key});

  @override
  State<FullscreenControl> createState() => _FullscreenControlState();
}

class _FullscreenControlState extends State<FullscreenControl> {
  final _fullscreen = BrowserFullscreen();
  bool _pending = false;
  bool _failed = false;

  Future<void> _toggle() async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _failed = false;
    });
    try {
      await _fullscreen.toggle();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  void dispose() {
    _fullscreen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_fullscreen.supported) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: ListenableBuilder(
        listenable: _fullscreen,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton.icon(
              onPressed: _pending ? null : _toggle,
              icon: Icon(
                _fullscreen.active
                    ? PhosphorIcons.arrowsIn
                    : PhosphorIcons.arrowsOut,
              ),
              label: Text(
                _fullscreen.active ? l10n.exitFullscreen : l10n.enterFullscreen,
              ),
            ),
            if (_failed) Text(l10n.fullscreenFailed),
          ],
        ),
      ),
    );
  }
}
