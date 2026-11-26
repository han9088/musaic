import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pub_semver/pub_semver.dart';

import 'app_logger.dart';

final musaicReleasesUrl = Uri.https(
  'github.com',
  '/han9088/musaic/releases/latest',
);

bool isMusaicUpdateAvailable(Version latest, String version, String build) {
  final installed = Version.parse(version);
  if (latest.build.isEmpty || build.isEmpty || installed.build.isNotEmpty) {
    return latest > installed;
  }
  return latest > Version.parse('$version+$build');
}

Future<Version?> latestMusaicRelease({
  Dio Function() createClient = createLoggedDio,
}) async {
  final client = createClient();
  try {
    final response = await client
        .getUri<String>(
          Uri.https('api.github.com', '/repos/han9088/musaic/releases/latest'),
          options: Options(
            headers: const {'Accept': 'application/vnd.github+json'},
            responseType: ResponseType.plain,
          ),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Release check failed (${response.statusCode})');
    }
    final payload = jsonDecode(response.data ?? '');
    if (payload is! Map<String, dynamic> || payload['tag_name'] is! String) {
      throw const FormatException('Missing release tag');
    }
    return Version.parse(
      (payload['tag_name'] as String).replaceFirst(RegExp(r'^[vV]'), ''),
    );
  } on DioException catch (error) {
    if (error.response?.statusCode == 404) return null;
    rethrow;
  } finally {
    client.close(force: true);
  }
}
