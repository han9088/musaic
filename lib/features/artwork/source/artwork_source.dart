// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

/// 封装或定义专辑封面来源type相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
enum ArtworkSourceType { asset, network, directory, placeholder }

/// 封装或定义专辑封面来源相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class ArtworkSource {
  const ArtworkSource._(this.type, this.value);

  /// Interprets the app's legacy source string into a typed source descriptor.
  factory ArtworkSource.parse(String reference) {
    if (reference.startsWith('directory:')) {
      return ArtworkSource._(
        ArtworkSourceType.directory,
        reference.substring('directory:'.length),
      );
    }
    if (reference.startsWith('local:')) {
      return ArtworkSource._(
        ArtworkSourceType.placeholder,
        reference.substring('local:'.length),
      );
    }

    final uri = Uri.tryParse(reference);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return ArtworkSource._(ArtworkSourceType.network, uri.toString());
    }
    return ArtworkSource._(ArtworkSourceType.asset, reference);
  }

  final ArtworkSourceType type;
  final String value;

  /// 执行当前模块中的identity操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  String get identity => switch (type) {
    ArtworkSourceType.asset || ArtworkSourceType.network => value,
    ArtworkSourceType.directory => 'directory:$value',
    ArtworkSourceType.placeholder => 'local:$value',
  };

  /// 管理缓存写入、命中或失效过程，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  String get cacheKey => identity;
  /// 判断当前状态是否满足指定条件，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  bool get isDirectory => type == ArtworkSourceType.directory;
  /// 判断当前状态是否满足指定条件，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  bool get isPlaceholder => type == ArtworkSourceType.placeholder;
}
