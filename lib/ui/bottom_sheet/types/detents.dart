// 文件职责：底部弹层的状态、布局、手势与动画引擎。

part of '../types.dart';

/// 封装或定义底部弹层模式相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
enum BottomSheetMode { presentation, modal, push }

/// 封装或定义推动方向相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
enum PushDirection { bottom, top }

/// 封装或定义底部弹层detentpreset相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
enum BottomSheetDetentPreset { medium, large, full }

/// 封装或定义底部弹层detent相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
sealed class BottomSheetDetent {
  const BottomSheetDetent();

  const factory BottomSheetDetent.preset(BottomSheetDetentPreset preset) =
      BottomSheetDetentPresetValue;
  const factory BottomSheetDetent.fraction(double fraction) =
      BottomSheetDetentFraction;
  const factory BottomSheetDetent.percent(String percent) =
      BottomSheetDetentPercent;

  /// 解析输入并转换为内部数据，用于底部弹层的状态、布局、手势与动画引擎。
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

/// 封装或定义底部弹层detentpresetvalue相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
final class BottomSheetDetentPresetValue extends BottomSheetDetent {
  const BottomSheetDetentPresetValue(this.preset);
  final BottomSheetDetentPreset preset;

  @override
  bool operator ==(Object other) =>
      other is BottomSheetDetentPresetValue && other.preset == preset;

  @override
  /// 判断当前状态是否满足指定条件，用于底部弹层的状态、布局、手势与动画引擎。
  int get hashCode => preset.hashCode;

  @override
  String toString() => 'BottomSheetDetent.preset($preset)';
}

/// 封装或定义底部弹层detentfraction相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
final class BottomSheetDetentFraction extends BottomSheetDetent {
  const BottomSheetDetentFraction(this.fraction);
  final double fraction;

  @override
  bool operator ==(Object other) =>
      other is BottomSheetDetentFraction && other.fraction == fraction;

  @override
  /// 判断当前状态是否满足指定条件，用于底部弹层的状态、布局、手势与动画引擎。
  int get hashCode => fraction.hashCode;

  @override
  String toString() => 'BottomSheetDetent.fraction($fraction)';
}

/// 封装或定义底部弹层detentpercent相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
final class BottomSheetDetentPercent extends BottomSheetDetent {
  const BottomSheetDetentPercent(this.percent);
  final String percent;

  @override
  bool operator ==(Object other) =>
      other is BottomSheetDetentPercent && other.percent == percent;

  @override
  /// 判断当前状态是否满足指定条件，用于底部弹层的状态、布局、手势与动画引擎。
  int get hashCode => percent.hashCode;

  @override
  String toString() => 'BottomSheetDetent.percent($percent)';
}

/// 封装或定义snappoint相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
typedef SnapPoint = BottomSheetDetent;

/// 封装或定义底部弹层keyboardbehavior相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
enum BottomSheetKeyboardBehavior { interactive, fillParent, extend }

/// 封装或定义底部弹层keyboardblurbehavior相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
enum BottomSheetKeyboardBlurBehavior { none, restore }

