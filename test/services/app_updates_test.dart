import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/services/app_logger.dart';
import 'package:musaic/services/app_updates.dart';
import 'package:musaic/services/diagnostics/diagnostic_log.dart';
import 'package:musaic/services/diagnostics/diagnostic_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'release checks include sanitized Dio entries in the diagnostic report',
    () async {
      addTearDown(diagnosticLog.talker.cleanHistory);

      Dio clientFor(int status, String body) =>
          createLoggedDio()..httpClientAdapter = _ReleaseAdapter(status, body);

      final version = await latestMusaicRelease(
        createClient: () => clientFor(200, '{"tag_name":"v1.0.0+2"}'),
      );
      expect(version.toString(), '1.0.0+2');
      expect(
        await latestMusaicRelease(createClient: () => clientFor(404, '')),
        isNull,
      );
      await expectLater(
        latestMusaicRelease(createClient: () => clientFor(503, 'private-body')),
        throwsA(isA<DioException>()),
      );

      final report = utf8.decode((await DiagnosticReport.create()).bytes);
      expect(report, contains('http-request GET api.github.com'));
      expect(report, contains('http-response GET api.github.com status=200'));
      expect(report, contains('http-error GET api.github.com status=503'));
      expect(report, isNot(contains('/repos/han9088')));
      expect(report, isNot(contains('tag_name')));
      expect(report, isNot(contains('private-')));
    },
  );
}

class _ReleaseAdapter implements HttpClientAdapter {
  _ReleaseAdapter(this.status, this.body);

  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.uri.path, '/repos/han9088/musaic/releases/latest');
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        'set-cookie': ['private-cookie'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
