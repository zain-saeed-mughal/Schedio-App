import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/api.dart';

import 'support/fake_backend.dart';

Repository repo(FakeBackend backend) => Repository(
  Api(client: Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))..httpClientAdapter = backend)..token = 'session',
);

Map<String, dynamic> dashboard(int unread) => {
  'data': {
    'metrics': {'today_meetings_count': 0, 'upcoming_meetings': 1, 'pending_tasks': 0, 'unread_notifications': unread, 'active_reminders': unread},
    'today_meetings': <Object>[],
    'upcoming_meetings': <Object>[],
  },
};

void main() {
  test('the badge follows the inbox when the dashboard metric disagrees (production: 11 vs an empty inbox)', () async {
    final backend = FakeBackend();
    backend.routes['GET dashboard'] = (_) => (200, dashboard(11));
    backend.routes['GET notifications'] = (_) => (200, {
      'data': <Object>[],
      'meta': {'current_page': 1, 'last_page': 1, 'per_page': 1, 'total': 0, 'unread_count': 0},
    });
    expect((await repo(backend).dashboard()).unread, 0);
  });

  test('the badge shows the inbox unread count', () async {
    final backend = FakeBackend();
    backend.routes['GET dashboard'] = (_) => (200, dashboard(0));
    backend.routes['GET notifications'] = (_) => (200, {
      'data': <Object>[],
      'meta': {'current_page': 1, 'last_page': 3, 'per_page': 1, 'total': 3, 'unread_count': 3},
    });
    expect((await repo(backend).dashboard()).unread, 3);
  });

  test('if the inbox cannot be read, the dashboard metric is kept', () async {
    final backend = FakeBackend();
    backend.routes['GET dashboard'] = (_) => (200, dashboard(4));
    backend.routes['GET notifications'] = (_) => (500, {'message': 'Server Error'});
    expect((await repo(backend).dashboard()).unread, 4);
  });
}
