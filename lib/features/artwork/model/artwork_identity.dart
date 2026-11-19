// 文件职责：定义专辑封面的稳定身份与资源版本。

import 'package:flutter/foundation.dart';

/// 标识一张逻辑上的专辑封面，不随图片下载地址或解码尺寸变化。
@immutable
class ArtworkIdentity {
  const ArtworkIdentity(this.value);

  /// 由音乐源提供的稳定 ID；没有外部 ID 时使用来源引用作为回退值。
  final String value;

  @override
  bool operator ==(Object other) =>
      other is ArtworkIdentity && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// 标识同一封面内容的具体版本，用于源图片更新时使下游缓存失效。
///
/// 可传入服务端版本号、ETag、文件修改时间或其他稳定版本标记。
@immutable
class ArtworkVersion {
  const ArtworkVersion(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is ArtworkVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
