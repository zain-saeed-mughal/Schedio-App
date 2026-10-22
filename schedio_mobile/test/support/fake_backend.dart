import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/device_alerts.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:timezone/data/latest.dart' as tz;

final _now = DateTime.now().toUtc();
String _at(Duration d) => _now.add(d).toIso8601String();

Map<String, dynamic> userFixture({String role = 'super_admin', bool admin = true}) => {
  'id': 1,
  'name': 'Ayesha Khan',
  'email': 'ayesha@example.test',
  'role': role,
  'timezone': 'UTC',
  'company': {'name': 'Example Company'},
  'booking_url': 'https://example.test/book/ayesha',
  'booking_username': 'ayesha',
  'can_administer': admin,
  'can_manage_rooms': admin,
  'notification_preferences': {
    'channels': {'in_app': true, 'email': false},
    'categories': <String, dynamic>{},
  },
};

final meetingFixtures = [
  {
    'id': 11,
    'title': 'Quarterly roadmap review',
    'status': 'scheduled',
    'start_time': _at(const Duration(hours: 2)),
    'end_time': _at(const Duration(hours: 3)),
    'organizer': {'id': 1, 'name': 'Ayesha Khan'},
    'can_manage': true,
    'can_rsvp': true,
    'participants': [
      {'id': 1, 'name': 'Ayesha Khan', 'status': 'pending'},
    ],
  },
  {
    'id': 12,
    'title': 'Discovery call with Northwind',
    'status': 'scheduled',
    'start_time': _at(const Duration(hours: 5)),
    'end_time': _at(const Duration(hours: 6)),
    'organizer': {'id': 1, 'name': 'Ayesha Khan'},
  },
];

final requestFixtures = [
  {
    'id': 21,
    'name': 'Hamza Riaz',
    'email': 'hamza@example.test',
    'title': 'Frontend Engineer',
    'role': 'employee',
    'approval_status': 'pending',
    'created_at': _at(const Duration(hours: -2)),
  },
];

final notificationFixtures = [
  {
    'id': 'n1',
    'read_at': null,
    'data': {'title': 'Bilal accepted your invite', 'message': 'Quarterly roadmap review', 'meeting_id': 11},
  },
];

List<Map<String, dynamic>> clientFixtures(String status) => status == 'discovery'
    ? [
        {
          'id': 31,
          'company_name': 'Northwind Traders',
          'contact_name': 'Omar Farooq',
          'status': 'discovery',
          'deal_value': 42000,
          'can_manage': true,
        },
      ]
    : [];

class FakeBackend implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final routes = <String, FutureOr<(int, Object?)> Function(RequestOptions)>{};
  bool offline = false;
  final Map<String, dynamic> user;
  FakeBackend({Map<String, dynamic>? user}) : user = user ?? userFixture();

  RequestOptions? lastWrite() =>
      requests.lastWhere((r) => r.method != 'GET', orElse: () => RequestOptions());

  Object? respond(RequestOptions o) {
    final p = o.path;
    final page = {'current_page': 1, 'last_page': 1};
    if (o.method != 'GET') return {'message': 'Saved successfully.'};
    if (p == 'auth/me') return {'data': user};
    if (p == 'dashboard') {
      return {
        'data': {
          'today_meetings': 2,
          'upcoming_meetings': 7,
          'pending_tasks': 4,
          'unread_notifications': 1,
          'meetings': meetingFixtures,
        },
      };
    }
    if (p == 'clients') {
      final list = clientFixtures('${o.queryParameters['status']}');
      return {'data': list, 'meta': {...page, 'total': list.length}};
    }
    if (p == 'admin/registration-requests') {
      final list = o.queryParameters['status'] == 'pending' ? requestFixtures : [];
      return {'data': list, 'total': list.length, ...page};
    }
    if (p == 'meetings') return {'data': meetingFixtures, 'meta': {...page, 'total': 2}};
    if (p == 'meetings/11') return {'data': meetingFixtures.first};
    if (p == 'notifications') return {'data': notificationFixtures, 'meta': {...page, 'total': 1}};
    if (p == 'calendar/feed') {
      return {
        'data': [
          for (final m in meetingFixtures)
            {
              'id': m['id'],
              'title': m['title'],
              'entity_type': 'meeting',
              'start_time': m['start_time'],
              'end_time': m['end_time'],
            },
        ],
      };
    }
    if (p == 'lookups') {
      return {
        'data': {'users': [], 'departments': [], 'rooms': [], 'clients': []},
      };
    }
    if (p.startsWith('tasks/')) {
      return {
        'data': {'id': 41, 'title': 'Send proposal', 'status': 'todo', 'priority': 'high', 'can_manage': true},
      };
    }
    return {'data': [], 'meta': {...page, 'total': 0}};
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests.add(o);
    if (offline) {
      throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
    }
    final route = routes['${o.method} ${o.path}'];
    final (status, body) = route != null ? await route(o) : (200, respond(o));
    return ResponseBody.fromString(
      status == 204 ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FixtureAuth extends AuthController {
  final Map<String, dynamic> user;
  FixtureAuth(this.user);
  @override
  Future<Account?> build() async => Account.fromJson(user);
}

Future<void> prepareWidgetTests() async {
  AppMotion.ambient = false;
  tz.initializeTimeZones();
  final font = FontLoader('Plus Jakarta Sans')
    ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
  await font.load();
}

void phoneSize(WidgetTester tester, {double height = 900}) {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget harness(FakeBackend backend, Widget child, {List<dynamic> overrides = const []}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
    ..httpClientAdapter = backend;
  final api = Api(client: dio)..token = 'test-token';
  return ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(api),
      authProvider.overrideWith(() => FixtureAuth(backend.user)),
      deviceAlertsProvider.overrideWithValue(SilentAlerts()),
      ...overrides.cast(),
    ],
    child: MaterialApp(theme: schedioTheme(), home: child),
  );
}

class SilentAlerts extends DeviceAlerts {
  @override
  Future<bool> enabled(int userId) async => false;
  @override
  Future<bool> setEnabled(int userId, bool enabled) async => enabled;
  @override
  Future<void> sync(Api api, Account account) async {}
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pumpAndSettle(const Duration(seconds: 1));
}
