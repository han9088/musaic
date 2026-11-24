import 'package:indiebase/indiebase.dart';

import '../config/indiebase_config.dart';

/// Owns one lazily created Project Runtime client for the app.
class IndiebaseRuntime {
  IndiebaseRuntime._(this._baseUrl, this._apiKey);

  final String _baseUrl;
  final String _apiKey;
  IndiebaseClient? _client;

  static IndiebaseRuntime? fromEnvironment({
    String baseUrl = indiebaseBaseUrl,
    String apiKey = indiebaseApiKey,
  }) {
    if (baseUrl.isEmpty || apiKey.isEmpty) return null;
    return IndiebaseRuntime._(baseUrl, apiKey);
  }

  IndiebaseClient get client => _client ??= IndiebaseClient(
    baseUrl: _baseUrl,
    apiKey: _apiKey,
    collectClientContext: false,
  );

  void close() => _client?.close();
}
