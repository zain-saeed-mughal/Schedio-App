import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';

import 'meeting_detail_test.dart' show meeting28;
import 'support/fake_backend.dart';

/// A meeting note exactly as production now embeds it in `GET meetings/{id}`
/// (field names and types from the 2026-10-27 read-only probe; values are
/// test placeholders).
Map<String, dynamic> embeddedNote({int id = 7, int meetingId = 11}) => {
  'id': id,
  'meeting_id': meetingId,
  'user_id': 3,
  'agenda': '[TEST] Agenda',
  'discussion': '[TEST] Discussion',
  'decisions': '[TEST] Decisions',
  'action_items': <Object>[],
  'follow_up_date': null,
  'attachments': <Object>[],
  'can_manage': true,
  'author': {'id': 3, 'name': 'Hammad Developer'},
  'created_at': '2026-10-20T09:00:00+00:00',
  'updated_at': '2026-10-20T09:00:00+00:00',
};

Map<String, dynamic> meetingWithNotes(List<Map<String, dynamic>> notes, {int id = 11}) => {
  'data': {...meeting28()['data'] as Json, 'id': id, 'title': '[TEST] Meeting $id', 'notes': notes, 'tasks': <Object>[]},
};

const couldNotRead = 'The server sent a response this app could not read. Please try again later.';

