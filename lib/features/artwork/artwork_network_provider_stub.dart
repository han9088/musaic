// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'package:flutter/widgets.dart';

/// 执行当前模块中的网络图片操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
ImageProvider<Object> networkArtworkProvider(String url) => NetworkImage(url);
