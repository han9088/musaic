import 'types.dart';

/// Numeric push direction (0 = bottom, 1 = top) matching RN worklets.
abstract final class PushDirectionJs {
  static const int bottom = 0;
  static const int top = 1;
}

int pushDirectionToJs(PushDirection direction) => direction == PushDirection.top
    ? PushDirectionJs.top
    : PushDirectionJs.bottom;

bool isTopPushDirection(PushDirection direction) =>
    direction == PushDirection.top;

bool isTopPushDirectionJs(int direction) => direction == PushDirectionJs.top;
