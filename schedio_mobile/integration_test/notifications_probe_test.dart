import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';

/// Read-only (GET only) probe of the production notification contract.
/// Logs field names, value types, ids, notification types and timestamps.
/// Never logs tokens, emails or message text.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('notifications contract probe (read-only)', (tester) async {
    await tester.runAsync(() async {
      final api = Api();
      await api.restore();
      String type(Object? v) => switch (v) {
        null => 'null',
        String() => 'String',
        int() => 'int',
        double() => 'double',
        bool() => 'bool',
        List() => 'List(${v.length})',
        Map() => 'Map{${v.keys.join(',')}}',
        _ => v.runtimeType.toString(),
      };
      String shape(Map m) => m.entries.map((e) => '${e.key}:${type(e.value)}').join(', ');
      void log(String s) => debugPrint('NPROBE $s');

      Future<Json?> get(String path, [Map<String, Object> q = const {}]) async {
        try {
          return await api.request(path, query: q);
        } on ApiFailure catch (e) {
          log('$path $q -> ApiFailure status ${e.status} unsupported ${e.unsupported}');
          return null;
        } catch (e) {
          log('$path $q -> ${e.runtimeType}');
          return null;
        }
      }

      final me = await get('user') ?? await get('me');
      final u = me == null ? null : resultOf(me);
      if (u != null) {
        log('account id ${u['id']} timezone ${u['timezone']} company ${u['company_id'] ?? asMap(u['company'])?['id']}');
        log('notification_preferences ${jsonEncode(u['notification_preferences'])}');
      }

      final dash = await get('dashboard');
      if (dash != null) log('dashboard unread_notifications ${asMap(resultOf(dash)['metrics'])?['unread_notifications'] ?? resultOf(dash)['unread_notifications']}');

      for (final q in <Map<String, Object>>[
        {},
        {'page': 1, 'per_page': 50},
        {'filter': 'unread', 'status': 'unread'},
        {'filter': 'read'},
        {'page': 2},
      ]) {
        final r = await get('notifications', q);
        if (r == null) continue;
        final data = r['data'];
        log('list $q -> top{${r.keys.join(',')}} data ${type(data)} meta ${jsonEncode(r['meta'])} links ${type(r['links'])}');
        if (q.isEmpty && data is List) {
          for (final n in data.take(20).whereType<Map>()) {
            final d = n['data'];
            log('item id ${type(n['id'])} type ${n['type']} read_at ${n['read_at'] == null ? 'null' : 'set'} created_at ${n['created_at']} '
                'fields{${shape(n)}} data{${d is Map ? shape(d) : type(d)}} data.type ${d is Map ? d['type'] : '-'}');
          }
        }
      }

      for (final path in ['notifications/unread-count', 'notifications/preferences', 'devices', 'reminders']) {
        final r = await get(path);
        if (r != null) log('$path -> top{${r.keys.join(',')}} data ${type(r['data'])} meta ${jsonEncode(r['meta'])}');
      }

      // Reminder fields on meetings (ids only).
      final meetings = await get('meetings', {'per_page': 20});
      for (final m in (meetings?['data'] as List? ?? const []).whereType<Map>()) {
        log('meeting ${m['id']} status ${m['status']} start ${m['start_time']} tz ${m['timezone']} '
            'reminder fields{${m.entries.where((e) => '${e.key}'.contains('remind')).map((e) => '${e.key}:${jsonEncode(e.value)}').join(', ')}}');
      }
      for (final id in [11, 28]) {
        final r = await get('meetings/$id');
        if (r == null) continue;
        final m = resultOf(r);
        log('meeting $id detail keys{${m.keys.join(',')}}');
        log('meeting $id reminders ${jsonEncode(m['reminders'] ?? m['reminder'] ?? m['reminder_minutes'])}');
      }
      log('DONE');
    });
  });
}
