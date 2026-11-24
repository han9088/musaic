import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musaic/features/indiebase/indiebase_scope.dart';
import 'package:musaic/services/indiebase_runtime.dart';

void main() {
  const baseUrl = 'https://musaic.example.invalid';
  const apiKey = 'ib_pk_example';

  test('the runtime requires a URL and a project key', () {
    expect(
      IndiebaseRuntime.fromEnvironment(baseUrl: '', apiKey: apiKey),
      isNull,
    );
    expect(
      IndiebaseRuntime.fromEnvironment(baseUrl: baseUrl, apiKey: ''),
      isNull,
    );
  });

  testWidgets('mounting the scope leaves the HTTP client unopened', (
    tester,
  ) async {
    final runtime = IndiebaseRuntime.fromEnvironment(
      baseUrl: baseUrl,
      apiKey: apiKey,
    )!;
    addTearDown(runtime.close);
    var clientsCreated = 0;
    late BuildContext lookupContext;

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          IndiebaseScope(
            runtime: runtime,
            child: Builder(
              builder: (context) {
                lookupContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(clientsCreated, 0);

        final client = IndiebaseScope.maybeOf(lookupContext);
        expect(client, isNotNull);
        expect(IndiebaseScope.maybeOf(lookupContext), same(client));
        expect(clientsCreated, 1);
      },
      () {
        clientsCreated++;
        return MockClient((_) => throw StateError('Unexpected HTTP request'));
      },
    );
  });
}
