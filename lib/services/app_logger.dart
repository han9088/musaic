// 文件职责：应用级服务、平台适配与辅助能力。

import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

final talker = TalkerFlutter.init();

/// 创建并组装所需对象或界面结构，用于应用级服务、平台适配与辅助能力。
TalkerDioLogger buildTalkerDioLogger() => TalkerDioLogger(
  talker: talker,
  settings: const TalkerDioLoggerSettings(
    printRequestHeaders: false,
    printResponseHeaders: false,
    printRequestData: false,
    printResponseData: false,
  ),
);
