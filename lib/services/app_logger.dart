import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

final talker = TalkerFlutter.init();

TalkerDioLogger buildTalkerDioLogger() => TalkerDioLogger(
  talker: talker,
  settings: const TalkerDioLoggerSettings(
    printRequestHeaders: false,
    printResponseHeaders: false,
    printRequestData: false,
    printResponseData: false,
  ),
);
