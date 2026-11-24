import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/dialogs/app_alert_dialog.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/settings_section_heading.dart';
import 'desktop_shortcuts.dart';

class DesktopShortcutsSettings extends StatefulWidget {
  const DesktopShortcutsSettings({super.key, required this.shortcuts});

  final DesktopShortcuts shortcuts;

  @override
  State<DesktopShortcutsSettings> createState() =>
      _DesktopShortcutsSettingsState();
}

class _DesktopShortcutsSettingsState extends State<DesktopShortcutsSettings> {
  Future<void> _edit(DesktopShortcut action, String title) async {
    await showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ShortcutDialog(
        shortcuts: widget.shortcuts,
        action: action,
        title: title,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shortcuts = widget.shortcuts;
    return FutureBuilder<void>(
      future: shortcuts.ready,
      builder: (context, snapshot) {
        final loaded = snapshot.connectionState == ConnectionState.done;
        Widget row(DesktopShortcut action, String title) => ListTile(
          title: Text(title),
          subtitle: loaded && !shortcuts.isRegistered(action)
              ? Text(l10n.desktopShortcutUnavailable)
              : null,
          trailing: Text(
            desktopShortcutLabel(shortcuts.binding(action)),
            style: const TextStyle(color: Colors.white70),
          ),
          onTap: loaded ? () => _edit(action, title) : null,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsSectionHeading(l10n.desktopShortcutsPlayback),
            row(DesktopShortcut.playPause, l10n.desktopShortcutPlayPause),
            row(DesktopShortcut.seekBackward, l10n.musicRewind),
            row(DesktopShortcut.seekForward, l10n.musicFastForward),
            row(DesktopShortcut.previousTrack, l10n.musicPreviousTrack),
            row(DesktopShortcut.nextTrack, l10n.musicNextTrack),
            SettingsSectionHeading(l10n.desktopShortcutsWindow),
            row(DesktopShortcut.restoreWindow, l10n.desktopWallpaperRestore),
            row(DesktopShortcut.embedWindow, l10n.desktopWallpaperSet),
            if (loaded && shortcuts.isRegistered(DesktopShortcut.restoreWindow))
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  settingsContentInset,
                  12,
                  settingsContentInset,
                  16,
                ),
                child: Text(
                  defaultTargetPlatform == TargetPlatform.macOS
                      ? l10n.desktopShortcutsCloseMac
                      : l10n.desktopShortcutsCloseWindows,
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ShortcutDialog extends StatefulWidget {
  const _ShortcutDialog({
    required this.shortcuts,
    required this.action,
    required this.title,
  });

  final DesktopShortcuts shortcuts;
  final DesktopShortcut action;
  final String title;

  @override
  State<_ShortcutDialog> createState() => _ShortcutDialogState();
}

class _ShortcutDialogState extends State<_ShortcutDialog> {
  late final VoidCallback _stopCapture;
  HotKey? _candidate;
  ShortcutChange? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stopCapture = widget.shortcuts.capture(_record);
  }

  void _record(HotKey candidate) {
    if (_saving) return;
    setState(() {
      _candidate = candidate;
      _error = null;
    });
  }

  KeyEventResult _recordKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.synthesized) {
      return KeyEventResult.ignored;
    }
    final modifiers = [
      for (final modifier in const [
        HotKeyModifier.control,
        HotKeyModifier.alt,
        HotKeyModifier.shift,
        HotKeyModifier.meta,
      ])
        if (modifier.isModifierPressed) modifier,
    ];
    if (modifiers.every((modifier) => modifier == HotKeyModifier.shift) ||
        HotKeyModifier.values.any(
          (modifier) => modifier.physicalKeys.contains(event.physicalKey),
        )) {
      return KeyEventResult.ignored;
    }
    _record(widget.action.binding(event.physicalKey, modifiers));
    return KeyEventResult.handled;
  }

  Future<void> _save(HotKey? candidate) async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await widget.shortcuts.change(widget.action, candidate);
    if (!mounted) return;
    if (result == ShortcutChange.saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = result;
      });
    }
  }

  @override
  void dispose() {
    _stopCapture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = switch (_error) {
      ShortcutChange.duplicate => l10n.desktopShortcutDuplicate,
      ShortcutChange.unavailable => l10n.desktopShortcutUnavailable,
      ShortcutChange.saveFailed => l10n.desktopShortcutSaveFailed,
      _ => null,
    };
    return PopScope(
      canPop: !_saving,
      child: Focus(
        autofocus: true,
        onKeyEvent: _recordKey,
        child: AppAlertDialog(
          title: Text(widget.title),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.desktopShortcutRecord),
              const SizedBox(height: 12),
              Text(
                desktopShortcutLabel(
                  _candidate ?? widget.shortcuts.binding(widget.action),
                ),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (error != null) ...[const SizedBox(height: 8), Text(error)],
            ],
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => _save(null),
              child: Text(l10n.desktopShortcutUseDefault),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            TextButton(
              onPressed: _saving || _candidate == null
                  ? null
                  : () => _save(_candidate),
              child: Text(l10n.desktopShortcutSave),
            ),
          ],
        ),
      ),
    );
  }
}
