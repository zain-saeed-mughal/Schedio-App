import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/features/authentication/auth_screen.dart';
import 'package:schedio_mobile/features/calendar/calendar_screen.dart';
import 'package:schedio_mobile/features/workspace/editor.dart';
import 'package:schedio_mobile/theme/app_theme.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:timezone/data/latest.dart' as tz;

class FixtureAuth extends AuthController {
  @override
  Future<Account?> build() async => Account.fromJson({
    'id': 1,
    'name': 'Test user',
    'email': 'test@example.test',
    'role': 'employee',
    'timezone': 'UTC',
    'booking_url': 'https://example.test/book/1',
    'booking_username': '1',
    'notification_preferences': {
      'channels': {'in_app': true, 'email': true},
      'categories': <String, dynamic>{},
    },
  });
}

class FakeAdapter implements HttpClientAdapter {
  RequestOptions? last;
  int status = 200;
  Json response;
  FakeAdapter(this.response);
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    last = o;
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    final font = FontLoader('Plus Jakarta Sans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await font.load();
  });
  test('meeting model preserves nullable fields and UTC instant', () {
    final record = Record.fromJson({
      'id': 9,
      'title': 'Planning',
      'start_time': '2030-10-21T15:00:00+05:00',
      'participants': [
        {'id': 1, 'name': 'Host', 'status': 'accepted'},
      ],
    }, Module.meetings);
    expect(record.start, DateTime.utc(2030, 10, 21, 10));
    expect(record.participants.single.status, 'accepted');
    expect(record.canManage, false);
    expect(record.roomId, null);
  });
  test(
    'repository parses Laravel pagination and attaches bearer token',
    () async {
      final adapter = FakeAdapter({
        'data': [
          {'id': 1, 'title': 'My task', 'status': 'todo'},
        ],
        'meta': {'current_page': 2, 'last_page': 3},
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
        ..httpClientAdapter = adapter;
      final api = Api(client: dio)..token = 'test-token';
      final page = await Repository(api).list(Module.tasks, page: 2);
      expect(page.records.single.title, 'My task');
      expect(page.lastPage, 3);
      expect(adapter.last!.headers['Authorization'], 'Bearer test-token');
      expect(adapter.last!.queryParameters['page'], 2);
    },
  );
  test('public booking requests never send bearer tokens', () async {
    final adapter = FakeAdapter({'data': {}});
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final api = Api(client: dio)..token = 'private-token';
    await api.request('public/booking/host');
    expect(adapter.last!.headers.containsKey('Authorization'), false);
  });
  test('validation errors retain server field message', () async {
    final adapter = FakeAdapter({
      'message': 'Invalid',
      'errors': {
        'start_time': ['Already booked.'],
      },
    })..status = 422;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
      ..httpClientAdapter = adapter;
    await expectLater(
      Api(client: dio).request('meetings', method: 'POST'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'message',
          'Already booked.',
        ),
      ),
    );
  });
  test('account timezone formatting respects DST', () {
    expect(
      dateLabel(DateTime.utc(2030, 7, 1, 12), 'UTC'),
      contains('12:00 PM'),
    );
    expect(
      dateLabel(DateTime.utc(2030, 7, 1, 12), 'America/New_York'),
      contains('8:00 AM'),
    );
    expect(
      dateLabel(DateTime.utc(2030, 1, 1, 12), 'America/New_York'),
      contains('7:00 AM'),
    );
  });
  testWidgets('login validates input before sending a request', (tester) async {
    final adapter = FakeAdapter({});
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
      ..httpClientAdapter = adapter;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(Api(client: dio))],
        child: MaterialApp(
          theme: schedioTheme(Brightness.dark),
          home: const AuthScreen(),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(adapter.last, null);
  });
  testWidgets('small-screen sign in renders without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: schedioTheme(Brightness.dark),
          home: const AuthScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Your day, in focus.'), findsOneWidget);
    await expectLater(
      find.byType(AuthScreen),
      matchesGoldenFile('goldens/sign_in.png'),
    );
  });
  for (final density in [1.0, 1.75]) {
    testWidgets('calendar switches all views at pixel ratio $density', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = density;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final adapter = FakeAdapter({'data': <dynamic>[]});
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
        ..httpClientAdapter = adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiProvider.overrideWithValue(Api(client: dio)),
            authProvider.overrideWith(FixtureAuth.new),
          ],
          child: MaterialApp(
            theme: schedioTheme(Brightness.dark),
            home: const CalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final view in ['Week', 'Day', 'Agenda', 'Month']) {
        await tester.tap(find.text(view));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('A little breathing room'), findsOneWidget);
    });
  }
  for (final module in [
    Module.meetings,
    Module.tasks,
    Module.clients,
    Module.rooms,
    Module.events,
    Module.notes,
  ]) {
    testWidgets('${module.name} editor renders at phone width', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final adapter = FakeAdapter({
        'data': {
          'users': <dynamic>[],
          'departments': <dynamic>[],
          'rooms': <dynamic>[],
          'clients': <dynamic>[],
        },
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
        ..httpClientAdapter = adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiProvider.overrideWithValue(Api(client: dio)),
            authProvider.overrideWith(FixtureAuth.new),
          ],
          child: MaterialApp(
            theme: schedioTheme(Brightness.dark),
            home: Editor(module: module, meetingId: '1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Form), findsOneWidget);
    });
  }
}
