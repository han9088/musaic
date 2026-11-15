import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic_query/musaic_query.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('querySongs uses the Musaic native channel', () async {
    const channel = MethodChannel('com.deskbtm.muasic.query');
    MethodCall? received;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return <Object?>[];
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(await MusaicQuery().querySongs(), isEmpty);
    expect(received?.method, 'querySongs');
  });
}
