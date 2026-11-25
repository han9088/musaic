/// Audius API 请求失败时抛出的异常。
class AudiusApiException implements Exception {
  const AudiusApiException({
    required this.statusCode,
    required this.message,
    required this.requestUri,
    this.responseBody,
    this.retryAfter,
  });

  final int statusCode;
  final String message;
  final Uri requestUri;
  final String? responseBody;

  /// 服务端提供的 Retry-After 响应头，通常用于处理 429 限流。
  final String? retryAfter;

  @override
  String toString() {
    return 'AudiusApiException($statusCode): $message [$requestUri]';
  }
}
