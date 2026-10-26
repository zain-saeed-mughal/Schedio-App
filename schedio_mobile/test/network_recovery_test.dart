import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';

import 'env_and_errors_test.dart' show ScriptedAdapter, json;

/// Fails the first [failures] requests with a connection error, then answers.
(Api, List<String>) flakyApi({int failures = 1, int status = 200}) {
  final calls = <String>[];
  var left = failures;
  final api = Api(
    client: Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
      ..httpClientAdapter = ScriptedAdapter((o) {
        calls.add('${o.method} ${o.path}');
        if (left-- > 0) {
          throw DioException.connectionError(
            requestOptions: o,
            reason: 'Failed host lookup',
            error: const SocketException('Failed host lookup'),
          );
        }
        return json({'data': <Object>[]}, status);
      }),
  )..retryPause = Duration.zero;
  return (api, calls);
}

void main() {
  group('reconnect after a network drop', () {
    test('a read that hits a connection error is retried once and succeeds', () async {
      final (api, calls) = flakyApi(failures: 1);
      expect(await api.request('meetings'), {'data': <Object>[]});
      expect(calls, ['GET meetings', 'GET meetings']);
    });

    test('a read that still fails after one retry reports the connection problem', () async {
      final (api, calls) = flakyApi(failures: 2);
      await expectLater(
        api.request('meetings'),
        throwsA(isA<ApiFailure>().having((e) => e.message, 'message', contains('Could not reach the Schedio server'))),
      );
      expect(calls, hasLength(2));
    });

    test('writes are never retried automatically', () async {
      final (api, calls) = flakyApi(failures: 1);
      await expectLater(api.request('meetings', method: 'POST', data: {'title': 'x'}), throwsA(isA<ApiFailure>()));
      expect(calls, ['POST meetings']);
    });

    test('server errors are not retried', () async {
      final calls = <String>[];
      final api = Api(
        client: Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
          ..httpClientAdapter = ScriptedAdapter((o) {
            calls.add(o.path);
            return json({'message': 'Server Error'}, 500);
          }),
      )..retryPause = Duration.zero;
      await expectLater(api.request('meetings/11'), throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 500)));
      expect(calls, hasLength(1));
    });
  });

  group('automatic retry policy for screens', () {
    const network = ApiFailure('Could not reach the Schedio server.');
    test('network failures retry up to 3 times, a few seconds apart', () {
      expect([for (var i = 0; i < 4; i++) schedioRetry(i, network)], [
        const Duration(seconds: 2),
        const Duration(seconds: 4),
        const Duration(seconds: 6),
        null,
      ]);
    });
    test('server answers are shown at once, not retried', () {
      for (final status in [401, 403, 404, 422, 500]) {
        expect(schedioRetry(0, ApiFailure('x', status: status)), isNull, reason: '$status');
      }
      expect(schedioRetry(0, StateError('bug')), isNull);
    });
  });

  testWidgets('Try again after an error shows loading, then the data', (tester) async {
    var attempts = 0;
    final gate = <int, Future<String>>{};
    final provider = FutureProvider.autoDispose<String>((ref) {
      attempts++;
      if (attempts == 1) return Future.error(const ApiFailure('Could not reach the Schedio server.'));
      return gate[attempts] ??= Future<String>.delayed(const Duration(seconds: 2), () => 'loaded');
    });
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => AsyncBody<String>(
                value: ref.watch(provider),
                retry: () => ref.invalidate(provider),
                builder: Text.new,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Try again'), findsNothing, reason: 'the old error must not stay on screen while retrying');
    expect(find.byType(SchedioLoadingIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('loaded'), findsOneWidget);
  });
}
