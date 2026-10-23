import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/models.dart';

void main() {
  test('an account with null role, status or timezone still loads', () {
    final a = Account.fromJson({'id': '8', 'name': 'Mobile App Tester', 'email': null, 'role': null, 'timezone': null, 'status': null});
    expect(a.id, 8);
    expect(a.role, '');
    expect(a.timezone, 'UTC');
  });

  test('a calendar entry without an end time gets a one hour block', () {
    final e = CalendarEntry.fromJson({'id': 3, 'title': null, 'entity_type': 'event', 'start_time': '2026-12-20T10:00:00+05:00'});
    expect(e.title, 'Untitled');
    expect(e.end.difference(e.start), const Duration(hours: 1));
  });

  test('legacy dashboard numbers given as strings are read', () {
    final d = Dashboard.fromJson({'today_meetings': '2', 'upcoming_meetings': 3, 'pending_tasks': null, 'unread_notifications': '10', 'meetings': null});
    expect([d.today, d.upcoming, d.tasks, d.unread], [2, 3, 0, 10]);
    expect(d.meetings, isEmpty);
  });
}
