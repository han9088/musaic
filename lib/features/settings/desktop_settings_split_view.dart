part of 'settings_sheet.dart';

class _DesktopSettingsSplitView extends StatefulWidget {
  const _DesktopSettingsSplitView({required this.sheet});

  final SettingsSheet sheet;

  @override
  State<_DesktopSettingsSplitView> createState() =>
      _DesktopSettingsSplitViewState();
}

class _DesktopSettingsSplitViewState extends State<_DesktopSettingsSplitView>
    with AutomaticKeepAliveClientMixin<_DesktopSettingsSplitView> {
  static const _rowInset = 8.0;
  static const _tileInset = 10.0;
  static const _iconInset = _rowInset + _tileInset;
  static const _iconSize = 18.0;

  final _details = GlobalKey<NavigatorState>();
  ({SettingsSection section, PageRoute<void> route})? _selection;
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selectSection(SettingsSection.system);
    });
  }

  void _selectSection(SettingsSection section) {
    final selection = _selection;
    if (selection != null &&
        selection.section == section &&
        selection.route.isCurrent) {
      return;
    }
    final navigator = _details.currentState!;
    navigator.popUntil((route) => route.isFirst);
    final route = widget.sheet.onOpenSection(navigator.context, section);
    if (route == null) return;
    setState(() => _selection = (section: section, route: route));
    unawaited(
      route.popped.then((_) {
        if (mounted && identical(_selection?.route, route)) {
          _selectSection(SettingsSection.system);
        }
      }),
    );
  }

  Widget _sidebarItem(
    IconData icon,
    String title, {
    bool selected = false,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: _rowInset),
    child: ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: _tileInset),
      horizontalTitleGap: 10,
      minLeadingWidth: _iconSize,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Icon(
        icon,
        size: _iconSize,
        color: selected ? AppColors.settingsAccent : null,
      ),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      selected: selected,
      selectedTileColor: AppColors.sheetHostBackground,
      onTap: onTap,
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final sheet = widget.sheet;
    final sidebar = _selection?.section;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          SizedBox(
            width: (constraints.maxWidth * 0.32).clamp(150, 214).toDouble(),
            child: SettingsInteractionTheme(
              child: ListView(
                key: const ValueKey('desktop-settings-sidebar'),
                primary: false,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: sheet._settingsItems(
                  l10n,
                  sidebarInset: _iconInset,
                  buildSection: (icon, title, section) => _sidebarItem(
                    icon,
                    title,
                    selected: sidebar == section,
                    onTap: () => _selectSection(section),
                  ),
                  support: SettingsSupportSection(
                    headingInset: _iconInset,
                    buildAction: (icon, title, onTap) =>
                        _sidebarItem(icon, title, onTap: onTap),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.sheetHostBackground),
          Expanded(
            child: HeroControllerScope.none(
              child: Navigator(
                key: _details,
                pages: const [MaterialPage<void>(child: SizedBox.shrink())],
                onDidRemovePage: (_) {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
