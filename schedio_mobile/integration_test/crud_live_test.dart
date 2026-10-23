import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

/// Live CRUD against production, limited to the confirmed sandbox company.
///
/// CRUD_PHASE=create: full create, read, update, verify and delete cycles for
/// every workflow, then leaves a small [TEST] set behind and checks it in the UI.
/// CRUD_PHASE=reopen: run in a fresh app process; checks the [TEST] set is still
/// shown, deletes it through the API and checks it is gone.
///
/// Every record is titled "[TEST] ...", assigned only to the signed-in test
/// account, has no other participants and is never company-wide.
const phase = String.fromEnvironment('CRUD_PHASE');
const sandboxCompanyId = int.fromEnvironment('SANDBOX_COMPANY_ID');
const pendingKey = 'qa_crud_pending';
// Inventory phase only: delete the one [TEST] meeting with exactly this title.
const deleteTitle = String.fromEnvironment('CRUD_DELETE_TITLE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('live CRUD ($phase)', (tester) async {
    if (!['create', 'reopen', 'inventory', 'cleanup', 'notifications', 'v21', 'final'].contains(phase)) fail('Set CRUD_PHASE to create, reopen, inventory or cleanup');
    if (sandboxCompanyId == 0) fail('Set SANDBOX_COMPANY_ID');
    // runAsync reports errors to the test framework and returns null, which
    // would let a failed request look like a pass; carry the error out instead.
    Future<T> async<T>(Future<T> Function() f) async {
      Object? error;
      StackTrace? trace;
      T? value;
      await tester.runAsync(() async {
        try {
          value = await f();
        } catch (e, s) {
          error = e;
          trace = s;
        }
      });
      if (error != null) Error.throwWithStackTrace(error!, trace!);
      return value as T;
    }

    final results = <String>[];
    final failures = <String>[];
    void log(String line) {
      results.add(line);
      debugPrint('CRUD $line');
    }

    Future<T?> step<T>(String label, Future<T> Function() body) async {
      try {
        final value = await async(body);
        log('$label: PASS');
        return value;
      } catch (e) {
        final why = e is ApiFailure ? 'HTTP ${e.status}: ${e.message}' : '$e'.split('\n').first;
        failures.add('$label: $why');
        log('$label: FAIL ($why)');
        return null;
      }
    }

    void check(bool ok, String what) {
      if (!ok) throw StateError(what);
    }

    // Start the real app with the saved session, then reuse its API client.
    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    final report = FlutterError.onError;
    var reported = 0;
    FlutterError.onError = (details) {
      reported++;
      final stack = details.stack.toString().split('\n').where((l) => l.contains('schedio_mobile')).take(4).join(' | ');
      debugPrint('CRUD APP ERROR $reported: ${details.exceptionAsString().split('\n').first} [${details.library}] $stack');
      report?.call(details);
    };
    addTearDown(() => FlutterError.onError = report);
    final api = Api();
    await async(api.restore);

    final me = (await async(() => api.request('auth/me')))['data'] as Json;
    final myId = asInt(me['id'])!;
    final company = asInt(asMap(me['company'])?['id']);
    if (company != sandboxCompanyId) {
      fail('Refusing to write: the signed-in account is in company $company, not sandbox company $sandboxCompanyId.');
    }
    log('tenant guard: signed-in account is in sandbox company $sandboxCompanyId: PASS');

    Future<Json> call(String path, {String method = 'GET', Json? data, Json? query}) =>
        api.request(path, method: method, data: data, query: query);

    // Meeting delete currently fails on the server; a meeting that cannot be
    // deleted is cancelled so it does not block the calendar, and the error is kept.
    Future<void> remove(String path) async {
      try {
        await call(path, method: 'DELETE');
      } on ApiFailure {
        if (path.startsWith('meetings/')) {
          try {
            await call('$path/cancel', method: 'PATCH');
          } catch (_) {}
        }
        rethrow;
      }
    }

    Future<void> expectStatus(Future<Object?> Function() request, Set<int> statuses, {String? field}) async {
      try {
        await request();
      } on ApiFailure catch (e) {
        check(statuses.contains(e.status), 'expected HTTP ${statuses.join('/')}, got ${e.status} ${e.message}');
        return;
      }
      throw StateError('expected HTTP ${statuses.join('/')} but the request succeeded');
    }

    Future<Json> read(String path) async => resultOf(await call(path));

    Future<int> idFromCreate(Json reply, String listPath, String title) async {
      final direct = asInt(resultOf(reply)['id']);
      if (direct != null) return direct;
      final found = await call(listPath, query: {'search': title, 'per_page': 100});
      final row = (found['data'] as List).cast<Map>().firstWhere((x) => '${x['title'] ?? x['name'] ?? x['company_name']}' == title);
      return asInt(row['id'])!;
    }

    Future<void> expectGone(String path) => expectStatus(() => call(path), {404, 410});

    void parses(Json row, Module module) {
      final r = Record.fromJson(row, module);
      check(r.id.isNotEmpty && r.id != 'null', '${module.name} model has no id');
    }

    Future<void> listChecks(String path, Module module) async {
      final page = await call(path, query: {'per_page': 1, 'page': 1});
      check(page['data'] is List, '$path data is not a list');
      final meta = asMap(page['meta']);
      check(meta != null && meta['current_page'] != null && meta['total'] != null, '$path has no pagination meta');
      for (final row in (page['data'] as List).whereType<Json>()) {
        parses(row, module);
      }
      RecordPage.fromJson(page, module);
    }

    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    String title(String what) => '[TEST] $what $stamp';
    // Times go out exactly as the app sends them: wall-clock in the account zone.
    final zone = '${me['timezone'] ?? 'UTC'}';
    String send(DateTime t) => apiTime(t, zone);
    final base = DateTime.now().toUtc().add(const Duration(days: 45));
    DateTime at(int dayOffset, int hour, [int minute = 0]) =>
        DateTime.utc(base.year, base.month, base.day + dayOffset, hour, minute);

    Json meetingBody(String name, DateTime start, int minutes, {int? roomId}) => {
      'title': name,
      'description': 'Automated QA record',
      'type': 'virtual',
      'department_id': null,
      'room_id': roomId,
      'client_id': null,
      'is_private': false,
      'is_client_meeting': false,
      'reminder_minutes': 15,
      'recurrence_frequency': 'none',
      'participant_ids': <int>[],
      'timezone': zone,
      'start_time': send(start),
      'end_time': send(start.add(Duration(minutes: minutes))),
    };

    final prefs = await async(SharedPreferences.getInstance);

    // CRUD_PHASE=final: one installed build runs v2.1, notifications and create,
    // then on the next launch (pending set saved) runs reopen, with no reinstall.
    final pending = prefs.getString(pendingKey) != null;
    final runV21 = phase == 'v21' || (phase == 'final' && !pending);
    final runNotifications = phase == 'notifications' || phase == 'inventory' || (phase == 'final' && !pending);
    final runCreate = phase == 'create' || (phase == 'final' && !pending);
    final runReopen = phase == 'reopen' || (phase == 'final' && pending);
    log('plan: v21 $runV21, notifications $runNotifications, create $runCreate, reopen $runReopen');
    if (runV21) {
      // Backend API v2.1 regression. Each meeting action runs once; if it still
      // fails, the rest of that chain is skipped instead of repeated.
      final name = title('v2.1 Meeting');
      final id = await step('v2.1 meeting create', () async => idFromCreate(await call('meetings', method: 'POST', data: meetingBody(name, at(13, 10), 30)), 'meetings', name));
      if (id != null) {
        final before = asInt(asMap((await async(() => call('notifications', query: {'per_page': 1})))['meta'])?['total']) ?? 0;
        Future<void> reminders(String when) async {
          final m = asMap(resultOf(await async(() => call('dashboard')))['metrics']);
          final list = resultOf(await async(() => call('dashboard')))['upcoming_reminders'];
          final mine = list is List ? list.whereType<Map>().where((r) => '${r['title'] ?? r['meeting_title'] ?? asMap(r['meeting'])?['title'] ?? ''}'.contains(stamp)).length : -1;
          log('note: reminders $when: active_reminders ${m?['active_reminders']}, upcoming list ${list is List ? list.length : 'n/a'}, for this meeting $mine');
        }
        await reminders('after create');
        final moved = await step('v2.1 meeting reschedule returns success and persists', () async {
          await call('meetings/$id', method: 'PUT', data: meetingBody('$name moved', at(13, 15), 45));
          final m = await read('meetings/$id');
          check(DateTime.parse('${m['start_time']}').toUtc() == at(13, 15), 'new start not saved: ${m['start_time']}');
          return true;
        });
        await step('v2.1 empty meeting note is rejected with 422', () => expectStatus(() => call('meetings/$id/notes', method: 'POST', data: {}), {422}));
        if (moved == true) {
          await step('v2.1 notification after meeting update', () async {
            final after = asInt(asMap((await call('notifications', query: {'per_page': 1}))['meta'])?['total']) ?? 0;
            log('note: notifications before update $before, after $after (organiser only; no other participants)');
          });
          await reminders('after reschedule');
          final cancelled = await step('v2.1 meeting cancel returns success and persists', () async {
            await call('meetings/$id/cancel', method: 'PATCH');
            check((await read('meetings/$id'))['status'] == 'cancelled', 'not cancelled');
            return true;
          });
          if (cancelled == true) {
            await reminders('after cancel');
            await step('v2.1 meeting delete returns success and is gone', () async {
              await call('meetings/$id', method: 'DELETE');
              await expectGone('meetings/$id');
            });
            await reminders('after delete');
          } else {
            log('v2.1 meeting delete: SKIPPED (cancel still failing)');
          }
        } else {
          log('v2.1 meeting cancel and delete: SKIPPED (update still failing)');
        }
      }
      await step('v2.1 rooms list has data, meta and links', () async {
        final r = await call('rooms', query: {'per_page': 5});
        check(r['data'] is List, 'no data');
        check(asMap(r['meta'])?['total'] != null, 'no meta');
        check(r['links'] is Map, 'no links');
      });
      final taskName = title('v2.1 Task');
      final taskId = await step('v2.1 task create', () async => idFromCreate(await call('tasks', method: 'POST', data: {
        'title': taskName,
        'description': 'Automated QA record',
        'priority': 'low',
        'assigned_to': myId,
        'due_date': send(at(9, 12)),
      }), 'tasks', taskName));
      if (taskId != null) {
        await step('v2.1 task detail fields', () async {
          final t = await read('tasks/$taskId');
          log('note: task detail keys ${t.keys.toList()}, can_manage ${t['can_manage']}');
        });
        await step('v2.1 task edit (PUT) persists title, priority, assignee, due date', () async {
          await call('tasks/$taskId', method: 'PUT', data: {
            'title': '$taskName edited',
            'description': 'Edited',
            'priority': 'high',
            'assigned_to': myId,
            'due_date': send(at(10, 9)),
          });
          final t = await read('tasks/$taskId');
          check(t['title'] == '$taskName edited' && t['priority'] == 'high', 'edit not saved');
          check(asInt(t['assigned_to'] ?? t['assignee']) == myId, 'assignee differs');
          check(DateTime.parse('${t['due_date']}').toUtc() == at(10, 9), 'due date differs: ${t['due_date']}');
        });
        await step('v2.1 task edit validation (empty title) is 422', () => expectStatus(() => call('tasks/$taskId', method: 'PUT', data: {'title': ''}), {422}));
        await step('v2.1 task status completed', () async {
          await call('tasks/$taskId/status', method: 'PATCH', data: {'status': 'completed'});
          check((await read('tasks/$taskId'))['status'] == 'completed', 'status not saved');
        });
        await step('v2.1 task delete and gone', () async {
          await call('tasks/$taskId', method: 'DELETE');
          await expectGone('tasks/$taskId');
        });
      }
      await step('v2.1 rooms pagination with per_page 1', () async {
        final r = await call('rooms', query: {'per_page': 1, 'page': 1});
        log('note: rooms meta ${asMap(r['meta'])}');
      });
    }
    if (runNotifications) {
      // Read/unread on the account's own notifications; each one ends in its original state.
      final rows = ((await async(() => call('notifications', query: {'per_page': 20})))['data'] as List).whereType<Json>().toList();
      log('notifications on the account: ${rows.length}');
      for (final row in rows) {
        parses(row, Module.notifications);
      }
      if (rows.isNotEmpty) {
        final n = rows.first;
        final wasRead = n['read_at'] != null;
        Future<Map> current() async => ((await call('notifications', query: {'per_page': 20}))['data'] as List).cast<Map>().firstWhere((x) => x['id'] == n['id']);
        await step('notification mark read persists', () async {
          await call('notifications/${n['id']}/read', method: 'PATCH');
          check((await current())['read_at'] != null, 'read not persisted');
        });
        await step('notification mark unread persists', () async {
          await call('notifications/${n['id']}/unread', method: 'PATCH');
          check((await current())['read_at'] == null, 'unread not persisted');
        });
        await step('unread filter and count agree', () async {
          final unread = await call('notifications', query: {'filter': 'unread', 'status': 'unread', 'per_page': 100});
          final list = (unread['data'] as List).cast<Map>();
          check(list.every((x) => x['read_at'] == null), 'read item in unread filter');
          final count = asInt(asMap(unread['meta'])?['unread_count']);
          check(count == null || count == list.length || list.length == 100, 'unread_count $count vs ${list.length} listed');
        });
        if (wasRead) await async(() => call('notifications/${n['id']}/read', method: 'PATCH'));
        await step('mark all as read, then restore the unread ones', () async {
          final unread = ((await call('notifications', query: {'filter': 'unread', 'status': 'unread', 'per_page': 100}))['data'] as List).cast<Map>().map((x) => x['id']).toList();
          await call('notifications/mark-all-read', method: 'POST');
          final left = await call('notifications', query: {'filter': 'unread', 'status': 'unread', 'per_page': 100});
          final leftCount = (left['data'] as List).length;
          for (final id in unread) {
            await call('notifications/$id/unread', method: 'PATCH');
          }
          final restored = ((await call('notifications', query: {'filter': 'unread', 'status': 'unread', 'per_page': 100}))['data'] as List).length;
          log('note: unread before ${unread.length}, after mark-all $leftCount, restored $restored');
          check(leftCount == 0, '$leftCount still unread after mark all');
          check(restored == unread.length, 'restore mismatch');
        });
        await step('notification timestamps carry a timezone', () async {
          final created = '${rows.first['created_at']}';
          check(RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(created), 'created_at without zone: $created');
          log('note: sample created_at $created');
        });
      }
    }
    if (phase == 'inventory' || phase == 'cleanup') {
      // Only records whose title starts with [TEST] are listed or touched.
      for (final path in ['clients', 'meetings', 'rooms', 'events', 'tasks']) {
        final rows = await async(() async {
          final all = <Map>[];
          for (var page = 1; page <= 10; page++) {
            final r = await call(path, query: {'per_page': 100, 'page': page});
            all.addAll((r['data'] as List).cast<Map>());
            if (page >= (asInt(asMap(r['meta'])?['last_page']) ?? 1)) break;
          }
          final test = all.where((x) => '${x['title'] ?? x['name'] ?? x['company_name']}'.startsWith('[TEST]')).toList();
          log('inventory $path: ${all.length} records in total, ${all.length - test.length} not [TEST]');
          return test;
        });
        log('inventory $path: ${rows.length} [TEST] records ${rows.map((x) => '${x['id']}:${x['status'] ?? ''}${path == 'meetings' ? ':${x['start_time']}' : ''}').toList()}');
        if (path == 'meetings' && deleteTitle.isNotEmpty) {
          for (final row in rows.where((x) => x['title'] == deleteTitle)) {
            await step('targeted delete of meeting ${row['id']} "$deleteTitle"', () async {
              await remove('meetings/${row['id']}');
              await expectGone('meetings/${row['id']}');
            });
          }
        }
        if (phase != 'cleanup' || path == 'tasks') continue;
        for (final row in rows) {
          await step('cleanup $path ${row['id']}', () async {
            await remove('$path/${row['id']}');
            await expectGone('$path/${row['id']}');
          });
        }
      }
    }
    if (runCreate) {
      final lookups = await async(() => read('lookups'));
      List<String> keys(Object? v) => [
        for (final x in (v is List ? v : const []))
          if (x is Map) '${x['value'] ?? x['key'] ?? x['id']}' else '$x',
      ];
      final stages = keys(lookups['pipeline_stages'] ?? lookups['client_statuses']);
      log('lookups: ${stages.length} pipeline stages');

      // 1. Clients and pipeline.
      await step('clients list, pagination and model', () => listChecks('clients', Module.clients));
      await step('clients validation (empty company name)', () => expectStatus(() => call('clients', method: 'POST', data: {'company_name': ''}), {422}, field: 'company_name'));
      final clientName = title('Client');
      final clientId = await step('client create', () async => idFromCreate(await call('clients', method: 'POST', data: {
        'company_name': clientName,
        'contact_name': 'QA Contact',
        'contact_email': 'qa.$stamp@example.test',
        'status': stages.isNotEmpty ? stages.first : 'discovery',
        'assigned_to': myId,
        'notes': 'Automated QA record',
      }), 'clients', clientName));
      if (clientId != null) {
        await step('client read matches', () async {
          final c = await read('clients/$clientId');
          parses(c, Module.clients);
          check(c['company_name'] == clientName, 'name differs');
          check(asInt(c['assigned_to']) == myId, 'assignee differs');
        });
        await step('client update persists', () async {
          await call('clients/$clientId', method: 'PUT', data: {'company_name': '$clientName edited', 'contact_name': 'QA Contact 2', 'status': stages.isNotEmpty ? stages.first : 'discovery', 'assigned_to': myId});
          final c = await read('clients/$clientId');
          check(c['company_name'] == '$clientName edited' && c['contact_name'] == 'QA Contact 2', 'update not persisted');
        });
        for (final stage in stages.skip(1).take(3)) {
          await step('client stage change to $stage persists', () async {
            await call('clients/$clientId/status', method: 'PATCH', data: {'status': stage, 'progress': 'QA stage check'});
            check((await read('clients/$clientId'))['status'] == stage, 'stage not persisted');
          });
        }
        await step('client invalid stage rejected', () => expectStatus(() => call('clients/$clientId/status', method: 'PATCH', data: {'status': 'not-a-stage'}), {422}));
        await step('client meetings list', () async => check((await call('clients/$clientId/meetings'))['data'] is List, 'no list'));
        await step('client delete and gone', () async {
          await remove('clients/$clientId');
          await expectGone('clients/$clientId');
        });
      }

      // 2. Tasks.
      await step('tasks list, pagination and model', () => listChecks('tasks', Module.tasks));
      await step('tasks validation (missing title)', () => expectStatus(() => call('tasks', method: 'POST', data: {'priority': 'medium'}), {422}, field: 'title'));
      final taskName = title('Task');
      final due = at(2, 12);
      final taskId = await step('task create (assigned to self, due date)', () async => idFromCreate(await call('tasks', method: 'POST', data: {
        'title': taskName,
        'description': 'Automated QA record',
        'priority': 'high',
        'assigned_to': myId,
        'department_id': null,
        'due_date': send(due),
        'meeting_id': null,
      }), 'tasks', taskName));
      if (taskId != null) {
        await step('task read matches (assignee, priority, due date)', () async {
          final t = await read('tasks/$taskId');
          parses(t, Module.tasks);
          check(t['title'] == taskName && t['priority'] == 'high', 'title or priority differs');
          check(asInt(t['assigned_to'] ?? t['assignee']) == myId, 'assignee differs');
          final d = DateTime.tryParse('${t['due_date']}');
          check(d != null && d.toUtc().year == due.year && d.toUtc().month == due.month && d.toUtc().day == due.day, 'due date differs: ${t['due_date']}');
        });
        for (final s in ['in_progress', 'completed']) {
          await step('task status $s persists', () async {
            await call('tasks/$taskId/status', method: 'PATCH', data: {'status': s});
            check((await read('tasks/$taskId'))['status'] == s, 'status not persisted');
          });
        }
        await step('task invalid status rejected', () => expectStatus(() => call('tasks/$taskId/status', method: 'PATCH', data: {'status': 'not-a-status'}), {422}));
        await step('task filter by completed', () async {
          final rows = (await call('tasks', query: {'status': 'completed', 'per_page': 100}))['data'] as List;
          check(rows.any((x) => asInt(x['id']) == taskId), 'completed task missing from filter');
        });
        await step('task delete and gone', () async {
          await remove('tasks/$taskId');
          await expectGone('tasks/$taskId');
        });
      }

      // 3 and 4. Meetings, rescheduling, calendar feed, conflicts, cancellation.
      await step('meetings list, pagination and model', () => listChecks('meetings', Module.meetings));
      await step('meetings validation (end before start)', () => expectStatus(() => call('meetings', method: 'POST', data: {
        ...meetingBody(title('Invalid'), at(0, 10), 30),
        'end_time': send(at(0, 9)),
      }), {422}));
      final meetingName = title('Meeting');
      final meetingId = await step('meeting create', () async => idFromCreate(await call('meetings', method: 'POST', data: meetingBody(meetingName, at(0, 10), 30)), 'meetings', meetingName));
      if (meetingId != null) {
        await step('meeting read matches', () async {
          final m = await read('meetings/$meetingId');
          parses(m, Module.meetings);
          check(m['title'] == meetingName, 'title differs');
          check(DateTime.parse('${m['start_time']}').toUtc() == at(0, 10), 'start differs: ${m['start_time']}');
        });
        await step('meeting reschedule persists', () async {
          await call('meetings/$meetingId', method: 'PUT', data: meetingBody('$meetingName moved', at(0, 14), 45));
          final m = await read('meetings/$meetingId');
          check(m['title'] == '$meetingName moved', 'title not saved');
          check(DateTime.parse('${m['start_time']}').toUtc() == at(0, 14), 'new start not saved: ${m['start_time']}');
          check(DateTime.parse('${m['end_time']}').toUtc() == at(0, 14, 45), 'new end not saved: ${m['end_time']}');
        });
        await step('calendar feed shows the rescheduled meeting', () async {
          final feed = await call('calendar/feed', query: {'start': send(at(0, 13)), 'end': send(at(0, 16))});
          check((feed['data'] as List).any((e) => asInt(e['id']) == meetingId), 'meeting missing from feed');
        });
        await step('availability reports the conflict', () async {
          final r = resultOf(await call('availability/check', method: 'POST', data: {
            'start_time': send(at(0, 14, 15)),
            'end_time': send(at(0, 14, 30)),
            'participant_ids': [myId],
          }));
          check(r['has_conflicts'] == true, 'overlap not reported as a conflict: $r');
        });
        await step('overlapping meeting is refused or flagged', () async {
          try {
            final reply = await call('meetings', method: 'POST', data: meetingBody(title('Overlap'), at(0, 14, 15), 15));
            // Accepted: record the behaviour and clean up.
            final id = await idFromCreate(reply, 'meetings', title('Overlap'));
            await remove('meetings/$id');
            log('note: the API accepted an overlapping meeting for the same organiser (no participants); it was deleted');
          } on ApiFailure catch (e) {
            check(e.status == 409 || e.status == 422, 'unexpected HTTP ${e.status}');
            log('note: overlapping meeting refused with HTTP ${e.status}');
          }
        });
        await step('meeting suggestions', () async {
          final day = at(0, 0);
          final r = resultOf(await call('availability/suggestions', query: {
            'date': '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
            'duration_minutes': 45,
            'participant_ids[]': [myId],
          }));
          check(r['slots'] is List, 'no suggestion slots');
        });

        // 5. Notes on the meeting.
        final noteId = await step('note create', () async {
          final r = await call('meetings/$meetingId/notes', method: 'POST', data: {
            'agenda': title('Agenda'),
            'discussion': 'Automated QA note',
            'decisions': 'None',
            'action_items': 'Check persistence',
            'follow_up_date': send(at(1, 9)),
          });
          final id = asInt(resultOf(r)['id']);
          if (id != null) return id;
          final list = (await call('meetings/$meetingId/notes'))['data'] as List;
          return asInt(list.cast<Map>().firstWhere((x) => x['agenda'] == title('Agenda'))['id'])!;
        });
        if (noteId != null) {
          await step('note read matches', () async {
            final n = await read('meeting-notes/$noteId');
            parses(n, Module.notes);
            check(n['agenda'] == title('Agenda'), 'agenda differs');
          });
          await step('note update persists', () async {
            await call('meeting-notes/$noteId', method: 'PUT', data: {'agenda': '${title('Agenda')} edited', 'discussion': 'Edited', 'action_items': 'Done'});
            check((await read('meeting-notes/$noteId'))['agenda'] == '${title('Agenda')} edited', 'note edit not persisted');
          });
          await step('note listed on the meeting', () async {
            final list = (await call('meetings/$meetingId/notes'))['data'] as List;
            check(list.any((x) => asInt(x['id']) == noteId), 'note missing from meeting notes');
          });
          await step('note delete and gone', () async {
            await remove('meeting-notes/$noteId');
            await expectGone('meeting-notes/$noteId');
          });
        }

        await step('meeting cancel persists', () async {
          await call('meetings/$meetingId/cancel', method: 'PATCH');
          check((await read('meetings/$meetingId'))['status'] == 'cancelled', 'status not cancelled');
        });
        await step('cancelled meeting frees the slot', () async {
          final r = resultOf(await call('availability/check', method: 'POST', data: {
            'start_time': send(at(0, 14, 15)),
            'end_time': send(at(0, 14, 30)),
            'participant_ids': [myId],
          }));
          check(r['has_conflicts'] == false, 'slot still busy after cancel');
        });
        await step('meeting delete and gone', () async {
          await remove('meetings/$meetingId');
          await expectGone('meetings/$meetingId');
        });
      }

      // 6. Rooms, amenities and room conflicts.
      await step('rooms list, pagination and model', () => listChecks('rooms', Module.rooms));
      await step('rooms validation (missing name)', () => expectStatus(() => call('rooms', method: 'POST', data: {'capacity': 4}), {422}, field: 'name'));
      final roomName = title('Room');
      final roomId = await step('room create with amenities', () async => idFromCreate(await call('rooms', method: 'POST', data: {
        'name': roomName,
        'code': 'QA${stamp.substring(stamp.length - 6)}',
        'location': 'QA floor',
        'capacity': '4',
        'amenities_text': 'Screen, Whiteboard',
        'amenities': ['Screen', 'Whiteboard'],
        'is_active': true,
      }), 'rooms', roomName));
      if (roomId != null) {
        await step('room read matches (capacity, amenities)', () async {
          final r = await read('rooms/$roomId');
          parses(r, Module.rooms);
          final model = Record.fromJson(r, Module.rooms);
          check(model.capacity == 4, 'capacity differs: ${r['capacity']}');
          check(model.amenities.length == 2, 'amenities differ: ${r['amenities']}');
        });
        await step('room update persists (amenities, capacity)', () async {
          await call('rooms/$roomId', method: 'PUT', data: {
            'name': '$roomName edited',
            'code': 'QA${stamp.substring(stamp.length - 6)}',
            'location': 'QA floor 2',
            'capacity': '6',
            'amenities_text': 'Screen, Whiteboard, Phone',
            'amenities': ['Screen', 'Whiteboard', 'Phone'],
            'is_active': true,
          });
          final model = Record.fromJson(await read('rooms/$roomId'), Module.rooms);
          check(model.title == '$roomName edited' && model.capacity == 6 && model.amenities.length == 3, 'room edit not persisted');
        });
        await step('room booking conflict', () async {
          final first = await idFromCreate(await call('meetings', method: 'POST', data: meetingBody(title('Room meeting'), at(3, 10), 60, roomId: roomId)), 'meetings', title('Room meeting'));
          try {
            final reply = await call('meetings', method: 'POST', data: meetingBody(title('Room clash'), at(3, 10, 30), 30, roomId: roomId));
            final second = await idFromCreate(reply, 'meetings', title('Room clash'));
            await remove('meetings/$second');
            throw StateError('the API double-booked the room');
          } on ApiFailure catch (e) {
            check(e.status == 409 || e.status == 422, 'unexpected HTTP ${e.status}');
            log('note: double room booking refused with HTTP ${e.status}');
          } finally {
            await remove('meetings/$first');
          }
        });
        await step('room delete and gone', () async {
          await remove('rooms/$roomId');
          await expectGone('rooms/$roomId');
        });
      }

      // 7. Events and booking.
      await step('events list, pagination and model', () => listChecks('events', Module.events));
      await step('events validation (missing title)', () => expectStatus(() => call('events', method: 'POST', data: {'category': 'general'}), {422}, field: 'title'));
      final eventName = title('Event');
      Json eventBody(String name, DateTime start) => {
        'title': name,
        'description': 'Automated QA record',
        'location': 'QA',
        'category': 'general',
        'department_id': null,
        'is_all_day': false,
        'is_company_wide': false,
        'start_time': send(start),
        'end_time': send(start.add(const Duration(hours: 1))),
      };
      final eventId = await step('event create (not company-wide)', () async => idFromCreate(await call('events', method: 'POST', data: eventBody(eventName, at(4, 10))), 'events', eventName));
      if (eventId != null) {
        await step('event read matches', () async {
          final e = await read('events/$eventId');
          parses(e, Module.events);
          check(e['title'] == eventName && e['is_company_wide'] != true, 'title or scope differs');
        });
        await step('event update persists', () async {
          await call('events/$eventId', method: 'PUT', data: eventBody('$eventName edited', at(4, 15)));
          final e = await read('events/$eventId');
          check(e['title'] == '$eventName edited' && DateTime.parse('${e['start_time']}').toUtc() == at(4, 15), 'event edit not persisted');
        });
        await step('calendar feed shows the event', () async {
          final feed = await call('calendar/feed', query: {'start': send(at(4, 14)), 'end': send(at(4, 17))});
          check((feed['data'] as List).any((x) => '${x['title']}' == '$eventName edited'), 'event missing from feed');
        });
        await step('event delete and gone', () async {
          await remove('events/$eventId');
          await expectGone('events/$eventId');
        });
      }

      final username = (me['booking_username'] ?? me['username'] ?? '').toString();
      if (username.isEmpty) {
        log('public booking: NOT TESTED (no booking username on the account)');
      } else {
        await step('public booking submit creates a meeting, then cleaned up', () async {
          final day = at(6, 0);
          final dateText = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          final slots = await call('public/booking/$username/slots', query: {'date': dateText, 'duration': 15});
          final list = (slots['slots'] ?? asMap(slots['data'])?['slots'] ?? slots['data']) as List;
          check(list.isNotEmpty, 'no free slots on $dateText');
          final slot = list.first as Map;
          final reply = await call('public/booking/$username', method: 'POST', data: {
            'client_name': title('Guest'),
            'client_email': 'qa.guest.$stamp@example.test',
            'client_company': '[TEST] QA',
            'notes': 'Automated QA booking',
            'start_time': slot['start_time'],
            'duration_minutes': 15,
          });
          check(resultOf(reply).isNotEmpty || reply['message'] != null, 'empty booking reply');
          final after = await call('public/booking/$username/slots', query: {'date': dateText, 'duration': 15});
          final left = (after['slots'] ?? asMap(after['data'])?['slots'] ?? after['data']) as List;
          check(!left.any((s) => (s as Map)['start_time'] == slot['start_time']), 'booked slot still offered');
          final meetings = (await call('meetings', query: {'search': title('Guest'), 'per_page': 100}))['data'] as List;
          final booked = meetings.cast<Map>().where((m) => '${m['title']}'.contains(stamp) || '${m['client_name'] ?? ''}'.contains(stamp)).toList();
          if (booked.isEmpty) {
            final all = (await call('meetings', query: {'per_page': 100}))['data'] as List;
            booked.addAll(all.cast<Map>().where((m) => DateTime.tryParse('${m['start_time']}')?.toUtc() == DateTime.parse('${slot['start_time']}').toUtc()));
          }
          check(booked.isNotEmpty, 'booking did not create a visible meeting');
          for (final m in booked) {
            await remove('meetings/${m['id']}');
          }
        });
      }

      // 8. Notifications and preferences.
      await step('notifications list, pagination and model', () => listChecks('notifications', Module.notifications));
      await step('notification read and unread round trip', () async {
        final rows = ((await call('notifications', query: {'per_page': 20}))['data'] as List).whereType<Json>().toList();
        if (rows.isEmpty) {
          log('note: no notifications on the account; read/unread not exercised');
          return;
        }
        final n = rows.first;
        final wasRead = n['read_at'] != null;
        await call('notifications/${n['id']}/read', method: 'PATCH');
        var now = ((await call('notifications', query: {'per_page': 20}))['data'] as List).cast<Map>().firstWhere((x) => x['id'] == n['id']);
        check(now['read_at'] != null, 'read not persisted');
        await call('notifications/${n['id']}/unread', method: 'PATCH');
        now = ((await call('notifications', query: {'per_page': 20}))['data'] as List).cast<Map>().firstWhere((x) => x['id'] == n['id']);
        check(now['read_at'] == null, 'unread not persisted');
        if (wasRead) await call('notifications/${n['id']}/read', method: 'PATCH');
      });
      await step('notification preferences change persists and is restored', () async {
        final account = Account.fromJson((await call('auth/me'))['data'] as Json);
        final original = account.preferences;
        Json body(bool email) => {
          'channel_in_app': original.inApp,
          'channel_email': email,
          'channels': {'in_app': original.inApp, 'email': email},
          'categories': {
            for (final e in original.categories.entries) e.key: {'in_app': e.value.inApp, 'email': e.value.email},
          },
        };
        await call('notifications/preferences', method: 'POST', data: body(!original.email));
        final changed = Account.fromJson((await call('auth/me'))['data'] as Json).preferences;
        await call('notifications/preferences', method: 'POST', data: body(original.email));
        final restored = Account.fromJson((await call('auth/me'))['data'] as Json).preferences;
        check(changed.email == !original.email, 'preference change not persisted');
        check(restored.email == original.email, 'preference not restored');
      });

      // 9. Registration queue: read-only (a new applicant would notify the company's other admins).
      await step('registration queue lists, filters and pagination', () async {
        for (final s in ['pending', 'approved', 'rejected']) {
          final page = await call('admin/registration-requests', query: {'status': s, 'per_page': 5});
          check(page['data'] is List, '$s list missing');
          for (final row in (page['data'] as List).whereType<Json>()) {
            parses(row, Module.administration);
          }
        }
      });

      // Leave a [TEST] set for the reopen phase and check it in the UI now.
      final keep = <String, Object>{};
      await step('persistence set create', () async {
        final c = title('Persist client');
        keep['client'] = await idFromCreate(await call('clients', method: 'POST', data: {'company_name': c, 'contact_name': 'QA', 'status': stages.isNotEmpty ? stages.first : 'discovery', 'assigned_to': myId}), 'clients', c);
        final m = title('Persist meeting');
        keep['meeting'] = await idFromCreate(await call('meetings', method: 'POST', data: meetingBody(m, DateTime.now().toUtc().add(const Duration(days: 1)).copyWith(minute: 0, second: 0, millisecond: 0, microsecond: 0), 30)), 'meetings', m);
        final r = title('Persist room');
        keep['room'] = await idFromCreate(await call('rooms', method: 'POST', data: {'name': r, 'code': 'QP${stamp.substring(stamp.length - 6)}', 'location': 'QA', 'capacity': '2', 'amenities': <String>[], 'is_active': true}), 'rooms', r);
        final e = title('Persist event');
        keep['event'] = await idFromCreate(await call('events', method: 'POST', data: eventBody(e, at(5, 10))), 'events', e);
        final t = title('Persist task');
        keep['task'] = await idFromCreate(await call('tasks', method: 'POST', data: {'title': t, 'priority': 'low', 'assigned_to': myId}), 'tasks', t);
        keep['stamp'] = stamp;
        await prefs.setString(pendingKey, jsonEncode(keep));
      });
      if (keep.containsKey('stamp')) await uiCheck(tester, stamp, expectPresent: true, log: log, failures: failures, async: async);
    }
    if (runReopen) {
      final raw = prefs.getString(pendingKey);
      if (raw == null) fail('No pending [TEST] set; run CRUD_PHASE=create first');
      final keep = jsonDecode(raw) as Map<String, dynamic>;
      final stamp = keep['stamp'] as String;
      log('reopen: fresh app process, checking [TEST] set $stamp');
      await uiCheck(tester, stamp, expectPresent: true, log: log, failures: failures, async: async);
      for (final entry in {'client': 'clients', 'meeting': 'meetings', 'room': 'rooms', 'event': 'events', 'task': 'tasks'}.entries) {
        final id = keep[entry.key];
        if (id == null) continue;
        await step('reopen: ${entry.key} still stored, then deleted', () async {
          await read('${entry.value}/$id');
          await remove('${entry.value}/$id');
          await expectGone('${entry.value}/$id');
        });
      }
      await prefs.remove(pendingKey);
      await uiCheck(tester, stamp, expectPresent: false, log: log, failures: failures, async: async);
    }

    debugPrint('CRUD SUMMARY: ${results.where((r) => r.endsWith('PASS')).length} pass, ${failures.length} fail');
    for (final f in failures) {
      debugPrint('CRUD FAILED: $f');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}

/// Visits the app's own screens and checks whether the [TEST] records with
/// [stamp] are shown (or, after cleanup, no longer shown).
Future<void> uiCheck(
  WidgetTester tester,
  String stamp, {
  required bool expectPresent,
  required void Function(String) log,
  required List<String> failures,
  required Future<T> Function<T>(Future<T> Function()) async,
}) async {
  Future<void> pumpFor(Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> settle() async {
    await pumpFor(const Duration(milliseconds: 600));
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (find.byWidgetPredicate((w) => w is SchedioLoadingIndicator && w.isLoading).evaluate().isNotEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await pumpFor(const Duration(milliseconds: 500));
  }

  bool shown(String what) => find.textContaining('$what $stamp', skipOffstage: false).evaluate().isNotEmpty;

  void verdict(String screen, String what) {
    final ok = shown(what) == expectPresent;
    final line = 'UI $screen ${expectPresent ? 'shows' : 'no longer shows'} [TEST] $what: ${ok ? 'PASS' : 'FAIL'}';
    log(line);
    if (!ok) failures.add(line);
  }

  Future<void> back() async {
    final chip = find.byTooltip('Back');
    if (chip.evaluate().isNotEmpty) {
      await tester.tap(chip.first);
    } else {
      await tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
    }
    await settle();
  }

  Future<void> quick(String label) async {
    await tester.tap(find.byType(CenterFab));
    await settle();
    final item = find.descendant(of: find.byType(AppSheet), matching: find.text(label));
    await tester.ensureVisible(item);
    await tester.tap(item);
    await settle();
  }

  // Same as the user pulling to refresh: reload every open screen.
  ProviderScope.containerOf(tester.element(find.byType(SchedioApp))).read(refreshProvider.notifier).refresh();
  await settle();
  await tester.tap(find.text('Meetings').last);
  await settle();
  verdict('Meetings', 'Persist meeting');
  await tester.tap(find.text('Pipeline').last);
  await settle();
  if (find.text('Spreadsheet').evaluate().isNotEmpty) {
    await tester.tap(find.text('Spreadsheet'));
    await settle();
  }
  verdict('Pipeline', 'Persist client');
  if (find.text('Board').evaluate().isNotEmpty) {
    await tester.tap(find.text('Board'));
    await settle();
  }
  await tester.tap(find.text('Home').last);
  await settle();
  for (final (label, what) in [('My Tasks', 'Persist task'), ('Meeting Suites', 'Persist room'), ('Events and Holidays', 'Persist event')]) {
    await quick(label);
    verdict(label, what);
    if (expectPresent && what == 'Persist task' && shown(what)) {
      // The task detail must offer status changes, Edit and Delete (tasks carry no can_manage).
      final tile = find.textContaining('$what $stamp').first;
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await settle();
      final ok = find.widgetWithText(FilterPill, 'Completed').evaluate().isNotEmpty &&
          find.text('Edit').evaluate().isNotEmpty &&
          find.text('Delete').evaluate().isNotEmpty;
      final line = 'UI task detail offers status, Edit and Delete: ${ok ? 'PASS' : 'FAIL'}';
      log(line);
      if (!ok) failures.add(line);
      await back();
    }
    await back();
  }
}
