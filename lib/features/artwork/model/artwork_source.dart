// 文件职责：定义专辑封面来源类型、引用值、稳定身份与版本信息。

import 'package:flutter/foundation.dart';

import 'artwork_identity.dart';

/// 专辑封面实际存放或获取的位置。
enum ArtworkSourceType { asset, network, directory, placeholder }

/// 将历史字符串引用解析为有明确类型的图片来源。
@immutable
class ArtworkSource {
  const ArtworkSource._({
    required this.type,
    required this.value,
    required this.artworkIdentity,
    required this.version,
  });

  factory ArtworkSource.parse(
    String reference, {
    ArtworkIdentity? identity,
    ArtworkVersion? version,
  }) {
    if (reference.startsWith('directory:')) {
      final value = reference.substring('directory:'.length);
      return ArtworkSource._(
        type: ArtworkSourceType.directory,
        value: value,
        artworkIdentity: identity ?? ArtworkIdentity('directory:$value'),
        version: version,
      );
    }

    if (reference.startsWith('local:')) {
      final value = reference.substring('local:'.length);
      return ArtworkSource._(
        type: ArtworkSourceType.placeholder,
        value: value,
        artworkIdentity: identity ?? ArtworkIdentity('local:$value'),
        version: version,
      );
    }

    final uri = Uri.tryParse(reference);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      final normalized = uri.toString();
      return ArtworkSource._(
        type: ArtworkSourceType.network,
        value: normalized,
        artworkIdentity: identity ?? ArtworkIdentity(normalized),
        version: version,
      );
    }

    return ArtworkSource._(
      type: ArtworkSourceType.asset,
      value: reference,
      artworkIdentity: identity ?? ArtworkIdentity(reference),
      version: version,
    );
  }

  final ArtworkSourceType type;
  final String value;
  final ArtworkIdentity artworkIdentity;
  final ArtworkVersion? version;

  /// 兼容现有图片管线使用的字符串身份。
  String get identity => artworkIdentity.value;

  /// 供资源缓存使用的身份与版本组合；不包含解码尺寸。
  String get cacheKey => '${artworkIdentity.value}|${version?.value ?? ''}|$value';

  bool get isDirectory => type == ArtworkSourceType.directory;
  bool get isPlaceholder => type == ArtworkSourceType.placeholder;
}
