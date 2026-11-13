import 'package:material_ui/material_ui.dart';

import '../engine/bottom_sheet_engine.dart';
import '../types.dart';
import 'bottom_sheet_backdrop.dart';
import 'bottom_sheet_overlay.dart';

class BottomSheetOverlayHost extends StatelessWidget {
  const BottomSheetOverlayHost({
    super.key,
    required this.engine,
    required this.topInset,
    required this.bottomInset,
  });

  final BottomSheetEngine engine;
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        // No overlay layer when idle — keeps host fully interactive/visible.
        if (engine.sheets.isEmpty) return const SizedBox.shrink();

        // Nested Navigator so sheet content can showDialog above the sheet
        // (the app root Navigator sits under this overlay layer).
        return _SheetLocalOverlay(
          engine: engine,
          topInset: topInset,
          bottomInset: bottomInset,
        );
      },
    );
  }
}

class _SheetStack extends StatelessWidget {
  const _SheetStack({
    required this.engine,
    required this.topInset,
    required this.bottomInset,
  });

  final BottomSheetEngine engine;
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final sheets = engine.sheets;
        if (sheets.isEmpty) return const SizedBox.shrink();

        final top = sheets.last;
        final showModalDim = top.options.mode == BottomSheetMode.modal;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (showModalDim)
              BottomSheetBackdrop(
                color: top.options.theme.modalBackdropColor,
                opacity: 1,
                solid: true,
                onTap: top.options.dismissOnScrimPress
                    ? engine.dismissTop
                    : null,
              ),
            for (var i = 0; i < sheets.length; i++) _buildStackItem(sheets, i),
          ],
        );
      },
    );
  }

  Widget _buildStackItem(List<BottomSheetState> sheets, int index) {
    final sheet = sheets[index];
    final stackSize = sheets.length;
    final depthFromTop = stackSize - 1 - index;
    final isTop = index == stackSize - 1;
    final drivesHost = index == 0;
    final enableStackCard =
        sheet.options.mode == BottomSheetMode.presentation &&
        engine.hostMode == BottomSheetMode.presentation &&
        depthFromTop > 0;

    return Positioned.fill(
      child: BottomSheetOverlay(
        key: ValueKey(sheet.id),
        sheet: sheet,
        progress: drivesHost ? engine.bottomProgress : null,
        hostSheetTopY: drivesHost ? engine.hostSheetTopY : null,
        pushProgressOpenY: drivesHost ? engine.pushProgressOpenY : null,
        pushSheetHeight: drivesHost ? engine.pushSheetHeight : null,
        layout: engine.mergedLayout,
        screenHeight: engine.screenHeight,
        screenWidth: engine.screenWidth,
        topInset: topInset,
        bottomInset: bottomInset,
        stackIndex: index,
        depthFromTop: depthFromTop,
        enableStackCardStyle: enableStackCard,
        isTop: isTop,
        onDismissComplete: () => engine.handleDismissComplete(sheet.id),
        onDismissHandlerChange: (handler) =>
            engine.handleDismissHandlerChange(sheet.id, handler),
        onControllerReady: (api) => engine.handleControllerReady(sheet.id, api),
      ),
    );
  }
}

/// Overlay + Navigator for sheet content rendered above the app Navigator.
class _SheetLocalOverlay extends StatefulWidget {
  const _SheetLocalOverlay({
    required this.engine,
    required this.topInset,
    required this.bottomInset,
  });

  final BottomSheetEngine engine;
  final double topInset;
  final double bottomInset;

  @override
  State<_SheetLocalOverlay> createState() => _SheetLocalOverlayState();
}

class _SheetLocalOverlayState extends State<_SheetLocalOverlay> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final OverlayEntry _entry = OverlayEntry(
    builder: (context) => Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _SheetStack(
            engine: widget.engine,
            topInset: widget.topInset,
            bottomInset: widget.bottomInset,
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_entry]);
  }
}
