import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';

/// Controlled reminder test, step 2: reschedules the approved [TEST] meeting 29
/// so that its stored start is about 35 minutes from now.
///
/// Production evidence from step 1 (2026-10-27): sending 19:30+05:00 stored
/// 14:30+05:00, i.e. the server converts to UTC and then stores that clock
/// time as Asia/Karachi, so every stored instant is 5 hours early. To land the
/// meeting at instant T for this test only, T + 5 h is sent as UTC. The stored
/// value is read back and compared with T.
const meetingId = 29;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reschedule [TEST] meeting 29 for the reminder test', (tester) async {
    await tester.runAsync(() async {
      void log(String s) => debugPrint('RRESCHED $s');
      final api = Api();
      await api.restore();
      final m = resultOf(await api.request('meetings/$meetingId'));
      if (!'${m['title']}'.startsWith('[TEST] Reminder')) {
        log('ABORT meeting $meetingId is not the [TEST] reminder meeting');
        return;
      }
      log('before start ${m['start_time']} end ${m['end_time']}');
      final now = DateTime.now().toUtc();
      final base = now.add(const Duration(minutes: 35));
      final target = DateTime.utc(base.year, base.month, base.day, base.hour, base.minute - base.minute % 5).add(const Duration(minutes: 5));
      final targetEnd = target.add(const Duration(minutes: 30));
      String compensated(DateTime t) => '${t.add(const Duration(hours: 5)).toIso8601String().split('.').first}Z';
      final payload = {
        'title': m['title'],
        'description': m['description'],
        'type': m['type'] ?? 'virtual',
        'is_private': false,
        'is_client_meeting': false,
        'reminder_minutes': 15,
        'recurrence_frequency': 'none',
        'participant_ids': <int>[],
        'timezone': m['timezone'] ?? 'UTC',
        'start_time': compensated(target),
        'end_time': compensated(targetEnd),
      };
      log('now ${now.toIso8601String()} target start ${target.toIso8601String()} reminder due ${target.subtract(const Duration(minutes: 15)).toIso8601String()} (UTC)');
      log('sent start_time ${payload['start_time']} (target + 5 h, to offset the server bug)');
      final updated = resultOf(await api.request('meetings/$meetingId', method: 'PUT', data: payload));
      log('PUT returned start ${updated['start_time']}');
      final after = resultOf(await api.request('meetings/$meetingId'));
      final stored = DateTime.parse('${after['start_time']}').toUtc();
      log('stored start ${after['start_time']} = ${stored.toIso8601String()} UTC');
      log(stored == target ? 'CHECK stored instant matches target: PASS' : 'CHECK stored instant matches target: FAIL (off by ${stored.difference(target).inMinutes} min)');
      final metrics = asMap(resultOf(await api.request('dashboard'))['metrics']) ?? const {};
      log('dashboard reminder metrics ${{for (final e in metrics.entries) if (e.key.contains('remind')) e.key: e.value}}');
      log('DONE');
    });
  });
}
