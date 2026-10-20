import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';

final userJson = <String, dynamic>{
  'id': 1,
  'name': 'Test User',
  'email': 'user@example.test',
  'role': 'employee',
  'timezone': 'UTC',
  'booking_url': 'https://example.test/book/1',
  'booking_username': '1',
  'notification_preferences': {
    'channels': {'in_app': true, 'email': true},
    'categories': <String, dynamic>{},
  },
};

class MemoryApi extends Api {
  bool offline = false, revoked = false;
  Json account = Map.of(userJson);
  @override
  Future<void> restore() async {}
  @override
  Future<void> saveToken(String value) async {
    token = value;
  }

  @override
  Future<void> clearToken() async {
    token = null;
  }

  @override
  Future<Json> request(
    String path, {
    String method = 'GET',
    Json? data,
    Json? query,
  }) async {
    if (offline) throw const ApiFailure('Offline');
    if (path == 'auth/login') return {'token': 'test-token', 'user': userJson};
    if (path == 'auth/logout') {
      revoked = true;
      return {};
    }
    return {'data': account};
  }
}

void main() {
  test('refresh account replaces cached notification preferences', () async {
    final api = MemoryApi()..token = 'test-token';
    final container = ProviderContainer(
      overrides: [apiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);
    expect(container.read(authProvider).value!.preferences.email, true);
    api.account = {
      ...userJson,
      'notification_preferences': {
        'channels': {'in_app': true, 'email': false},
        'categories': <String, dynamic>{},
      },
    };
    await container.read(authProvider.notifier).refreshAccount();
    expect(container.read(authProvider).value!.preferences.email, false);
    expect(api.token, 'test-token');
  });
  test(
    'auth controller restores, signs in, revokes and clears credentials',
    () async {
      final api = MemoryApi();
      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      expect(await container.read(authProvider.future), null);
      await container
          .read(authProvider.notifier)
          .login('user@example.test', 'password');
      expect(container.read(authProvider).value?.id, 1);
      expect(api.token, 'test-token');
      await container.read(authProvider.notifier).logout();
      expect(api.revoked, true);
      expect(api.token, null);
      expect(container.read(authProvider).value, null);
    },
  );
  test(
    'network failure during logout retains token for revocation retry',
    () async {
      final api = MemoryApi()..token = 'test-token';
      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);
      api.offline = true;
      await expectLater(
        container.read(authProvider.notifier).logout(),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.token, 'test-token');
      expect(api.revoked, false);
    },
  );
}
