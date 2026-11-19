// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

/// 执行当前模块中的Xerox种子操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
int xeroxSeed(String identity) {
  var hash = 0x811c9dc5;
  for (final unit in identity.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash % 65521;
}
