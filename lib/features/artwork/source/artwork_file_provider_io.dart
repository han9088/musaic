// 文件职责：在 IO 平台将本地封面文件转换为 Flutter 图片提供器。

import 'dart:io';

import 'package:flutter/widgets.dart';

/// 为本地文件 URI 创建 FileImage。
ImageProvider<Object> fileArtworkProvider(String uri) =>
    FileImage(File.fromUri(Uri.parse(uri)));
