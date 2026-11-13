import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

class _TestSensors extends SensorsPlatform {
  @override
  Stream<AccelerometerEvent> accelerometerEventStream({
    Duration samplingPeriod = SensorInterval.normalInterval,
  }) => const Stream.empty();
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final original = SensorsPlatform.instance;
  SensorsPlatform.instance = _TestSensors();
  try {
    await testMain();
  } finally {
    SensorsPlatform.instance = original;
  }
}
