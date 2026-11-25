/// 保留 Audius 响应信封中的 data 和其他元信息。
///
/// JS SDK 通常返回包含 data 的对象；Dart SDK 将 data 转为强类型，
/// 同时把 signature、timestamp、version 等字段保留在 metadata 中。
class AudiusResponse<T> {
  const AudiusResponse({
    required this.data,
    this.metadata = const <String, Object?>{},
  });

  final T data;
  final Map<String, Object?> metadata;

  factory AudiusResponse.fromJson(
    Map<String, Object?> json,
    T Function(Object? value) decodeData,
  ) {
    if (!json.containsKey('data')) {
      throw const FormatException('Audius response does not contain data.');
    }

    final metadata = Map<String, Object?>.from(json)..remove('data');
    return AudiusResponse<T>(
      data: decodeData(json['data']),
      metadata: Map<String, Object?>.unmodifiable(metadata),
    );
  }
}
