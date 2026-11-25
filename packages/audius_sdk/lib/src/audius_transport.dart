import 'dart:convert';

import 'package:http/http.dart' as http;

import 'audius_api_exception.dart';
import 'json_utils.dart';

/// 负责 URL、认证头、超时、JSON 解码和 HTTP 错误处理。
///
/// 只使用公开 API Key，不接收 API Secret 或服务端 Bearer Token，
/// 避免把高权限凭据误放进移动端、桌面端或 Web 客户端。
class AudiusTransport {
  AudiusTransport({
    String? apiKey,
    required String baseUrl,
    required http.Client client,
    required bool ownsClient,
    required Duration timeout,
  }) : _apiKey = apiKey?.trim(),
       _baseUri = _normalizeBaseUri(baseUrl),
       _client = client,
       _ownsClient = ownsClient,
       _timeout = timeout {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive.');
    }
  }

  final String? _apiKey;
  final Uri _baseUri;
  final http.Client _client;
  final bool _ownsClient;
  final Duration _timeout;
  bool _closed = false;

  /// JSON API 请求头。
  Map<String, String> get headers => Map<String, String>.unmodifiable({
    'Accept': 'application/json',
    if (_apiKey?.isNotEmpty == true) 'x-api-key': _apiKey!,
  });

  /// 音频流请求头不声明 JSON Accept，避免影响音频节点协商。
  Map<String, String> get streamHeaders => Map<String, String>.unmodifiable({
    if (_apiKey?.isNotEmpty == true) 'x-api-key': _apiKey!,
  });

  Uri buildUri(String path, {Map<String, Object?> query = const {}}) {
    _ensureOpen();
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final endpoint = _baseUri.resolve(normalizedPath);
    final parameters = <String, List<String>>{};

    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;

      if (value is Iterable<Object?>) {
        final values = value
            .whereType<Object>()
            .map(_queryValue)
            .toList(growable: false);
        if (values.isNotEmpty) {
          parameters[entry.key] = values;
        }
      } else {
        parameters[entry.key] = <String>[_queryValue(value)];
      }
    }

    if (parameters.isEmpty) return endpoint;
    return endpoint.replace(queryParametersAll: parameters);
  }

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    final uri = buildUri(path, query: query);
    final response = await _client
        .get(uri, headers: headers)
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _toApiException(response, uri);
    }

    if (response.body.isEmpty) {
      throw const FormatException('Audius returned an empty JSON response.');
    }

    final decoded = jsonDecode(response.body);
    return requireJsonMap(decoded, label: 'Audius response');
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsClient) _client.close();
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('AudiusSdk has been closed.');
    }
  }

  AudiusApiException _toApiException(http.Response response, Uri uri) {
    var message =
        'Audius request failed with HTTP ' + response.statusCode.toString() + '.';

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<Object?, Object?>) {
        final body = requireJsonMap(decoded, label: 'Audius error');
        final candidate = body['message'] ?? body['error'] ?? body['detail'];
        if (candidate != null && candidate.toString().isNotEmpty) {
          message = candidate.toString();
        }
      }
    } on FormatException {
      if (response.body.isNotEmpty) {
        message = response.body;
      }
    }

    return AudiusApiException(
      statusCode: response.statusCode,
      message: message,
      requestUri: uri,
      responseBody: response.body,
      retryAfter: response.headers['retry-after'],
    );
  }

  static Uri _normalizeBaseUri(String value) {
    final uri = Uri.parse(value);
    if ((uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
        value,
        'baseUrl',
        'Must be an HTTP(S) base URL without query or fragment.',
      );
    }

    final path = uri.path.endsWith('/') ? uri.path : uri.path + '/';
    return uri.replace(path: path);
  }

  static String _queryValue(Object value) {
    if (value is bool) return value ? 'true' : 'false';
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value.toString();
  }
}
