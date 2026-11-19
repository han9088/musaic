// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:io';

import 'package:flutter/widgets.dart';

/// 执行当前模块中的文件封面图提供器操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
ImageProvider<Object> fileArtworkProvider(String uri) =>
    FileImage(File.fromUri(Uri.parse(uri)));
