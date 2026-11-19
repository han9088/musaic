// 文件职责：为不支持 dart:io 的平台提供本地文件封面的安全降级。

import 'package:flutter/widgets.dart';

/// 非 IO 平台无法直接读取本地文件 URI，返回 null 交由上层展示占位内容。
ImageProvider<Object>? fileArtworkProvider(String uri) => null;
