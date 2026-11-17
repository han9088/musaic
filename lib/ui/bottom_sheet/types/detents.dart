part of '../types.dart';

/// Host presentation style for bottom sheets.
///
/// - [presentation] — iOS-style: scales the app behind the sheet, letterbox,
///   stacked card peek.
/// - [modal] — standard overlay: app stays full size, dimmed scrim.
/// - [push] — pushes the host away from the sheet.
enum BottomSheetMode { presentation, modal, push }

/// Which screen edge the sheet pushes from in [BottomSheetMode.push].
enum PushDirection { bottom, top }

/// Built-in snap heights: 50%, 90%, and full screen.
enum BottomSheetDetentPreset { medium, large, full }

/// Preset, screen-height fraction (0–1), or percentage string such as `50%`.
sealed class BottomSheetDetent {
  const BottomSheetDetent();

  const factory BottomSheetDetent.preset(BottomSheetDetentPreset preset) =
      BottomSheetDetentPresetValue;
  const factory BottomSheetDetent.fraction(double fraction) =
      BottomSheetDetentFraction;
  const factory BottomSheetDetent.percent(String percent) =
      BottomSheetDetentPercent;

  /// Parses a snap point: preset name, `0–1` fraction, or `"50%"` string.
  static BottomSheetDetent parse(Object value) {
    if (value is BottomSheetDetent) return value;
    if (value is BottomSheetDetentPreset) {
      return BottomSheetDetent.preset(value);
    }
    if (value is num) {
      return BottomSheetDetent.fraction(value.toDouble());
    }
    if (value is String) {
      switch (value) {
        case 'medium':
          return const BottomSheetDetent.preset(BottomSheetDetentPreset.medium);
        case 'large':
          return const BottomSheetDetent.preset(BottomSheetDetentPreset.large);
        case 'full':
          return const BottomSheetDetent.preset(BottomSheetDetentPreset.full);
        default:
          return BottomSheetDetent.percent(value);
      }
    }
    throw ArgumentError.value(value, 'value', 'Unsupported detent');
  }

  static const medium = BottomSheetDetent.preset(
    BottomSheetDetentPreset.medium,
  );
  static const large = BottomSheetDetent.preset(BottomSheetDetentPreset.large);
  static const full = BottomSheetDetent.preset(BottomSheetDetentPreset.full);
}

final class BottomSheetDetentPresetValue extends BottomSheetDetent {
  const BottomSheetDetentPresetValue(this.preset);
  final BottomSheetDetentPreset preset;

  @override
  bool operator ==(Object other) =>
      other is BottomSheetDetentPresetValue && other.preset == preset;

  @override
  int get hashCode => preset.hashCode;

  @override
  String toString() => 'BottomSheetDetent.preset($preset)';
}

final class BottomSheetDetentFraction extends BottomSheetDetent {
  const BottomSheetDetentFraction(this.fraction);
  final double fraction;

  @override
  bool operator ==(Object other) =>
      other is BottomSheetDetentFraction && other.fraction == fraction;

  @override
  int get hashCode => fraction.hashCode;

  @override
  String toString() => 'BottomSheetDetent.fraction($fraction)';
}

final class BottomSheetDetentPercent extends BottomSheetDetent {
  const BottomSheetDetentPercent(this.percent);
  final String percent;

  @override
  bool operator ==(Object other) =>
      other is BottomSheetDetentPercent && other.percent == percent;

  @override
  int get hashCode => percent.hashCode;

  @override
  String toString() => 'BottomSheetDetent.percent($percent)';
}

typedef SnapPoint = BottomSheetDetent;

enum BottomSheetKeyboardBehavior { interactive, fillParent, extend }

enum BottomSheetKeyboardBlurBehavior { none, restore }

