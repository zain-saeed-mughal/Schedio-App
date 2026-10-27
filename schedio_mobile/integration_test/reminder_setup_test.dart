import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/api_time.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Controlled reminder test, step 1 (approved 2026-10-27 by the user): creates
/// exactly one [TEST] meeting owned by the sandbox account, starting about 30
/// minutes from now with a 15-minute reminder. Refuses to run if a [TEST]
/// reminder meeting already exists. Logs ids and times only.
///
/// Times are sent as Asia/Karachi wall-clock (BACKEND_TIMEZONE_FIX.md: the
/// server currently stores the wall-clock part as Karachi time), and the
/// stored instant is read back and compared with the intended one.
const title = '[TEST] Reminder Check 01';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create one [TEST] reminder meeting', (tester) async {
    tzdata.initializeTimeZones();
    await tester.runAsync(() async {
      void log(String s) => debugPrint('RSETUP $s');
      final api = Api();
      await api.restore();
      final me = resultOf(await api.request('auth/me'));
      log('account ${me['id']} timezone ${me['timezone']}');

      final existing = (await api.request('meetings', query: {'search': '[TEST] Reminder'}))['data'] as List? ?? const [];
      final dupes = existing.whereType<Map>().where((m) => '${m['title']}'.startsWith('[TEST] Reminder')).toList();
      if (dupes.isNotEmpty) {
        log('ABORT a [TEST] reminder meeting already exists: ids ${dupes.map((m) => m['id']).toList()}');
        return;
      }

      final now = DateTime.now().toUtc();
      final base = now.add(const Duration(minutes: 30));
      final start = DateTime.utc(base.year, base.month, base.day, base.hour, base.minute - base.minute % 5).add(const Duration(minutes: 5));
      final end = start.add(const Duration(minutes: 30));
      final remindAt = start.subtract(const Duration(minutes: 15));
      final payload = {
        'title': title,
        'description': '[TEST] Controlled reminder test from mobile QA. Safe to delete.',
        'type': 'virtual',
        'is_private': false,
        'is_client_meeting': false,
        'reminder_minutes': 15,
        'recurrence_frequency': 'none',
        'participant_ids': <int>[],
        'timezone': me['timezone'] ?? 'UTC',
        'start_time': encodeApiTime(start, compatZone: 'Asia/Karachi'),
        'end_time': encodeApiTime(end, compatZone: 'Asia/Karachi'),
      };
      log('now ${now.toIso8601String()} intended start ${start.toIso8601String()} reminder due ${remindAt.toIso8601String()} (UTC)');
      log('sent start_time ${payload['start_time']} end_time ${payload['end_time']}');

      final created = resultOf(await api.request('meetings', method: 'POST', data: payload));
      final id = created['id'];
      log('created meeting id $id status ${created['status']} returned start ${created['start_time']} tz ${created['timezone']}');

      final detail = resultOf(await api.request('meetings/$id'));
      final stored = DateTime.parse('${detail['start_time']}').toUtc();
      log('stored start ${detail['start_time']} = ${stored.toIso8601String()} UTC');
      log(stored == start
          ? 'CHECK stored instant matches intended: PASS'
          : 'CHECK stored instant matches intended: FAIL (off by ${stored.difference(start).inMinutes} min)');
      final dash = resultOf(await api.request('dashboard'));
      final metrics = asMap(dash['metrics']) ?? const {};
      log('dashboard reminder metrics ${{for (final e in metrics.entries) if (e.key.contains('remind')) e.key: e.value}}');
      log('DONE meeting $id');
    });
  });
}