Future<void> pumpFor(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(prepareWidgetTests);

  group('meeting detail parsing (production shape)', () {
    test('ROOT CAUSE: a meeting whose `notes` is a list of note objects parses (meeting 11 shape)', () {
      final m = Record.fromJson(meetingWithNotes([embeddedNote()])['data'] as Json, Module.meetings);
      expect(m.id, '11');
      expect(m.notes, isNull, reason: 'a list is not note text');
      expect(m.meetingNotes, hasLength(1));
      expect(m.meetingNotes.first.module, Module.notes);
      expect(m.meetingNotes.first.agenda, '[TEST] Agenda');
      expect(m.meetingNotes.first.owner, 'Hammad Developer');
    });

    test('an empty `notes` list parses (meeting 28 shape)', () {
      final m = Record.fromJson(meetingWithNotes(const [], id: 28)['data'] as Json, Module.meetings);
      expect(m.meetingNotes, isEmpty);
      expect(m.title, '[TEST] Meeting 28');
    });

    test('clients still read `notes` as text', () {
      final c = Record.fromJson({'id': 14, 'company_name': '[TEST] Sync Client 01', 'notes': 'Call back Monday', 'status': 'scheduled'}, Module.clients);
      expect(c.notes, 'Call back Monday');
      expect(c.meetingNotes, isEmpty);
    });

    test('unexpected types in optional fields do not break a meeting', () {
      final m = Record.fromJson({
        'id': 99,
        'title': '[TEST] Odd types',
        'status': 'scheduled',
        'location': {'name': 'Room A'},
        'meeting_link': 42,
        'type': ['virtual'],
        'timezone': null,
        'agenda': {'text': 'x'},
        'participants': [3, {'id': 4, 'name': 'Tester'}, null],
        'metadata': {'is_client_meeting': false, 'client_name': 7},
        'organizer': {'id': 3, 'name': 12},
      }, Module.meetings);
      expect(m.title, '[TEST] Odd types');
      expect(m.location, isNull);
      expect(m.meetingLink, '42');
      expect(m.type, isNull);
      expect(m.agenda, isNull);
      expect(m.participants.map((p) => p.id), [4]);
      expect(m.clientName, '7');
    });

    test('a numeric title or status is shown as text instead of failing', () {
      final m = Record.fromJson({'id': 1, 'title': 2026, 'status': 1}, Module.meetings);
      expect(m.title, '2026');
      expect(m.status, '1');
    });
  });

  group('My Meetings screens', () {
    testWidgets('My Meetings -> meeting 11 (embedded notes) opens its detail with no read error', (tester) async {
      phoneSize(tester, height: 2400);
      final backend = FakeBackend(user: {...userFixture(), 'id': 3, 'timezone': 'UTC'});
      backend.routes['GET meetings'] = (_) => (200, {
        'data': [
          {...meeting28()['data'] as Json, 'id': 11, 'title': '[TEST] Meeting 11', 'tasks': null},
          {...meeting28()['data'] as Json, 'tasks': null},
        ],
        'meta': {'current_page': 1, 'last_page': 1, 'total': 2},
      });
      backend.routes['GET meetings/11'] = (_) => (200, meetingWithNotes([embeddedNote()]));
      await tester.pumpWidget(harness(backend, const RecordsScreen(module: Module.meetings)));
      await settle(tester);
      expect(find.text('[TEST] Meeting 11'), findsOneWidget);
      expect(find.text('[TEST] Sync Meeting 01'), findsOneWidget);
      await tester.tap(find.text('[TEST] Meeting 11'));
      await pumpFor(tester);
      expect(find.text(couldNotRead), findsNothing);
      expect(find.byType(ErrorPanel), findsNothing);
      expect(find.text('Meeting notes (1)'), findsOneWidget);
      expect(find.text('Create action item'), findsOneWidget);
    });

    testWidgets('a 500 on a meeting detail shows a server error, and Try again loads it', (tester) async {
      phoneSize(tester, height: 2400);
      final backend = FakeBackend();
      var fail = true;
      var calls = 0;
      backend.routes['GET meetings/11'] = (_) {
        calls++;
        return fail ? (500, {'message': 'Server Error'}) : (200, meetingWithNotes([embeddedNote()]));
      };
      await tester.pumpWidget(harness(backend, RecordScreen(initial: Record.fromJson({'id': 11, 'title': '[TEST] Meeting 11'}, Module.meetings))));
      await pumpFor(tester);
      expect(find.text('The Schedio server had a problem. Please try again shortly.'), findsOneWidget);
      expect(find.text(couldNotRead), findsNothing, reason: 'a 500 is not a parse error');
      final before = calls;
      fail = false;
      await tester.tap(find.text('Try again'));
      await pumpFor(tester);
      expect(calls, before + 1);
      expect(find.byType(ErrorPanel), findsNothing, reason: 'no stale error after a successful retry');
      expect(find.text('Meeting notes (1)'), findsOneWidget);
    });

    testWidgets('parse, network and server errors on My Meetings show different messages', (tester) async {
      phoneSize(tester, height: 2400);
      Future<String?> messageFor(void Function(FakeBackend) setup) async {
        final backend = FakeBackend();
        setup(backend);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(harness(backend, const RecordsScreen(module: Module.meetings)));
        await settle(tester);
        // Network failures are retried 3 times (2, 4 and 6 s) before the error shows.
        if (backend.offline) await pumpFor(tester, 160);
        final panel = find.byType(ErrorPanel);
        return panel.evaluate().isEmpty ? null : tester.widget<ErrorPanel>(panel.first).message;
      }

      expect(await messageFor((b) => b.routes['GET meetings'] = (_) => (200, {'data': 'not a list'})), couldNotRead);
      expect(await messageFor((b) => b.routes['GET meetings'] = (_) => (500, {'message': 'Server Error'})),
          'The Schedio server had a problem. Please try again shortly.');
      expect(await messageFor((b) => b.offline = true), startsWith('Could not reach the Schedio server'));
    });

    testWidgets('a real empty list shows the empty state, not an error', (tester) async {
      phoneSize(tester, height: 2400);
      final backend = FakeBackend();
      backend.routes['GET meetings'] = (_) => (200, {'data': <Object>[], 'meta': {'current_page': 1, 'last_page': 1, 'total': 0}});
      await tester.pumpWidget(harness(backend, const RecordsScreen(module: Module.meetings)));
      await settle(tester);
      expect(find.byType(ErrorPanel), findsNothing);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });
  });
}
