import 'push_direction.dart';
import 'types.dart';

/// Numeric host layout modes matching RN worklets.
abstract final class HostLayoutMode {
  static const int modal = 0;
  static const int presentation = 1;
  static const int pushBottom = 2;
  static const int pushTop = 3;
}

int resolveHostLayoutMode(
  BottomSheetMode mode, {
  PushDirection pushDirection = PushDirection.bottom,
}) {
  if (mode == BottomSheetMode.push) {
    return pushDirection == PushDirection.top
        ? HostLayoutMode.pushTop
        : HostLayoutMode.pushBottom;
  }
  switch (mode) {
    case BottomSheetMode.modal:
      return HostLayoutMode.modal;
    case BottomSheetMode.presentation:
      return HostLayoutMode.presentation;
    case BottomSheetMode.push:
      return HostLayoutMode.pushBottom;
  }
}

int pushDirectionJsToHostLayoutMode(int direction) =>
    direction == PushDirectionJs.top
    ? HostLayoutMode.pushTop
    : HostLayoutMode.pushBottom;
