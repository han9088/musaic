// 文件职责：页面状态组织与业务流程协调。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../features/desktop_shortcuts/desktop_shortcuts.dart';
import '../../features/desktop_shortcuts/desktop_shortcuts_settings.dart';
import '../../features/music/playback/album_playback.dart';
import '../../features/music/playback/now_playing_controls.dart';
import '../../features/music/playback/playback_gesture_intro.dart';
import '../../features/music/account/audius_account_tab.dart';
import '../../features/music/presentation/music_settings.dart';
import '../../features/artwork/presentation/album_color_family.dart';
import '../../features/artwork/presentation/album_color_organization_settings.dart';
import '../../features/music/presentation/music_source_picker.dart';
import '../../features/pro/pro_settings.dart';
import '../../features/settings/about_settings.dart';
import '../../features/settings/appearance_settings.dart';
import '../../features/settings/developer_options_settings.dart';
import '../../features/settings/desktop_settings_window.dart';
import '../../features/settings/diagnostics_settings.dart';
import '../../features/settings/settings_sheet.dart';
import '../../features/settings/usage_guide_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_icon_service.dart';
import '../../services/app_updates.dart';
import '../../services/music/apple_music_provider.dart';
import '../../services/music/audius_music_provider.dart';
import '../../services/music/music_source_controller.dart';
import '../../storage/settings/app_language_preference.dart';
import '../../storage/settings/developer_options_preference.dart';
import '../../storage/settings/manual_rotation_preference.dart';
import '../../storage/settings/screensaver_delay_preference.dart';
import '../../storage/settings/usage_guide_preference.dart';
import '../../ui/bottom_sheet/bottom_sheet.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../settings/settings_page.dart';

/// 封装或定义首页弹层相关类型与行为，负责页面状态组织与业务流程协调。
class HomeSheet extends StatefulWidget {
  const HomeSheet({
    super.key,
    required this.child,
    this.settingsWindow,
    this.icons = const AppIconService(),
    this.enabled = true,
    this.playbackReady = true,
    this.sources,
    this.playback,
    this.desktopShortcuts,
    this.onKeyboardShortcutsOpened,
    this.layoutSwitch,
    this.sourceSwitching,
    this.onSourceSelection,
    this.language,
    this.manualRotation,
    this.screensaverDelay,
    this.xeroxEnabled,
    this.onXeroxChanged,
    this.xeroxPalettePicker,
    this.colorIndex,
    this.colorOrganizeEnabled,
    this.selectedColorFamily,
    this.onColorOrganizeChanged,
    this.onColorFamilySelected,
    this.checkLatestRelease = latestMusaicRelease,
  });

  final Widget child;
  final DesktopSettingsWindow? settingsWindow;
  final AppIconService icons;
  final bool enabled;
  final bool playbackReady;
  final MusicSourceController? sources;
  final AlbumPlayback? playback;
  final DesktopShortcuts? desktopShortcuts;
  final ValueChanged<PageRoute<void>>? onKeyboardShortcutsOpened;
  final ({Widget button, bool visible})? layoutSwitch;
  final ValueListenable<bool>? sourceSwitching;
  final Future<void> Function(Future<void> Function())? onSourceSelection;
  final AppLanguagePreference? language;
  final ManualRotationPreference? manualRotation;
  final ScreensaverDelayPreference? screensaverDelay;
  final ValueListenable<bool>? xeroxEnabled;
  final FutureOr<void> Function(bool enabled)? onXeroxChanged;
  final Widget? xeroxPalettePicker;
  final AlbumColorFamilyIndex? colorIndex;
  final ValueListenable<bool>? colorOrganizeEnabled;
  final ValueListenable<AlbumColorFamily?>? selectedColorFamily;
  final ValueChanged<bool>? onColorOrganizeChanged;
  final ValueChanged<AlbumColorFamily?>? onColorFamilySelected;
  final Future<Version?> Function() checkLatestRelease;

  @override
  State<HomeSheet> createState() => _HomeSheetState();
}

/// 封装或定义首页弹层状态相关类型与行为，负责页面状态组织与业务流程协调。
class _HomeSheetState extends State<HomeSheet> {
  static const _firstSheetDetent = BottomSheetDetentFraction(0.38);

