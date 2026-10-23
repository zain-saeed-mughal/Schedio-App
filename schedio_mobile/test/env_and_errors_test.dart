import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/providers.dart';

import 'auth_provider_test.dart' show userJson;

class ScriptedAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) handler;
  ScriptedAdapter(this.handler);
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async => handler(o);
  @override
  void close({bool force = false}) {}
}

ResponseBody json(Object body, int status) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Api apiWith(ResponseBody Function(RequestOptions) handler) => Api(
  client: Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
    ..httpClientAdapter = ScriptedAdapter(handler),
);

Future<String> failureFor(int status, Object body) async {
  try {
    await apiWith((_) => json(body, status)).request('meetings');
  } on ApiFailure catch (e) {
    return e.message;
  }
  fail('Expected a failure');
}

void main() {
  group('environment guard', () {
    test('recognises private and local hosts', () {
      for (final host in [
        'localhost',
        '127.0.0.1',
        '10.0.2.2',
        '192.168.1.20',
        '172.20.0.5',
        'printer.local',
      ]) {
        expect(Env.isPrivateHost(host), isTrue, reason: host);
      }
      for (final host in ['schedio.live', 'staging.schedio.live', '172.32.0.1', '8.8.8.8']) {
        expect(Env.isPrivateHost(host), isFalse, reason: host);
      }
    });

    test('release and production builds reject HTTP and private servers', () {
      for (final url in [
        'http://schedio.live/api/v1/',
        'https://10.0.2.2/api/v1/',
        'https://192.168.0.10/api/v1/',
        'https://localhost/api/v1/',
      ]) {
        expect(
          () => Env.validate(url, environment: AppEnvironment.production, release: true),
          throwsA(isA<EnvironmentError>()),
          reason: url,
        );
        expect(
          () => Env.validate(url, environment: AppEnvironment.development, release: true),
          throwsA(isA<EnvironmentError>()),
          reason: 'release builds stay strict even when APP_ENV is development: $url',
        );
      }
      expect(
        Env.validate('https://staging.schedio.live/api/v1/', environment: AppEnvironment.staging, release: true).host,
        'staging.schedio.live',
      );
    });

    test('development debug builds may use a LAN server over HTTP', () {
      expect(
        Env.validate('http://192.168.1.20:8090/api/v1/', environment: AppEnvironment.development, release: false).port,
        8090,
      );
    });

    test('the API path must be the versioned mobile API', () {
      expect(
        () => Env.validate('https://schedio.live/', environment: AppEnvironment.production, release: true),
        throwsA(isA<EnvironmentError>()),
      );
      expect(
        () => Env.validate('', environment: AppEnvironment.development, release: false),
        throwsA(isA<EnvironmentError>()),
      );
    });
  });

  group('error messages', () {
    test('server internals are never shown to users', () async {
      expect(
        await failureFor(500, {'message': 'SQLSTATE[42S02]: Base table not found'}),
        'The Schedio server had a problem. Please try again shortly.',
      );
      expect(
        await failureFor(400, {'message': 'ErrorException in /var/www/app/Http/Kernel.php'}),
        'Something went wrong (HTTP 400). Please try again.',
      );
    });

    test('missing mobile API routes get a clear explanation', () async {
      expect(
        await failureFor(404, {'message': 'The route api/v1/auth/login could not be found.'}),
        'This feature is not available on the connected Schedio server yet.',
      );
    });

    test('an HTML 404 from a server without the mobile API is explained', () async {
      final api = apiWith(
        (_) => ResponseBody.fromString('<html>Not Found</html>', 404, headers: {
          Headers.contentTypeHeader: ['text/html'],
        }),
      );
      await expectLater(
        api.request('auth/login', method: 'POST'),
        throwsA(isA<ApiFailure>().having((e) => e.message, 'message', contains('not available'))),
      );
    });

    test('rate limits, validation and permissions are explained', () async {
      expect(await failureFor(429, {'message': 'Too Many Attempts.'}), contains('Too many attempts'));
      expect(
        await failureFor(422, {
          'message': 'Invalid',
          'errors': {
            'start_time': ['This room is already booked.'],
          },
        }),
        'This room is already booked.',
      );
      expect(await failureFor(403, {}), 'You do not have permission to do that.');
    });

    test('network failures and timeouts are distinguished', () async {
      for (final (type, expected) in [
        (DioExceptionType.connectionError, 'Could not reach the Schedio server'),
        (DioExceptionType.receiveTimeout, 'took too long'),
      ]) {
        final api = apiWith((o) => throw DioException(requestOptions: o, type: type));
        await expectLater(
          api.request('dashboard'),
          throwsA(isA<ApiFailure>().having((e) => e.message, 'message', contains(expected))),
        );
      }
    });

    test('non JSON responses are rejected safely', () async {
      final api = apiWith(
        (_) => ResponseBody.fromString('<html>gateway</html>', 200, headers: {
          Headers.contentTypeHeader: ['text/html'],
        }),
      );
      await expectLater(
        api.request('dashboard'),
        throwsA(isA<ApiFailure>().having((e) => e.message, 'message', 'The server returned an unexpected response.')),
      );
    });
  });

  group('session handling', () {
    ProviderContainer containerFor(Api api) {
      final c = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
      addTearDown(c.dispose);
      return c;
    }

    test('an account disabled mid session signs out with the server reason', () async {
      var blocked = false;
      final api = TokenApi(
        (o) => o.path == 'auth/me'
            ? json({'data': userJson}, 200)
            : blocked
            ? json({'message': 'Your company is inactive.', 'account_status': 'inactive'}, 403)
            : json({'data': []}, 200),
      );
      final c = containerFor(api);
      expect((await c.read(authProvider.future))?.id, 1);
      blocked = true;
      await expectLater(c.read(apiProvider).request('dashboard'), throwsA(isA<ApiFailure>()));
      expect(c.read(authProvider).value, isNull);
      expect(api.token, isNull);
      expect(c.read(authNoticeProvider)?.status, 'inactive');
      expect(c.read(authNoticeProvider)?.message, 'Your company is inactive.');
    });

    test('an expired token signs out and explains why', () async {
      final api = TokenApi((o) => json({'message': 'Unauthenticated.'}, 401));
      final c = containerFor(api);
      expect(await c.read(authProvider.future), isNull);
      expect(api.token, isNull);
      expect(c.read(authNoticeProvider)?.status, 'expired');
    });

    test('losing the network on resume keeps the user signed in', () async {
      var offline = false;
      final api = TokenApi(
        (o) => offline
            ? throw DioException(requestOptions: o, type: DioExceptionType.connectionError)
            : json({'data': userJson}, 200),
      );
      final c = containerFor(api);
      expect((await c.read(authProvider.future))?.id, 1);
      offline = true;
      c.invalidate(authProvider);
      expect((await c.read(authProvider.future))?.id, 1);
      expect(api.token, 'stored-token');
    });
  });
}

class TokenApi extends Api {
  TokenApi(ResponseBody Function(RequestOptions) handler)
    : super(
        client: Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
          ..httpClientAdapter = ScriptedAdapter(handler),
      );

  @override
  Future<void> restore() async => token ??= 'stored-token';
  @override
  Future<void> saveToken(String value) async => token = value;
  @override
  Future<void> clearToken() async => token = null;
}

