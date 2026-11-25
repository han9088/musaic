import 'audius_response.dart';

/// 将 JSON 对象安全转换为 String-keyed map，避免在 API 层散落动态转换。
Map<String, Object?> requireJsonMap(
  Object? value, {
  String label = 'JSON value',
}) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('$label must be a JSON object.');
  }

  return <String, Object?>{
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

/// 将 JSON 数组解析为不可变的强类型列表。
List<T> decodeJsonList<T>(
  Object? value,
  T Function(Map<String, Object?> json) decodeItem, {
  String label = 'data',
}) {
  if (value is! List<Object?>) {
    throw FormatException('Audius $label must be a JSON array.');
  }

  return List<T>.unmodifiable(
    value.map(
      (item) => decodeItem(requireJsonMap(item, label: 'Audius $label item')),
    ),
  );
}

/// 解析单个 JSON 对象响应。
AudiusResponse<T> decodeSingleResponse<T>(
  Map<String, Object?> json,
  T Function(Map<String, Object?> value) decodeItem,
) {
  return AudiusResponse<T>.fromJson(
    json,
    (value) => decodeItem(
      requireJsonMap(
        value is List<Object?> && value.length == 1 ? value.single : value,
      ),
    ),
  );
}

/// 解析 JSON 数组响应。
AudiusResponse<List<T>> decodeListResponse<T>(
  Map<String, Object?> json,
  T Function(Map<String, Object?> value) decodeItem,
) {
  return AudiusResponse<List<T>>.fromJson(
    json,
    (value) => decodeJsonList(value, decodeItem),
  );
}
