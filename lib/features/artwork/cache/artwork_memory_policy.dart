// 文件职责：集中定义 Artwork 与 Xerox 位图缓存的默认内存预算。

import 'package:flutter/foundation.dart';

/// 按平台给出保守的默认预算，同时允许调用方通过构造参数覆盖。
///
/// 该策略不假装读取设备真实可用内存；需要更细粒度的设备分级时，
/// 应由宿主应用注入经过设备 Profile 验证的预算。
abstract final class ArtworkMemoryPolicy {
  static const int mebibyte = 1024 * 1024;

  static int get defaultXeroxRasterBytes {
    if (kIsWeb) return 32 * mebibyte;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => 64 * mebibyte,
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => 128 * mebibyte,
      TargetPlatform.fuchsia => 64 * mebibyte,
    };
  }

  /// 非 IO 平台的磁盘缓存替代实现只能驻留内存，因此使用更小的独立上限。
  static const int fallbackXeroxDiskBytes = 32 * mebibyte;
}
