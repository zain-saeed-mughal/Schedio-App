import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/push.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/booking/booking_screen.dart';
import 'package:schedio_mobile/features/pipeline/pipeline_screen.dart';
import 'package:schedio_mobile/features/settings/settings_screen.dart';
import 'package:schedio_mobile/features/workspace/approval_screen.dart';

import 'support/fake_backend.dart';

Map<String, dynamic> productionClient({String status = 'discovery'}) => {
  'id': 7,
  'company_name': 'Sample Logistics',
  'contact_name': 'Sample Contact',
  'contact_email': 'contact@example.test',
  'contact_phone': '+1 555 0100',
  'contact_role': 'Lead',
  'campaign': 'Direct Outreach',
  'progress': 'Contract in review',
  'status': status,
  'status_label': 'Discovery',
  'deal_value': 75000.0,
  'notes': 'Sample',
  'last_activity_at': '2026-10-22T12:00:00+00:00',
  'assigned_to': {'id': 3, 'name': 'Sample Owner'},
  'created_by': {'id': 1, 'name': 'Sample Creator'},
  'can_manage': true,
};

Map<String, dynamic> productionSlots(DateTime day) => {
  'date': '${day.year}-${'${day.month}'.padLeft(2, '0')}-${'${day.day}'.padLeft(2, '0')}',
  'duration': 15,
  'slots': [
    for (final h in [9, 10, 11])
      {
        'start_time': '${day.year}-${'${day.month}'.padLeft(2, '0')}-${'${day.day}'.padLeft(2, '0')}T${'$h'.padLeft(2, '0')}:00:00+05:00',
        'end_time': '${day.year}-${'${day.month}'.padLeft(2, '0')}-${'${day.day}'.padLeft(2, '0')}T${'$h'.padLeft(2, '0')}:15:00+05:00',
        'formatted_time': '$h:00 am',
        'time_24': '${'$h'.padLeft(2, '0')}:00',
      },
  ],
  'total_available': 3,
};

const productionProfile = {
  'data': {
    'id': 8,
    'name': 'Sample Host',
    'title': null,
    'avatar_url': null,
    'timezone': 'Asia/Karachi',
    'booking_headline': 'Book a meeting with me',
    'booking_bio': null,
    'durations': [15, 30, 45, 60],
    'default_duration': 15,
  },
};

