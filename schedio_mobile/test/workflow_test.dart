import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/authentication/auth_screen.dart';
import 'package:schedio_mobile/features/calendar/calendar_screen.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';

import 'support/fake_backend.dart';

Widget opener(Record record) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => RecordScreen(initial: record)),
        ),
        child: const Text('Open record'),
      ),
    ),
  ),
);

Future<void> openRecordScreen(WidgetTester tester, FakeBackend backend, Record record) async {
  await tester.pumpWidget(harness(backend, opener(record)));
  await tester.tap(find.text('Open record'));
  await settle(tester);
}

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppField && w.label == label),
  matching: find.byType(TextFormField),
);

Record meeting() => Record.fromJson({'id': 11, 'title': 'Quarterly roadmap review'}, Module.meetings);

void main() {
  setUpAll(prepareWidgetTests);

  testWidgets('cancelling a meeting asks first, calls the cancel endpoint and shows the new status', (tester) async {
    phoneSize(tester, height: 1600);
    final backend = FakeBackend();
    var cancelled = false;
    backend.routes['PATCH meetings/11/cancel'] = (_) {
      cancelled = true;
      return (200, {'message': 'Meeting cancelled.'});
    };
    backend.routes['GET meetings/11'] = (_) => (
      200,
      {
        'data': {...meetingFixtures.first, if (cancelled) 'status': 'cancelled'},
      },
    );
    await openRecordScreen(tester, backend, meeting());
    expect(find.text('Scheduled'), findsWidgets);

    await tester.tap(find.widgetWithText(AppButton, 'Cancel meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this meeting?'), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Cancel meeting').last);
    await settle(tester);

    expect(backend.lastWrite()!.method, 'PATCH');
    expect(backend.lastWrite()!.path, 'meetings/11/cancel');
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.widgetWithText(AppButton, 'Cancel meeting'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing the cancel prompt sends nothing', (tester) async {
    phoneSize(tester, height: 1600);
    final backend = FakeBackend();
    await openRecordScreen(tester, backend, meeting());
    await tester.tap(find.widgetWithText(AppButton, 'Cancel meeting'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(backend.requests.where((r) => r.method != 'GET'), isEmpty);
  });

  testWidgets('deleting a meeting calls DELETE and closes the detail screen', (tester) async {
    phoneSize(tester, height: 1600);
    final backend = FakeBackend();
    await openRecordScreen(tester, backend, meeting());
    await tester.tap(find.widgetWithText(AppButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this item?'), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Delete').last);
    await settle(tester);
    expect(backend.lastWrite()!.method, 'DELETE');
    expect(backend.lastWrite()!.path, 'meetings/11');
    expect(find.byType(RecordScreen), findsNothing);
    expect(find.text('Open record'), findsOneWidget);
  });

  testWidgets('a refused delete keeps the screen open and shows the server message', (tester) async {
    phoneSize(tester, height: 1600);
    final backend = FakeBackend();
    backend.routes['DELETE meetings/11'] = (_) => (403, {'message': 'This action is unauthorized.'});
    await openRecordScreen(tester, backend, meeting());
    await tester.tap(find.widgetWithText(AppButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Delete').last);
    await settle(tester);
    expect(find.byType(RecordScreen), findsOneWidget);
    expect(find.byType(InlineBanner), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a meeting the user cannot manage shows no cancel or delete', (tester) async {
    phoneSize(tester, height: 1600);
    final backend = FakeBackend();
    backend.routes['GET meetings/11'] = (_) => (
      200,
      {
        'data': {...meetingFixtures.first, 'can_manage': false},
      },
    );
    await openRecordScreen(tester, backend, meeting());
    expect(find.widgetWithText(AppButton, 'Cancel meeting'), findsNothing);
    expect(find.widgetWithText(AppButton, 'Delete'), findsNothing);
    expect(find.text('Your RSVP'), findsOneWidget);
  });

  testWidgets('room detail loads from rooms/{id} and deletes through the API', (tester) async {
    phoneSize(tester, height: 1600);
    final backend = FakeBackend();
    backend.routes['GET rooms/5'] = (_) => (
      200,
      {
        'data': {
          'id': 5,
          'name': 'Board Room',
          'code': 'BRD',
          'location': 'Floor 3',
          'capacity': 10,
          'amenities': ['Screen'],
          'is_active': true,
          'can_manage': true,
        },
      },
    );
    await openRecordScreen(tester, backend, Record.fromJson({'id': 5, 'name': 'Board Room'}, Module.rooms));
    expect(backend.requests.any((r) => r.method == 'GET' && r.path == 'rooms/5'), isTrue);
    expect(find.text('Board Room'), findsWidgets);
    expect(find.text('Available'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Edit'), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Delete').last);
    await settle(tester);
    expect(backend.lastWrite()!.method, 'DELETE');
    expect(backend.lastWrite()!.path, 'rooms/5');
  });

  testWidgets('event detail loads from events/{id} and shows its category and scope', (tester) async {
    phoneSize(tester, height: 1600);
    final backend = FakeBackend();
    backend.routes['GET events/6'] = (_) => (
      200,
      {
        'data': {
          'id': 6,
          'title': 'Annual offsite',
          'category': 'social',
          'is_company_wide': true,
          'start_time': DateTime.now().toUtc().add(const Duration(days: 3)).toIso8601String(),
          'end_time': DateTime.now().toUtc().add(const Duration(days: 3, hours: 4)).toIso8601String(),
          'can_manage': false,
        },
      },
    );
    await openRecordScreen(tester, backend, Record.fromJson({'id': 6, 'title': 'Annual offsite'}, Module.events));
    expect(backend.requests.any((r) => r.method == 'GET' && r.path == 'events/6'), isTrue);
    expect(find.text('Annual offsite'), findsWidgets);
    expect(find.text('Social'), findsOneWidget);
    expect(find.text('Company wide'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Delete'), findsNothing);
  });

  testWidgets('short meetings fit in the day and week timelines without overflowing', (tester) async {
    phoneSize(tester, height: 1600);
    final backend = FakeBackend();
    final today = DateTime.now().toUtc();
    final start = DateTime.utc(today.year, today.month, today.day, 10);
    backend.routes['GET calendar/feed'] = (_) => (
      200,
      {
        'data': [
          for (final (id, minutes) in [(91, 15), (92, 30), (93, 90)])
            {
              'id': id,
              'title': 'Standup $minutes',
              'entity_type': 'meeting',
              'start_time': start.add(Duration(hours: id - 91)).toIso8601String(),
              'end_time': start.add(Duration(hours: id - 91, minutes: minutes)).toIso8601String(),
            },
        ],
      },
    );
    await tester.pumpWidget(harness(backend, const CalendarScreen()));
    await settle(tester);
    for (final view in ['Day', 'Week']) {
      await tester.tap(find.text(view));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: view);
      expect(find.text('Standup 15'), findsWidgets, reason: view);
    }
  });

  Future<FakeBackend> openRegistration(WidgetTester tester) async {
    phoneSize(tester, height: 2400);
    final backend = FakeBackend();
    backend.routes['GET auth/registration-options'] = (_) => (
      200,
      {
        'data': {
          'companies': [
            {'id': 1, 'name': 'Test Company A'},
          ],
          'departments': [
            {'id': 4, 'company_id': 1, 'name': 'Sales'},
          ],
        },
      },
    );
    await tester.pumpWidget(harness(backend, const AuthScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request Staff Access'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Company A').last);
    await tester.pumpAndSettle();
    await tester.enterText(field('Full name'), 'Sara Malik');
    await tester.enterText(field('Email'), 'sara@example.test');
    await tester.enterText(field('Password'), 'pass-word-123');
    await tester.enterText(field('Confirm password'), 'pass-word-123');
    return backend;
  }

  testWidgets('staff registration sends the company and shows the pending review state', (tester) async {
    final backend = await openRegistration(tester);
    backend.routes['POST auth/register'] = (_) => (
      201,
      {'message': 'Registration submitted for approval.', 'account_status': 'pending'},
    );
    await tester.ensureVisible(find.text('Submit Registration'));
    await tester.tap(find.text('Submit Registration'));
    await tester.pumpAndSettle();
    final write = backend.lastWrite()!;
    expect(write.path, 'auth/register');
    final data = write.data as Map;
    expect(data['registration_type'], 'employee');
    expect(data['company_id'], 1);
    expect(data['name'], 'Sara Malik');
    expect(data['email'], 'sara@example.test');
    expect(data['password_confirmation'], 'pass-word-123');
    expect(find.text('Pending Review'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
  });

  testWidgets('registration shows the server validation message and stays on the form', (tester) async {
    final backend = await openRegistration(tester);
    backend.routes['POST auth/register'] = (_) => (
      422,
      {
        'message': 'The email has already been taken.',
        'errors': {
          'email': ['The email has already been taken.'],
        },
      },
    );
    await tester.ensureVisible(find.text('Submit Registration'));
    await tester.tap(find.text('Submit Registration'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already been taken'), findsWidgets);
    expect(find.text('Submit Registration'), findsOneWidget);
    expect(find.text('Pending Review'), findsNothing);
  });

  testWidgets('registration refuses mismatched passwords before sending', (tester) async {
    final backend = await openRegistration(tester);
    await tester.enterText(field('Confirm password'), 'different-123');
    await tester.ensureVisible(find.text('Submit Registration'));
    await tester.tap(find.text('Submit Registration'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(backend.requests.where((r) => r.method != 'GET'), isEmpty);
  });
}
