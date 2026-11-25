import '../audius_response.dart';
import '../audius_stream.dart';
import '../audius_transport.dart';
import '../json_utils.dart';
import '../models.dart';
import '../api_utils.dart';

/// 与官方 @audius/sdk tracks namespace 对齐的只读音轨 API。
class AudiusTracksApi {
  const AudiusTracksApi(this._transport);

  final AudiusTransport _transport;

  /// 根据 Track ID 获取一首歌曲。
  Future<AudiusResponse<AudiusTrack>> getTrack({
    required String trackId,
    String? userId,
  }) async {
    final json = await _transport.getJson(
      'tracks/' + pathSegment(trackId, 'trackId'),
      query: <String, Object?>{'user_id': userId},
    );
    return decodeSingleResponse(json, AudiusTrack.fromJson);
  }

  /// 按 ID、permalink 或 ISRC 批量获取歌曲。
  Future<AudiusResponse<List<AudiusTrack>>> getBulkTracks({
    List<String>? ids,
    List<String>? permalinks,
    List<String>? isrcs,
    String? userId,
  }) async {
    if ((ids == null || ids.isEmpty) &&
        (permalinks == null || permalinks.isEmpty) &&
        (isrcs == null || isrcs.isEmpty)) {
      throw ArgumentError('Provide at least one track ID, permalink or ISRC.');
    }

    final json = await _transport.getJson(
      'tracks',
      query: <String, Object?>{
        'id': ids,
        'permalink': permalinks,
        'isrc': isrcs,
        'user_id': userId,
      },
    );
    return decodeListResponse(json, AudiusTrack.fromJson);
  }

  /// 搜索歌曲。数组筛选项会按 OpenAPI form-array 规则重复传递 query 参数。
  Future<AudiusResponse<List<AudiusTrack>>> searchTracks({
    String? query,
    int? offset,
    int? limit,
    List<String>? genres,
    String? sortMethod,
    List<String>? moods,
    bool? onlyDownloadable,
    bool? includePurchaseable,
    bool? isPurchaseable,
    bool? hasDownloads,
    List<String>? keys,
    num? bpmMin,
    num? bpmMax,
  }) async {
    validatePagination(offset: offset, limit: limit);
    if (bpmMin != null && bpmMax != null && bpmMin > bpmMax) {
      throw ArgumentError('bpmMin must not be greater than bpmMax.');
    }

    final json = await _transport.getJson(
      'tracks/search',
      query: <String, Object?>{
        'query': query,
        'offset': offset,
        'limit': limit,
        'genre': genres,
        'sort_method': sortMethod,
        'mood': moods,
        'only_downloadable': onlyDownloadable,
        'include_purchaseable': includePurchaseable,
        'is_purchaseable': isPurchaseable,
        'has_downloads': hasDownloads,
        'key': keys,
        'bpm_min': bpmMin,
        'bpm_max': bpmMax,
      },
    );
    return decodeListResponse(json, AudiusTrack.fromJson);
  }

  /// 获取热门歌曲。time 支持 week、month、year、allTime。
  Future<AudiusResponse<List<AudiusTrack>>> getTrendingTracks({
    String? genre,
    String time = 'allTime',
    int? offset,
    int? limit,
    String? userId,
  }) async {
    validatePagination(offset: offset, limit: limit);
    final json = await _transport.getJson(
      'tracks/trending',
      query: <String, Object?>{
        'genre': genre,
        'time': time,
        'offset': offset,
        'limit': limit,
        'user_id': userId,
      },
    );
    return decodeListResponse(json, AudiusTrack.fromJson);
  }

  /// 获取地下热门歌曲。
  Future<AudiusResponse<List<AudiusTrack>>> getUndergroundTrendingTracks({
    int? offset,
    int? limit,
    String? userId,
  }) async {
    validatePagination(offset: offset, limit: limit);
    final json = await _transport.getJson(
      'tracks/trending/underground',
      query: <String, Object?>{
        'offset': offset,
        'limit': limit,
        'user_id': userId,
      },
    );
    return decodeListResponse(json, AudiusTrack.fromJson);
  }

  /// 构造可交给音频播放器的流地址。
  ///
  /// 该方法不主动下载音频。播放器请求 uri 时应同时传入返回的 headers，
  /// 以便服务端识别 API Key，并跟随 Audius 的音频节点重定向。
  AudiusStream getTrackStream({
    required String trackId,
    String? userId,
  }) {
    final uri = _transport.buildUri(
      'tracks/' + pathSegment(trackId, 'trackId') + '/stream',
      query: <String, Object?>{'user_id': userId},
    );
    return AudiusStream(uri: uri, headers: _transport.streamHeaders);
  }
}
