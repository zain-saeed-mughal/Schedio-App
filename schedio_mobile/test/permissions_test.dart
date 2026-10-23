import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';

import 'support/fake_backend.dart';

// Production task detail (2026-10-24): no can_manage field.
Map<String, dynamic> productionTask({int assignee = 8, int creator = 8}) => {
  'data': {
    'id': 41,
    'title': '[TEST] Task',
    'description': null,
    'status': 'pending',
    'priority': 'low',
    'due_date': '2026-12-20T15:00:00+05:00',
    'completed_at': null,
    'meeting_id': null,
    'assignee': {'id': assignee, 'name': 'Assignee'},
    'creator': {'id': creator, 'name': 'Creator'},
    'meeting': null,
  },
};

Account account({required int id, bool admin = false, bool rooms = false}) =>
    Account.fromJson({...userFixture(admin: admin), 'id': id, 'can_manage_rooms': rooms});

void main() {
  group('who may manage a record when the server omits can_manage', () {
    Record task({int assignee = 8, int creator = 8}) => Record.fromJson(productionTask(assignee: assignee, creator: creator)['data'] as Json, Module.tasks);

    test('administrators may', () => expect(task(assignee: 2, creator: 3).canManageAs(account(id: 9, admin: true)), isTrue));
    test('the assignee may', () => expect(task(assignee: 9, creator: 3).canManageAs(account(id: 9)), isTrue));
    test('the creator may', () => expect(task(assignee: 2, creator: 9).canManageAs(account(id: 9)), isTrue));
    test('other employees may not', () => expect(task(assignee: 2, creator: 3).canManageAs(account(id: 9)), isFalse));
    test('room managers may manage rooms', () {
      final room = Record.fromJson({'id': 1, 'name': 'Suite'}, Module.rooms);
      expect(room.canManageAs(account(id: 9, rooms: true)), isTrue);
      expect(room.canManageAs(account(id: 9)), isFalse);
    });
    test('the server decides when it sends can_manage', () {
      final m = Record.fromJson({'id': 1, 'title': 'M', 'can_manage': false, 'organizer': {'id': 9}}, Module.meetings);
      expect(m.canManageAs(account(id: 9, admin: true)), isFalse);
    });
  });

  testWidgets('a production task shows status, Edit and Delete to its assignee', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final backend = FakeBackend(user: {...userFixture(role: 'employee', admin: false), 'id': 8});
    backend.routes['GET tasks/41'] = (_) => (200, productionTask(assignee: 8, creator: 3));
    await tester.pumpWidget(harness(backend, RecordScreen(initial: Record.fromJson({'id': 41, 'title': 'Task'}, Module.tasks))));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.widgetWithText(FilterPill, 'Completed'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('another employee sees the task read-only', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final backend = FakeBackend(user: {...userFixture(role: 'employee', admin: false), 'id': 9});
    backend.routes['GET tasks/41'] = (_) => (200, productionTask(assignee: 8, creator: 3));
    await tester.pumpWidget(harness(backend, RecordScreen(initial: Record.fromJson({'id': 41, 'title': 'Task'}, Module.tasks))));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.widgetWithText(FilterPill, 'Completed'), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });
}
