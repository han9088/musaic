// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'package:material_ui/material_ui.dart';

import '../engine/bottom_sheet_engine.dart';
import '../host_layout_mode.dart';
import '../merge_layout_options.dart';
import '../scope/bottom_sheet_scope.dart';
import '../types.dart';
import 'bottom_sheet_backdrop.dart';
import 'bottom_sheet_host.dart';
import 'bottom_sheet_overlay_host.dart';

/// 封装或定义底部弹层提供器相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetProvider extends StatefulWidget {
  const BottomSheetProvider({
    super.key,
    required this.child,
    this.mode = BottomSheetMode.presentation,
    this.sheet,
    this.layout,
    this.theme,
  });

  final Widget child;
  final BottomSheetMode mode;
  final BottomSheetOptions? sheet;
  final BottomSheetLayoutOptionsPartial? layout;
  final BottomSheetTheme? theme;

  @override
  State<BottomSheetProvider> createState() => _BottomSheetProviderState();
}

/// 封装或定义底部弹层提供器状态相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class _BottomSheetProviderState extends State<BottomSheetProvider> {
  BottomSheetEngine? _engine;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    if (_engine == null) {
      _engine = BottomSheetEngine(
        hostMode: widget.mode,
        sheetDefaults: widget.sheet,
        layoutPartial: widget.layout,
        theme: widget.theme,
        screenHeight: size.height,
        screenWidth: size.width,
      );
      _engine!.activeHostMode.value = resolveHostLayoutMode(widget.mode);
    } else {
      _engine!.updateScreenSize(size.height, size.width);
    }
  }

  @override
  void didUpdateWidget(BottomSheetProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.theme != oldWidget.theme) {
      _engine?.updateTheme(widget.theme);
    }
    if (widget.layout != oldWidget.layout) {
      _engine?.updateLayout(widget.layout);
    }
    if (widget.mode != oldWidget.mode) {
      _engine?.hostMode = widget.mode;
      if (_engine?.sheets.isEmpty ?? true) {
        _engine?.activeHostMode.value = resolveHostLayoutMode(widget.mode);
      }
    }
    if (widget.sheet != oldWidget.sheet) {
      _engine?.sheetDefaults = widget.sheet;
    }
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine!;
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final bottomInset = media.padding.bottom;

    // 绘制顺序与 RN 的 z-index 规则保持一致：
    // letterbox（0）< 宿主（1）< 弹层（2 及以上）。
    return BottomSheetScope(
      engine: engine,
      child: ColoredBox(
        color: engine.mergedTheme.hostBackgroundColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _LetterboxLayer(engine: engine),
            BottomSheetHost(
              hostLayoutMode: engine.activeHostMode,
              progress: engine.bottomProgress,
              sheetTopY: engine.hostSheetTopY,
              pushProgressOpenY: engine.pushProgressOpenY,
              pushSheetHeight: engine.pushSheetHeight,
              topInset: topInset,
              screenHeight: engine.screenHeight,
              screenWidth: engine.screenWidth,
              layout: engine.mergedLayout,
              child: widget.child,
            ),
            BottomSheetOverlayHost(
              engine: engine,
              topInset: topInset,
              bottomInset: bottomInset,
            ),
          ],
        ),
      ),
    );
  }
}

/// 封装或定义letterboxlayer相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class _LetterboxLayer extends StatelessWidget {
  const _LetterboxLayer({required this.engine});

  final BottomSheetEngine engine;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([engine, engine.bottomProgress]),
      builder: (context, _) {
        if (engine.sheets.isEmpty) return const SizedBox.shrink();

        final top = engine.sheets.last;
        final mode = top.options.mode;
        if (mode != BottomSheetMode.presentation &&
            mode != BottomSheetMode.push) {
          return const SizedBox.shrink();
        }

        return BottomSheetBackdrop(
          color: top.options.theme.letterboxColor,
          opacity:
              engine.bottomProgress.value * top.options.theme.letterboxOpacity,
          onTap: engine.dismissTop,
        );
      },
    );
  }
}
