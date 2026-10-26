import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';

import 'support/fake_backend.dart';

// Production-shaped meeting detail (meeting 28, created on the website with
// two action items).
Map<String, dynamic> meeting28({List<Map<String, dynamic>>? tasks}) => {
  'data': {
    'id': 28,
    'title': '[TEST] Sync Meeting 01',
    'description': 'Sync test 04 - meeting with action item',
    'start_time': '2026-10-27T10:00:00+05:00',
    'end_time': '2026-10-27T10:30:00+05:00',
    'timezone': 'UTC',
    'status': 'scheduled',
    'type': 'virtual',
    'can_manage': true,
    'can_rsvp': true,
    'organizer': {'id': 3, 'name': 'Hammad Developer'},
    'participants': <Object>[],
    'metadata': {'is_client_meeting': true},
    'tasks': tasks ??
        [
          for (final id in [16, 17])
            {
              'id': id,
              'title': '[TEST] Sync Task 01',
              'status': 'todo',
              'priority': 'medium',
              'due_date': '2026-10-28T23:06:00+05:00',
              'meeting_id': 28,
              'assignee': {'id': 3, 'name': 'Hammad Developer'},
            },
        ],
    'client': null,
  },
};

void main() {
  test('a meeting without an agenda does not show its title as the agenda', () {
    final m = Record.fromJson(meeting28()['data'] as Json, Module.meetings);
    expect(m.agenda, isNull);
  });

  test('a meeting with an agenda keeps it', () {
    final m = Record.fromJson({...meeting28()['data'] as Json, 'agenda': 'Pricing review'}, Module.meetings);
    expect(m.agenda, 'Pricing review');
  });

  test('meeting notes still fall back to their title', () {
    final n = Record.fromJson({'id': 5, 'title': 'Kick-off'}, Module.notes);
    expect(n.agenda, 'Kick-off');
  });

  test('a meeting reads its action items', () {
    final m = Record.fromJson(meeting28()['data'] as Json, Module.meetings);
    expect(m.meetingTasks.map((t) => t.id), ['16', '17']);
    expect(m.meetingTasks.first.owner, 'Hammad Developer');
    expect(m.meetingTasks.first.meetingId, 28);
  });

  testWidgets('meeting detail lists its action items and opens one', (tester) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final backend = FakeBackend(user: {...userFixture(), 'id': 3, 'timezone': 'UTC'});
    backend.routes['GET meetings/28'] = (_) => (200, meeting28());
    backend.routes['GET tasks/16'] = (_) => (200, {
      'data': {
        'id': 16,
        'title': '[TEST] Sync Task 01',
        'status': 'todo',
        'priority': 'medium',
        'meeting_id': 28,
        'assignee': {'id': 3, 'name': 'Hammad Developer'},
        'creator': {'id': 3, 'name': 'Hammad Developer'},
      },
    });
    await tester.pumpWidget(harness(backend, RecordScreen(initial: Record.fromJson({'id': 28, 'title': '[TEST] Sync Meeting 01'}, Module.meetings))));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Action items (2)'), findsOneWidget);
    expect(find.text('[TEST] Sync Task 01'), findsNWidgets(2));
    expect(find.textContaining('Todo · Medium · Due'), findsNWidgets(2));
    expect(find.text('Agenda'), findsNothing, reason: 'the title must not be shown as the agenda');
    await tester.tap(find.text('[TEST] Sync Task 01').first);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Update status'), findsOneWidget, reason: 'the task detail opened');
  });

  testWidgets('a meeting without action items shows no empty card', (tester) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    backend.routes['GET meetings/28'] = (_) => (200, meeting28(tasks: const []));
    await tester.pumpWidget(harness(backend, RecordScreen(initial: Record.fromJson({'id': 28, 'title': 'M'}, Module.meetings))));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Action items ('), findsNothing);
    expect(find.text('Create action item'), findsOneWidget);
  });
}
