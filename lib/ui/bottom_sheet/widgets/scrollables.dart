import 'package:material_ui/material_ui.dart';

import '../constants.dart';
import '../scope/bottom_sheet_scope.dart';

/// Non-scrolling content wrapper that reports layout height for dynamic sizing.
class BottomSheetView extends StatelessWidget {
  const BottomSheetView({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = BottomSheetContent.maybeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) => false,
          child: SizeChangedLayoutNotifier(
            child: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box != null && box.hasSize) {
                    content?.onContentLayout(box.size.height);
                  }
                });
                return Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// ScrollView with scroll→pan handoff contract.
class BottomSheetScrollView extends StatelessWidget {
  const BottomSheetScrollView({
    super.key,
    required this.child,
    this.controller,
    this.padding,
    this.physics,
  });

  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final sheet = BottomSheetContent.maybeOf(context);
    final bottomInset = sheet?.bottomInset ?? 0;
    final endPadding = getBottomSheetScrollBottomPadding(bottomInset);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (sheet == null) return false;
        if (notification is ScrollUpdateNotification ||
            notification is ScrollStartNotification) {
          final metrics = notification.metrics;
          sheet.scrollOffset.value = metrics.pixels;
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: controller,
        physics: physics,
        padding: padding ?? EdgeInsets.only(bottom: endPadding),
        child: child,
      ),
    );
  }
}

/// ListView with scroll→pan handoff.
class BottomSheetListView extends StatelessWidget {
  const BottomSheetListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.physics,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final sheet = BottomSheetContent.maybeOf(context);
    final bottomInset = sheet?.bottomInset ?? 0;
    final endPadding = getBottomSheetScrollBottomPadding(bottomInset);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (sheet == null) return false;
        if (notification is ScrollUpdateNotification ||
            notification is ScrollStartNotification) {
          sheet.scrollOffset.value = notification.metrics.pixels;
        }
        return false;
      },
      child: ListView.builder(
        controller: controller,
        physics: physics,
        padding: padding ?? EdgeInsets.only(bottom: endPadding),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// TextField that participates in keyboard avoidance.
class BottomSheetTextField extends StatelessWidget {
  const BottomSheetTextField({
    super.key,
    this.controller,
    this.decoration,
    this.keyboardType,
    this.onChanged,
    this.maxLines = 1,
  });

  final TextEditingController? controller;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: decoration,
      keyboardType: keyboardType,
      onChanged: onChanged,
      maxLines: maxLines,
    );
  }
}
