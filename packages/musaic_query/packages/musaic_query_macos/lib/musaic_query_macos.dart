import 'package:flutter/services.dart';
import 'package:musaic_query_desktop/musaic_query_desktop.dart';
import 'package:musaic_query_platform_interface/method_channel_musaic_query.dart';
import 'package:musaic_query_platform_interface/musaic_query_platform_interface.dart';

class MusaicQueryMacos extends MethodChannelMusaicQuery {
  static void registerWith() {
    MusaicQueryPlatform.instance = MusaicQueryMacos();
  }

  @override
  final DesktopAudioDirectory directories = _MacosAudioDirectory();

  @override
  Future<void> setLogConfig(LogConfig? logConfig) async {}

  @override
  Future<AudioPlaybackSource> openSongPlayback(int id) async {
    final opened = (await channel.invokeMapMethod<String, String>(
      'openSongPlayback',
      {'id': id},
    ))!;
    return AudioPlaybackSource(
      Uri.parse(opened['uri']!),
      () => channel.invokeMethod<void>('closeSongPlayback', {
        'session': opened['session']!,
      }),
    );
  }
}

class _MacosAudioDirectory extends DesktopAudioDirectory {
  static const _channel = MethodChannel(
    'com.deskbtm.musaic.query/macos_directories',
  );
  final _grants = <String, Future<AudioDirectory>>{};

  @override
  Future<AudioDirectory?> pickDirectory() async {
    final selection = await _channel.invokeMapMethod<String, String>('pick');
    if (selection == null) return null;
    final path = selection['path']!;
    try {
      final source = await openDirectory(path, token: selection['token']!);
      _grants[source.id] = Future.value(source);
      return source;
    } catch (_) {
      await _channel.invokeMethod<void>('release', {'path': path});
      rethrow;
    }
  }

  @override
  Future<AudioDirectory> restoreDirectory(AudioDirectory source) async {
    if (source.id == source.token) return super.restoreDirectory(source);
    final grant = await _grants.putIfAbsent(source.id, () => _resolve(source));
    return super.restoreDirectory(grant);
  }

  Future<AudioDirectory> _resolve(AudioDirectory source) async {
    try {
      final token = await _channel.invokeMethod<String>(
        'restore',
        _arguments(source),
      );
      return AudioDirectory(id: source.id, name: source.name, token: token!);
    } catch (_) {
      _grants.remove(source.id);
      rethrow;
    }
  }

  @override
  Future<void> releaseDirectory(AudioDirectory source) async {
    if (source.id == source.token) return;
    _grants.remove(source.id);
    await _channel.invokeMethod<void>('release', _arguments(source));
  }

  @override
  Future<String?> retainPlayback(AudioDirectory source) {
    if (source.id == source.token) return Future.value();
    return _channel.invokeMethod<String>('retainPlayback', _arguments(source));
  }

  @override
  Future<void> releasePlayback(String session) =>
      _channel.invokeMethod<void>('releasePlayback', {'session': session});

  Map<String, String> _arguments(AudioDirectory source) => {
    'path': Uri.parse(source.id).toFilePath(),
    'token': source.token,
  };
}
