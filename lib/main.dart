// 文件职责：应用启动、依赖初始化与根组件挂载。

import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';

import 'package:material_ui/material_ui.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const MusaicApp());
}
