import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic_audio_windows/musaic_audio_windows.dart';
import 'package:musaic_audio_platform_interface/musaic_audio_platform_interface.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const main = MethodChannel('com.deskbtm.musaic.audio.methods');
  const channel = MethodChannel('com.deskbtm.musaic.audio.methods.test');
  late AudioPlayerPlatform player;
  late List<MethodCall> calls;

  final a = ProgressiveAudioSourceMessage(
    id: 'a',
    uri: 'file:///C:/musaic%20%C3%A1udio/track%20%231%2520.wav',
  );
  final clip = ClippingAudioSourceMessage(
    id: 'clip',
    child: ProgressiveAudioSourceMessage(id: 'b', uri: 'file:///C:/b.wav'),
    start: const Duration(minutes: 42),
    end: const Duration(minutes: 43),
  );
  ConcatenatingAudioSourceMessage nested(List<int> order) =>
      ConcatenatingAudioSourceMessage(
        id: 'nested',
        children: [clip, a],
        useLazyPreparation: true,
        shuffleOrder: order,
      );
  ConcatenatingAudioSourceMessage root(
    List<int> order,
    List<int> nestedOrder,
  ) =>
      ConcatenatingAudioSourceMessage(
        id: '',
        children: [
          a,
          LoopingAudioSourceMessage(
            id: 'loop',
            child: nested(nestedOrder),
            count: 2,
          ),
        ],
        useLazyPreparation: true,
        shuffleOrder: order,
      );

  Map<Object?, Object?> arguments(int index) =>
      calls[index].arguments as Map<Object?, Object?>;
  List<Object?> itemIds(int call) => (arguments(call)['items'] as List<Object?>)
      .map((item) => (item as Map<Object?, Object?>)['id'])
      .toList();

  setUp(() async {
    calls = [];
    messenger
      ..setMockMethodCallHandler(main, (call) async => null)
      ..setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'load' ? {'duration': 60000000} : null;
      });
    MusaicAudioWindows.registerWith();
    player = await MusaicAudioPlatform.instance.init(InitRequest(id: 'test'));
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(main, null)
      ..setMockMethodCallHandler(channel, null);
  });

  test('flattens nested shuffle and preserves repeated item identities',
      () async {
    final response = await player.load(
      LoadRequest(
        audioSourceMessage: root([1, 0], [1, 0]),
        initialIndex: 3,
        initialPosition: const Duration(seconds: 2),
      ),
    );

    expect(response.duration, const Duration(minutes: 1));
    expect(arguments(0)['initialIndex'], 3);
    expect(arguments(0)['initialPosition'], 2000000);
    expect(arguments(0)['shuffleOrder'], [2, 1, 4, 3, 0]);
    final items = arguments(0)['items'] as List<Object?>;
    final local = items[0] as Map<Object?, Object?>;
    expect(local['filePath'], r'C:\musaic áudio\track #1%20.wav');
    final clipped = items[1] as Map<Object?, Object?>;
    expect(clipped['start'], 2520000000);
    expect(clipped['end'], 2580000000);
    expect(itemIds(0).toSet(), hasLength(5));

    await player.setShuffleOrder(
      SetShuffleOrderRequest(audioSourceMessage: root([0, 1], [0, 1])),
    );
    expect(arguments(1)['shuffleOrder'], [0, 1, 2, 3, 4]);
    expect(itemIds(1), itemIds(0));

    await player.concatenatingMove(
      ConcatenatingMoveRequest(
        id: 'nested',
        currentIndex: 0,
        newIndex: 1,
        shuffleOrder: [0, 1],
      ),
    );
    expect(itemIds(2), [0, 2, 1, 4, 3]);

    await player.concatenatingRemoveRange(
      ConcatenatingRemoveRangeRequest(
        id: 'nested',
        startIndex: 1,
        endIndex: 2,
        shuffleOrder: [0],
      ),
    );
    expect(itemIds(3), [0, 2, 4]);
    expect(arguments(3)['shuffleOrder'], [0, 1, 2]);
  });

  test('serializes overlapping edits to different nested playlists', () async {
    await player.load(LoadRequest(audioSourceMessage: root([0, 1], [0, 1])));
    await Future.wait([
      player.concatenatingInsertAll(
        ConcatenatingInsertAllRequest(
          id: '',
          index: 0,
          children: [a],
          shuffleOrder: [1, 0, 2],
        ),
      ),
      player.concatenatingRemoveRange(
        ConcatenatingRemoveRangeRequest(
          id: 'nested',
          startIndex: 0,
          endIndex: 1,
          shuffleOrder: [0],
        ),
      ),
    ]);
    expect(itemIds(2), [5, 0, 2, 4]);
    expect(arguments(2)['shuffleOrder'], [1, 0, 2, 3]);
  });

  test('keeps adaptive transport and headers through source clipping',
      () async {
    const headers = {'Authorization': 'Bearer sample'};
    final hls = HlsAudioSourceMessage(
      id: 'hls',
      uri: 'https://example.com/stream',
      headers: headers,
    );
    final dash = DashAudioSourceMessage(
      id: 'dash',
      uri: 'https://example.com/manifest',
      headers: headers,
    );
    await player.load(LoadRequest(
      audioSourceMessage: ConcatenatingAudioSourceMessage(
        id: '',
        children: [
          ClippingAudioSourceMessage(id: 'clipped', child: hls),
          dash,
          a
        ],
        useLazyPreparation: true,
        shuffleOrder: [0, 1, 2],
      ),
    ));
    final items =
        (arguments(0)['items'] as List<Object?>).cast<Map<Object?, Object?>>();
    expect(items.map((item) => item['adaptive']), [true, true, false]);
    expect(items[0]['headers'], headers);
    expect(items[1]['headers'], headers);
  });
}
