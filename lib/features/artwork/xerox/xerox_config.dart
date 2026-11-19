// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

/// 封装或定义Xeroxconfig相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxConfig {
  const XeroxConfig({
    this.edge = 0.9,
    this.contrast = 32,
    this.smooth = 0,
    this.grain = 0.5,
    this.invert = false,
  });

  final double edge;
  final double contrast;
  final double smooth;
  final double grain;
  final bool invert;
}

const xeroxConfig = XeroxConfig();
