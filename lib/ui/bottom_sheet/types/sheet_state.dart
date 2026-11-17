part of '../types.dart';

class BottomSheetState {
  const BottomSheetState({
    required this.id,
    required this.content,
    required this.options,
  });

  final String id;
  final Widget content;
  final ResolvedBottomSheetOptions options;
}
