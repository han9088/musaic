/// 可交给 just_audio、audioplayers 等播放器消费的 Audius 音频流。
///
/// stream endpoint 通常会重定向到实际音频节点。播放器需要保留 headers，
/// 尤其是配置了 API Key 时的 x-api-key。
class AudiusStream {
  AudiusStream({
    required this.uri,
    required Map<String, String> headers,
  }) : headers = Map<String, String>.unmodifiable(headers);

  final Uri uri;
  final Map<String, String> headers;
}