void main() {
  setUpAll(prepareWidgetTests);

  group('bug 1: clients and pipeline', () {
    test('a production client with object assignee and creator parses', () {
      final r = Record.fromJson(productionClient(), Module.clients);
      expect(r.assignedTo, 3);
      expect(r.owner, 'Sample Owner');
      expect(r.dealValue, '75000.0');
      expect(r.status, 'discovery');
    });

    test('meetings with room, department and client objects parse', () {
      final r = Record.fromJson({
        'id': 1,
        'title': 'Planning',
        'room': {'id': 4, 'name': 'Boardroom', 'location': 'Floor 4'},
        'department': {'id': 2, 'name': 'Engineering'},
        'client_id': '9',
        'organizer': {'id': 1, 'name': 'Sample Organizer'},
        'participants': [
          {'id': 1, 'name': 'Sample', 'role': 'host', 'status': 'accepted', 'response_notes': null},
        ],
        'metadata': <dynamic>[],
      }, Module.meetings);
      expect((r.roomId, r.departmentId, r.clientId), (4, 2, 9));
      expect(r.owner, 'Sample Organizer');
    });

    test('rooms accept amenities as strings or objects, attachments as strings or objects', () {
      final r = Record.fromJson({
        'id': 2,
        'name': 'Apollo',
        'capacity': '12',
        'amenities': ['Projector', {'name': 'Whiteboard'}],
        'attachments': ['https://example.test/a', {'name': 'Spec', 'url': 'https://example.test/b'}],
      }, Module.rooms);
      expect(r.capacity, 12);
      expect(r.amenities, ['Projector', 'Whiteboard']);
      expect(r.attachments, ['https://example.test/a', 'https://example.test/b']);
    });

    test('pagination numbers sent as strings still work', () {
      final page = RecordPage.fromJson({
        'data': [productionClient()],
        'meta': {'current_page': '1', 'last_page': '3', 'per_page': '100', 'total': '41'},
      }, Module.clients);
      expect((page.page, page.lastPage, page.total), (1, 3, 41));
    });

    testWidgets('the pipeline board renders production clients without a type error', (tester) async {
      phoneSize(tester, height: 1400);
      final backend = FakeBackend();
      backend.routes['GET clients'] = (o) => (
        200,
        {
          'data': o.queryParameters['status'] == 'discovery' ? [productionClient()] : <dynamic>[],
          'meta': {'current_page': 1, 'last_page': 1, 'per_page': 100, 'total': o.queryParameters['status'] == 'discovery' ? 1 : 0},
        },
      );
      await tester.pumpWidget(harness(backend, const PipelineScreen()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorPanel), findsNothing);
      expect(find.textContaining('subtype'), findsNothing);
      expect(find.text('Sample Logistics'), findsWidgets);
    });
  });

  group('bug 3: public booking', () {
    test('the booking profile reads the production field names', () {
      final p = BookingProfile.fromJson(productionProfile['data']!);
      expect(p.headline, 'Book a meeting with me');
      expect(p.timezone, 'Asia/Karachi');
      expect(p.durations, [15, 30, 45, 60]);
      expect(p.defaultDuration, 15);
    });

    Future<FakeBackend> openBooking(WidgetTester tester, (int, Object?) Function() slots) async {
      phoneSize(tester, height: 1800);
      final backend = FakeBackend();
      backend.routes['GET public/booking/host'] = (_) => (200, productionProfile);
      backend.routes['GET public/booking/host/slots'] = (_) => slots();
      await tester.pumpWidget(harness(backend, const BookingScreen()));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).first, 'host');
      await tester.ensureVisible(find.text('Open booking profile'));
      await tester.tap(find.text('Open booking profile'));
      await settle(tester);
      return backend;
    }

    testWidgets('the production slots reply shows the slots', (tester) async {
      final backend = await openBooking(tester, () => (200, productionSlots(DateTime.now())));
      expect(find.textContaining('could not read'), findsNothing);
      expect(find.text('No available slots'), findsNothing);
      expect(find.byType(SlotPill), findsNWidgets(4 + 3), reason: '4 durations and 3 slots');
      final request = backend.requests.lastWhere((r) => r.path.endsWith('/slots'));
      expect(request.queryParameters['duration'], 15, reason: 'uses the server default duration');
    });

    testWidgets('an API error is shown as an error, never as "No available slots"', (tester) async {
      await openBooking(tester, () => (500, {'message': 'Server Error'}));
      expect(find.text('No available slots'), findsNothing);
      expect(find.textContaining('server had a problem'), findsOneWidget);
    });

    testWidgets('a genuinely empty day shows "No available slots"', (tester) async {
      await openBooking(tester, () => (200, {'date': '2026-10-24', 'duration': 15, 'slots': <dynamic>[], 'total_available': 0}));
      expect(find.text('No available slots'), findsOneWidget);
    });
  });

  group('bug 2: notification settings', () {
    Future<void> openSettings(WidgetTester tester, {required bool enabled, String? token, PushStatus? status}) async {
      phoneSize(tester, height: 1400);
      final backend = FakeBackend();
      final push = PushService(
        Api(client: Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))..httpClientAdapter = backend),
        const DisabledPushTransport(),
        enabled: enabled,
      )..registeredToken = token;
      push.status.value = status ?? (token != null ? PushStatus.active : PushStatus.off);
      await tester.pumpWidget(
        harness(backend, const SettingsScreen(), overrides: [pushServiceProvider.overrideWithValue(push)]),
      );
      await settle(tester);
    }

    testWidgets('a push-enabled, registered device says push is on', (tester) async {
      await openSettings(tester, enabled: true, token: 'registered');
      expect(find.text('Push notifications'), findsOneWidget);
      expect(find.textContaining('not enabled'), findsNothing);
      expect(find.text('Device alerts'), findsNothing);
      expect(find.textContaining('On for this device'), findsOneWidget);
    });

    testWidgets('a push build still connecting says so instead of offering device alerts', (tester) async {
      await openSettings(tester, enabled: true, status: PushStatus.connecting);
      expect(find.textContaining('Setting up'), findsOneWidget);
      expect(find.text('Device alerts'), findsNothing);
    });

    testWidgets('a push build with notifications blocked explains how to turn it on', (tester) async {
      await openSettings(tester, enabled: true, status: PushStatus.blocked);
      expect(find.textContaining('Allow notifications for Schedio'), findsOneWidget);
      expect(find.textContaining('not enabled'), findsNothing);
    });

    testWidgets('a build without push offers device alerts and never claims push', (tester) async {
      await openSettings(tester, enabled: false);
      expect(find.text('Device alerts'), findsOneWidget);
      expect(find.text('Push notifications'), findsNothing);
    });
  });

  test('approval options accept role objects and a data wrapper', () async {
    final backend = FakeBackend();
    backend.routes['GET admin/registration-requests/21/options'] = (_) => (
      200,
      {
        'data': {
          'applicant': {'id': 21},
          'roles': [
            {'key': 'manager', 'label': 'Department Manager'},
            'employee',
          ],
          'departments': [
            {'id': '4', 'name': 'Engineering'},
          ],
        },
      },
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))..httpClientAdapter = backend;
    final options = resultOf(await Api(client: dio).request('admin/registration-requests/21/options'));
    expect(options['roles'], hasLength(2));
    expect(asInt((options['departments'] as List).first), 4);
    expect(approvalOptionsProvider, isNotNull);
  });
}
