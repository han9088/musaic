import 'package:material_ui/material_ui.dart';

import '../../ui/bottom_sheet/bottom_sheet.dart';

class HomeSheet extends StatefulWidget {
  const HomeSheet({super.key, required this.child});

  final Widget child;

  @override
  State<HomeSheet> createState() => _HomeSheetState();
}

class _HomeSheetState extends State<HomeSheet> {
  bool _open = false;
  double _dragUp = 0;

  void _present() {
    if (_open) return;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    DeskBottomSheet.of(context).present(
      const SizedBox.expand(),
      BottomSheetOptions(
        mode: BottomSheetMode.push,
        pushDirection: PushDirection.bottom,
        snapPoints: [
          const BottomSheetDetent.fraction(0.38),
          BottomSheetDetent.fraction(landscape ? 0.76 : 0.78),
        ],
        index: 0,
        enableDynamicSizing: false,
        enablePanDownToClose: true,
        dismissOnScrimPress: true,
        enableContentPanningGesture: true,
        showHandle: true,
        onDismiss: () {
          if (mounted) setState(() => _open = false);
        },
      ),
    );
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _open) DeskBottomSheet.of(context).dismiss();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: IgnorePointer(
                ignoring: _open,
                child: AnimatedOpacity(
                  opacity: _open ? 0 : 1,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 120),
                  child: Semantics(
                    button: true,
                    label: MaterialLocalizations.of(context).showMenuTooltip,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _present,
                      onVerticalDragStart: (_) => _dragUp = 0,
                      onVerticalDragUpdate: (details) {
                        final dy = details.primaryDelta ?? 0;
                        _dragUp = dy < 0 ? _dragUp - dy : 0;
                        if (_dragUp >= 36) _present();
                      },
                      onVerticalDragEnd: (details) {
                        if ((details.primaryVelocity ?? 0) <= -200) _present();
                        _dragUp = 0;
                      },
                      onVerticalDragCancel: () => _dragUp = 0,
                      child: SizedBox(
                        width: 140,
                        height: 70,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 26),
                            child: Container(
                              width: 44,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xB3FFFFFF),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: const [
                                  BoxShadow(blurRadius: 4, color: Color(0x66000000)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
