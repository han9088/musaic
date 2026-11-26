// 文件职责：应用级服务、平台适配与辅助能力。

import 'package:dio/dio.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import 'diagnostics/diagnostic_log.dart';

Dio createLoggedDio() => Dio()
  ..interceptors.add(
    TalkerDioLogger(
      talker: diagnosticLog.talker,
      settings: const TalkerDioLoggerSettings(
        printRequestData: false,
        printResponseData: false,
        printResponseMessage: false,
        printErrorData: false,
        printErrorHeaders: false,
        printErrorMessage: false,
        printResponseTime: true,
      ),
    ),
  );