  final _usageGuide = UsageGuidePreference();
  final _developerOptions = DeveloperOptionsPreference();
  String? _sheetId;
  bool _sheetExpanded = false;
  bool _xeroxChangePending = false;
  bool _sourceSelectionPending = false;
  Completer<bool>? _xeroxSheetCollapse;
  Completer<void>? _sourceSheetDismissed;
  Timer? _hideTimer;
  bool _visible = true;

  bool get _open => _sheetId != null;
  bool get _playbackAvailable => widget.enabled && widget.playbackReady;

  @override
  void initState() {
    super.initState();
    widget.settingsWindow?.content = _buildDesktopSettings;
    unawaited(_usageGuide.restore());
    unawaited(_developerOptions.restore());
  }

  void _reveal() {
    if (!_playbackAvailable || _open) return;
    if (!_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  /// 准备并调度后续任务，用于页面状态组织与业务流程协调。
  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_playbackAvailable ||
        _open ||
        MediaQuery.accessibleNavigationOf(context)) {
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 4500), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.accessibleNavigationOf(context)) _visible = true;
    _scheduleHide();
  }

  @override
  void didUpdateWidget(HomeSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settingsWindow != widget.settingsWindow) {
      oldWidget.settingsWindow?.content = null;
      widget.settingsWindow?.content = _buildDesktopSettings;
    }
    final wasPlaybackAvailable = oldWidget.enabled && oldWidget.playbackReady;
    if (wasPlaybackAvailable != _playbackAvailable) {
      _visible = _playbackAvailable && oldWidget.enabled;
      _scheduleHide();
      if (_playbackAvailable && !oldWidget.enabled) {
        // Mount the surface at zero opacity before fading it back in.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _reveal();
        });
      }
    }
    if (oldWidget.enabled && !widget.enabled && _open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.enabled && _open) {
          DeskBottomSheet.of(context).dismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.settingsWindow?.content = null;
    _hideTimer?.cancel();
    _usageGuide.dispose();
    _developerOptions.dispose();
    _finishXeroxCollapse(false);
    final dismissed = _sourceSheetDismissed;
    if (dismissed != null && !dismissed.isCompleted) dismissed.complete();
    super.dispose();
  }

  Widget _buildDesktopSettings(BuildContext context) => Scaffold(
    backgroundColor: AppColors.sheetBackground,
    body: _buildSettingsSheet(desktop: true),
  );

  Widget _buildSettingsSheet({bool desktop = false}) => SignalBuilder(
    builder: (context) {
      final sources = widget.sources;
      final musicAccount = switch (sources?.selectedProviderId) {
        AudiusMusicProvider.providerId => (
          icon: Image.asset(
            'assets/branding/audius_glyph_color.png',
            width: 22,
            height: 22,
            semanticLabel: 'Audius',
          ),
          page: AudiusAccountTab(sources: sources!, playback: widget.playback),
        ),
        AppleMusicProvider.providerId => (
          icon: const Icon(
            PhosphorIcons.appleLogoFill,
            size: 22,
            semanticLabel: 'Apple Music',
          ),
          page: ListTile(
            title: Text(
              AppLocalizations.of(context).appleMusicAccountUnavailable,
            ),
          ),
        ),
        _ => null,
      };
      return SettingsSheet(
        desktop: desktop,
        musicAccount: musicAccount,
        musicSourceVisible: widget.sources != null,
        onOpenSection: (source, section) =>
            _openSettings(source, section, desktop: desktop),
        language: widget.language,
        usageGuideVisible: _usageGuide.visible,
        developerOptionsEnabled: _developerOptions.enabled,
        keyboardShortcutsVisible: widget.desktopShortcuts != null,
        xeroxEnabled: widget.xeroxEnabled,
        onXeroxChanged: widget.onXeroxChanged == null
            ? null
            : (enabled) => _changeXerox(enabled, desktop: desktop),
        xeroxPalettePicker: widget.xeroxPalettePicker,
      );
    },
  );

  void _present() {
    if (_open || !_playbackAvailable || _xeroxChangePending) return;
    final host = DeskBottomSheet.of(context);
    if (host.isPresented) return;
    _hideTimer?.cancel();
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final sheetId = host.present(
      _buildSettingsSheet(),
      BottomSheetOptions(
        mode: BottomSheetMode.push,
        pushDirection: PushDirection.bottom,
        snapPoints: [
          _firstSheetDetent,
          BottomSheetDetent.fraction(landscape ? 0.76 : 0.78),
        ],
        index: 0,
        enableDynamicSizing: false,
        enablePanDownToClose: true,
        dismissOnScrimPress: true,
        enableContentPanningGesture: true,
        showHandle: true,
        onAnimate: (_, index) {
          if (index > 0) _sheetExpanded = true;
        },
        onChange: (index) {
          _sheetExpanded = index > 0;
          _finishXeroxCollapse(index == 0);
        },
        onDismiss: () {
          _sheetExpanded = false;
          _finishXeroxCollapse(false);
          final dismissed = _sourceSheetDismissed;
          if (dismissed != null && !dismissed.isCompleted) {
            dismissed.complete();
          }
          if (mounted) {
            setState(() => _sheetId = null);
            _reveal();
          }
        },
      ),
    );
    setState(() => _sheetId = sheetId);
  }

  PageRoute<void>? _openSettings(
    BuildContext source,
    SettingsSection section, {
    required bool desktop,
  }) {
    if (!desktop &&
        (!_open || _sourceSelectionPending || _xeroxChangePending)) {
      return null;
    }
    final navigator = Navigator.of(source, rootNavigator: !desktop);
    late final PageRoute<void> route;
    final (path, title, body) = switch (section) {
      SettingsSection.pro => (
        '/settings/pro',
        (AppLocalizations l10n) => l10n.settingsPro,
        const ProSettings(),
      ),
      SettingsSection.musicSource => (
        '/settings/music-source',
        (AppLocalizations l10n) => l10n.musicSource,
        MusicSourcePicker(
          sources: widget.sources!,
          sourceSwitching: widget.sourceSwitching,
          onSourceSelection: desktop
              ? _selectSource
              : (select) async {
                  if (!route.isCurrent) return;
                  navigator.pop();
                  await route.completed;
                  if (mounted) await _selectSource(select);
                },
        ),
      ),
      SettingsSection.music => (
        '/settings/music',
        (AppLocalizations l10n) => l10n.settingsMusic,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.screensaverDelay case final delay?)
              MusicSettings(screensaverDelay: delay),
            if ((
                  widget.colorIndex,
                  widget.colorOrganizeEnabled,
                  widget.onColorOrganizeChanged,
                )
                case (final index?, final enabled?, final onChanged?))
              AlbumColorOrganizationSettings(
                index: index,
                enabled: enabled,
                onChanged: onChanged,
                selectedFamily: widget.selectedColorFamily,
                onFamilySelected: widget.onColorFamilySelected,
              ),
          ],
        ),
      ),
      SettingsSection.system => (
        '/settings/system',
        (AppLocalizations l10n) => l10n.settingsSystem,
        AppearanceSettings(
          icons: widget.icons,
          manualRotation: widget.manualRotation,
        ),
      ),
      SettingsSection.keyboardShortcuts => (
        '/settings/keyboard-shortcuts',
        (AppLocalizations l10n) => l10n.settingsKeyboardShortcuts,
        DesktopShortcutsSettings(shortcuts: widget.desktopShortcuts!),
      ),
      SettingsSection.usageGuide => (
        '/settings/usage-guide',
        (AppLocalizations l10n) => l10n.settingsUsageGuide,
        const UsageGuideSettings(),
      ),
      SettingsSection.diagnostics => (
        '/settings/diagnostics',
        (AppLocalizations l10n) => l10n.settingsDiagnostics,
        const DiagnosticsSettings(),
      ),
      SettingsSection.about => (
        '/settings/about',
        (AppLocalizations l10n) => l10n.settingsAbout,
        AboutSettings(
          checkLatestRelease: widget.checkLatestRelease,
          onOpenDetail: (source, title, body) =>
              pushSettingsDetail(source, title, body, desktop: desktop),
          onOpenDeveloperOptions: (source) =>
              _openDeveloperOptions(source, desktop: desktop),
        ),
      ),
      SettingsSection.developerOptions => (
        '/settings/developer-options',
        (AppLocalizations l10n) => l10n.settingsDeveloperOptions,
        const DeveloperOptionsSettings(),
      ),
    };
    route = pushSettingsPage(
      source: source,
      navigator: navigator,
      path: path,
      title: title,
      body: body,
      desktop: desktop,
      bodyIsSliver: section == SettingsSection.diagnostics,
      footer: section == SettingsSection.about
          ? const AboutCopyrightFooter()
          : null,
      fixedFooter: section == SettingsSection.usageGuide
          ? UsageGuideDismissFooter(
              onDismiss: () async {
                if (!route.isCurrent) return;
                await _usageGuide.hide();
                if (route.isCurrent) navigator.pop();
              },
            )
          : null,
    );
    if (!desktop && section == SettingsSection.keyboardShortcuts) {
      widget.onKeyboardShortcutsOpened?.call(route);
    }
    return route;
  }

  void _openDeveloperOptions(BuildContext source, {required bool desktop}) {
    if (ModalRoute.isCurrentOf(source) == false) return;
    unawaited(_developerOptions.enable());
    pushSettingsDetail(
      source,
      AppLocalizations.of(source).settingsDeveloperOptions,
      const DeveloperOptionsSettings(),
      desktop: desktop,
    );
  }

  void _finishXeroxCollapse(bool settled) {
    final collapse = _xeroxSheetCollapse;
    _xeroxSheetCollapse = null;
    collapse?.complete(settled);
  }

  Future<void> _changeXerox(bool enabled, {required bool desktop}) async {
    final onChanged = widget.onXeroxChanged;
    if ((!desktop && !_open) ||
        _xeroxChangePending ||
        _sourceSelectionPending ||
        onChanged == null) {
      return;
    }
    _xeroxChangePending = true;
    try {
      if (desktop) {
        await onChanged(enabled);
        return;
      }
      final sheet = DeskBottomSheet.of(context);
      final controller = sheet.topSheetController;
      if (_sheetExpanded &&
          sheet.topSheetId == _sheetId &&
          controller != null) {
        final collapse = _xeroxSheetCollapse = Completer<bool>();
        controller.collapse();
        if (!await collapse.future) return;
      } else if (!enabled) {
        await sheet.dismissAll();
      }
      if (mounted) await onChanged(enabled);
    } finally {
      _xeroxChangePending = false;
    }
  }

  Future<void> _selectSource(Future<void> Function() select) async {
    if (_sourceSelectionPending || _xeroxChangePending) return;
    _sourceSelectionPending = true;
    try {
      if (_open) {
        final dismissed = Completer<void>();
        _sourceSheetDismissed = dismissed;
        DeskBottomSheet.of(context).dismiss();
        await dismissed.future;
        _sourceSheetDismissed = null;
      }
      if (!mounted) return;
      final onSourceSelection = widget.onSourceSelection;
      if (onSourceSelection == null) {
        await select();
      } else {
        await onSourceSelection(select);
      }
    } finally {
      _sourceSheetDismissed = null;
      _sourceSelectionPending = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.playback == null || widget.settingsWindow != null
      ? _buildHome(context, null)
      : PlaybackGestureIntro(
          enabled: _playbackAvailable && !_open,
          sheetDetent: _firstSheetDetent,
          buildSheet: _buildSettingsSheet,
          builder: _buildHome,
        );

  Widget _buildHome(
    BuildContext context,
    Animation<PlaybackPullPreview>? pullPreview,
  ) {
    final layoutSwitch = _open ? null : widget.layoutSwitch;
    final capsuleVisible =
        _playbackAvailable && !_open && (_visible || pullPreview != null);
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_open || _sourceSelectionPending) return;
        DeskBottomSheet.of(context).dismiss();
      },
      child: MouseRegion(
        onHover: (_) => _reveal(),
        child: Listener(
          onPointerDown: (_) {
            _reveal();
            _hideTimer?.cancel();
          },
          onPointerUp: (_) => _scheduleHide(),
          onPointerCancel: (_) => _scheduleHide(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (widget.enabled)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: AppSpacing.playbackBottom,
                  child: Center(
                    child: NowPlayingControls(
                      playback: widget.playback,
                      pullPreview: pullPreview,
                      visible: capsuleVisible,
                      onOpenSheet: widget.settingsWindow == null
                          ? _present
                          : null,
                      companion: layoutSwitch?.button,
                      companionVisible: layoutSwitch?.visible ?? false,
                    ),
                  ),
                ),
              if (!widget.enabled && layoutSwitch != null)
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: SafeArea(child: layoutSwitch.button),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
