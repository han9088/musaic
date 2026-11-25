import '../audius_response.dart';
import '../audius_transport.dart';
import '../json_utils.dart';
import '../models.dart';

/// Audius canonical URL resolver。
class AudiusResolveApi {
  const AudiusResolveApi(this._transport);

  final AudiusTransport _transport;

  /// 将 audius.co 的歌曲、歌单或专辑链接解析为 API 资源。
  Future<AudiusResponse<AudiusResolvedResource>> resolveUrl({
    required Uri url,
  }) async {
    if (url.scheme != 'https' && url.scheme != 'http') {
      throw ArgumentError.value(url, 'url', 'Must be an HTTP(S) URL.');
    }

    final json = await _transport.getJson(
      'resolve',
      query: <String, Object?>{'url': url.toString()},
    );
    return AudiusResponse<AudiusResolvedResource>.fromJson(
      json,
      (value) => AudiusResolvedResource.fromJson(
        requireJsonMap(value, label: 'resolved resource'),
      ),
    );
  }
}
