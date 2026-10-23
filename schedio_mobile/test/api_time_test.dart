import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('times are sent as wall-clock time in the account timezone with its offset', () {
    // 10:00 UTC is 15:00 in Karachi; the server stores the wall-clock part.
    final instant = DateTime.utc(2026, 12, 20, 10);
    expect(apiTime(instant, 'Asia/Karachi'), '2026-12-20T15:00:00+05:00');
    expect(apiTime(instant, 'America/New_York'), '2026-12-20T05:00:00-05:00');
    expect(apiTime(instant, 'UTC'), '2026-12-20T10:00:00+00:00');
    expect(apiTime(instant, 'Asia/Kolkata'), '2026-12-20T15:30:00+05:30');
  });

  test('the sent time reads back as the same instant', () {
    final instant = DateTime.utc(2026, 7, 1, 8, 45);
    for (final zone in ['Asia/Karachi', 'Europe/London', 'America/Los_Angeles', 'UTC']) {
      expect(DateTime.parse(apiTime(instant, zone)).toUtc(), instant, reason: zone);
    }
  });

  test('isoWithOffset never uses Z', () {
    expect(isoWithOffset(DateTime.utc(2026, 1, 2, 3, 4, 5)), '2026-01-02T03:04:05+00:00');
  });

  test('tasks read the assignee object', () {
    final r = Record.fromJson({
      'id': 4,
      'title': '[TEST] Task',
      'status': 'pending',
      'assignee': {'id': 8, 'name': 'Mobile App Tester'},
    }, Module.tasks);
    expect(r.assignedTo, 8);
    expect(r.owner, 'Mobile App Tester');
  });
}
