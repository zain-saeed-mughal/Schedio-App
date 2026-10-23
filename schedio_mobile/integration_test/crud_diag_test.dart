import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';

/// Prints raw production responses behind the CRUD failures. Writes only
/// [TEST] events, which it deletes again. Emails and tokens are masked.
const sandboxCompanyId = int.fromEnvironment('SANDBOX_COMPANY_ID');

String mask(Object? v) => jsonEncode(v)
    .replaceAll(RegExp(r'[\w.+-]+@[\w.-]+'), '<email>')
    .replaceAll(RegExp(r'[A-Za-z0-9_-]{40,}'), '<long>');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crud diagnostics', (tester) async {
    await tester.runAsync(() async {
      final api = Api();
      await api.restore();
      final me = (await api.request('auth/me'))['data'] as Json;
      if (asInt(asMap(me['company'])?['id']) != sandboxCompanyId || sandboxCompanyId == 0) {
        debugPrint('DIAG refusing: not the sandbox company');
        return;
      }
      debugPrint('DIAG me id ${me['id']}, timezone ${me['timezone']}');
      final raw = Dio(BaseOptions(
        baseUrl: Api.baseUrl,
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer ${api.token}'},
        validateStatus: (_) => true,
      ));

      Future<void> show(String label, Future<Response<dynamic>> request) async {
        final r = await request;
        final body = mask(r.data);
        debugPrint('DIAG $label -> HTTP ${r.statusCode}: ${body.length > 700 ? '${body.substring(0, 700)}...' : body}');
      }

      // Task assignee shape.
      final tasks = (await api.request('tasks', query: {'per_page': 100}))['data'] as List;
      final testTask = tasks.cast<Map>().where((t) => '${t['title']}'.startsWith('[TEST]')).firstOrNull;
      if (testTask != null) {
        await show('task detail ${testTask['id']}', raw.get('tasks/${testTask['id']}'));
      }

      // Meeting update, cancel and delete on a leftover [TEST] meeting.
      final meetings = (await api.request('meetings', query: {'per_page': 100}))['data'] as List;
      final leftovers = meetings.cast<Map>().where((m) => '${m['title']}'.startsWith('[TEST]')).toList();
      debugPrint('DIAG [TEST] meetings: ${leftovers.map((m) => '${m['id']}:${m['status']}:${m['start_time']}:${m['timezone']}').toList()}');
      final scheduled = leftovers.where((m) => m['status'] != 'cancelled').firstOrNull;
      if (scheduled != null) {
        final id = scheduled['id'];
        await show('meeting detail $id', raw.get('meetings/$id'));
        await show('meeting PUT title only $id', raw.put('meetings/$id', data: {'title': '${scheduled['title']}'}));
        await show('meeting PATCH cancel $id', raw.patch('meetings/$id/cancel'));
        await show('meeting DELETE $id', raw.delete('meetings/$id'));
      }

      for (final id in [9, 11, 12]) {
        await show('meeting detail $id', raw.get('meetings/$id'));
      }

      // How the server stores event times (events can be deleted).
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final variants = {
        'utc-z': '2026-12-20T10:00:00.000Z',
        'offset+05': '2026-12-20T10:00:00+05:00',
        'naive': '2026-12-20 10:00:00',
      };
      for (final v in variants.entries) {
        final title = '[TEST] Time ${v.key} $stamp';
        final start = v.value;
        final end = start.replaceFirst('10:00:00', '11:00:00');
        final r = await raw.post('events', data: {
          'title': title,
          'category': 'general',
          'is_all_day': false,
          'is_company_wide': false,
          'start_time': start,
          'end_time': end,
        });
        final found = (await api.request('events', query: {'search': title}))['data'] as List;
        final row = found.cast<Map>().where((e) => e['title'] == title).firstOrNull;
        debugPrint('DIAG event ${v.key} sent $start -> HTTP ${r.statusCode}, stored start ${row?['start_time']}');
        if (row != null) {
          if (v.key == 'utc-z') {
            await show('event PUT start 15:00Z', raw.put('events/${row['id']}', data: {
              'title': '$title edited',
              'category': 'general',
              'is_all_day': false,
              'is_company_wide': false,
              'start_time': '2026-12-20T15:00:00.000Z',
              'end_time': '2026-12-20T16:00:00.000Z',
            }));
            await show('event detail after PUT', raw.get('events/${row['id']}'));
          }
          await raw.delete('events/${row['id']}');
        }
      }
      debugPrint('DIAG DONE');
    });
  });
}
