import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

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

Future<Version?> latestMusaicRelease() async {
  final client = http.Client();
  try {
    final response = await client
        .get(
          Uri.https('api.github.com', '/repos/han9088/musaic/releases/latest'),
          headers: const {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw StateError('Release check failed (${response.statusCode})');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> || payload['tag_name'] is! String) {
      throw const FormatException('Missing release tag');
    }
    return Version.parse(
      (payload['tag_name'] as String).replaceFirst(RegExp(r'^[vV]'), ''),
    );
  } finally {
    client.close();
  }
}
