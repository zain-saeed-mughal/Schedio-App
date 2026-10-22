import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';

const confirmed = String.fromEnvironment('SANDBOX_CONFIRMED') == 'yes';
const companyId = int.fromEnvironment('SANDBOX_COMPANY_ID');
const adminEmail = String.fromEnvironment('SANDBOX_ADMIN_EMAIL');
const adminPassword = String.fromEnvironment('SANDBOX_ADMIN_PASSWORD');
const staffEmail = String.fromEnvironment('SANDBOX_STAFF_EMAIL');
const staffPassword = String.fromEnvironment('SANDBOX_STAFF_PASSWORD');
const useSavedSession = String.fromEnvironment('SANDBOX_USE_SAVED_SESSION') == 'yes';

class Session {
  final Api api;
  final Json user;
  final bool saved;
  Session(this.api, this.user, {this.saved = false});

  static Future<Session> fromSavedSession() async {
    final api = Api();
    await api.restore();
    if (api.token == null) throw StateError('no saved session on this device');
    final me = await api.request('auth/me');
    return Session(api, me['data'] as Json, saved: true);
  }

  static Future<Session> signIn(String email, String password) async {
    final api = Api(client: Dio(BaseOptions(baseUrl: Api.baseUrl, headers: {'Accept': 'application/json'})));
    final r = await api.request('auth/login', method: 'POST', data: {'email': email, 'password': password, 'device_name': 'Schedio sandbox test'});
    api.token = r['token'] as String;
    return Session(api, r['user'] as Json);
  }

  Future<Json> call(String path, {String method = 'GET', Json? data, Json? query}) =>
      api.request(path, method: method, data: data, query: query);

  Future<void> signOut() async {
    if (saved) return;
    try {
      await api.request('auth/logout', method: 'POST');
    } catch (_) {}
    api.token = null;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sandbox write workflows (only with explicit confirmation)', (tester) async {
    final haveAdmin = useSavedSession || (adminEmail.isNotEmpty && adminPassword.isNotEmpty);
    if (confirmed && haveAdmin && companyId == 0) {
      final probe = useSavedSession ? await Session.fromSavedSession() : await Session.signIn(adminEmail, adminPassword);
      final c = asMap(probe.user['company']);
      debugPrint('SANDBOX COMPANY PROBE: id ${c?['id']}, name ${c?['name']}. Nothing was written. Rerun with SANDBOX_COMPANY_ID set to this id if it is the sandbox.');
      await probe.signOut();
      return;
    }
    if (!confirmed || companyId == 0 || !haveAdmin) {
      debugPrint('SANDBOX NOT RUN: pass SANDBOX_CONFIRMED=yes, SANDBOX_COMPANY_ID and rotated test credentials. Nothing was written.');
      return;
    }
    final results = <String>[];
    final failures = <String>[];
    final cleanup = <Future<void> Function()>[];
    final stamp = DateTime.now().millisecondsSinceEpoch;
    String name(String what) => '[TEST] $what $stamp';

    Future<T?> step<T>(String label, Future<T> Function() body) async {
      try {
        final value = await body();
        results.add('SANDBOX $label: PASS');
        debugPrint(results.last);
        return value;
      } catch (e) {
        final why = e is ApiFailure ? 'HTTP ${e.status}: ${e.message}' : '$e'.split('\n').first;
        failures.add('$label: $why');
        results.add('SANDBOX $label: FAIL ($why)');
        debugPrint(results.last);
        return null;
      }
    }

    void expectTrue(bool ok, String what) {
      if (!ok) throw StateError(what);
    }

    Future<void> expectStatus(Future<Object?> call, Set<int> statuses) async {
      try {
        await call;
        throw StateError('expected HTTP ${statuses.join('/')} but the call succeeded');
      } on ApiFailure catch (e) {
        expectTrue(statuses.contains(e.status), 'expected HTTP ${statuses.join('/')}, got ${e.status}');
      }
    }

    final admin = useSavedSession ? await Session.fromSavedSession() : await Session.signIn(adminEmail, adminPassword);
    final adminCompany = asMap(admin.user['company'])?['id'];
    if (adminCompany != companyId) {
      await admin.signOut();
      fail('Refusing to write: the admin account belongs to company $adminCompany, not the confirmed sandbox company $companyId.');
    }
    debugPrint('SANDBOX tenant guard: admin is in the confirmed sandbox company');
    final start = DateTime.now().toUtc().add(const Duration(days: 30));
    final slot = DateTime.utc(start.year, start.month, start.day, 10);

    try {
      final meetingId = await step('meeting create', () async {
        final r = await admin.call('meetings', method: 'POST', data: {
          'title': name('Meeting'),
          'type': 'virtual',
          'start_time': slot.toIso8601String(),
          'end_time': slot.add(const Duration(minutes: 30)).toIso8601String(),
          'timezone': 'UTC',
          'participant_ids': <int>[],
          'is_private': false,
          'is_client_meeting': false,
          'reminder_minutes': 15,
          'recurrence_frequency': 'none',
        });
        final found = await admin.call('meetings', query: {'search': name('Meeting')});
        final id = (resultOf(r)['id'] ?? (found['data'] as List).first['id']) as int;
        cleanup.add(() async => admin.call('meetings/$id', method: 'DELETE'));
        return id;
      });
      if (meetingId != null) {
        await step('meeting read', () async => expectTrue((await admin.call('meetings/$meetingId'))['data'] is Map, 'no meeting data'));
        await step('meeting update', () => admin.call('meetings/$meetingId', method: 'PUT', data: {
          'title': '${name('Meeting')} edited',
          'type': 'virtual',
          'start_time': slot.toIso8601String(),
          'end_time': slot.add(const Duration(minutes: 45)).toIso8601String(),
          'timezone': 'UTC',
          'participant_ids': <int>[],
        }));
        await step('calendar feed shows the meeting', () async {
          final feed = await admin.call('calendar/feed', query: {
            'start': slot.subtract(const Duration(hours: 1)).toIso8601String(),
            'end': slot.add(const Duration(hours: 2)).toIso8601String(),
          });
          expectTrue((feed['data'] as List).any((e) => e['id'] == meetingId), 'meeting missing from feed');
        });
        final noteId = await step('meeting note create', () async {
          final r = await admin.call('meetings/$meetingId/notes', method: 'POST', data: {
            'agenda': name('Agenda'),
            'discussion': 'Sandbox note',
            'action_items': 'Check sync',
          });
          final id = resultOf(r)['id'] as int?;
          if (id != null) cleanup.add(() async => admin.call('meeting-notes/$id', method: 'DELETE'));
          return id;
        });
        if (noteId != null) {
          await step('meeting note update', () => admin.call('meeting-notes/$noteId', method: 'PUT', data: {'agenda': '${name('Agenda')} edited'}));
        }
        await step('meeting cancel', () => admin.call('meetings/$meetingId/cancel', method: 'PATCH'));
        await step('cancelled meeting frees the slot', () async {
          final r = resultOf(await admin.call('availability/check', method: 'POST', data: {
            'start_time': slot.toIso8601String(),
            'end_time': slot.add(const Duration(minutes: 30)).toIso8601String(),
            'participant_ids': [admin.user['id']],
          }));
          expectTrue(r['has_conflicts'] == false, 'slot still busy after cancel');
        });
      }

      final clientId = await step('client create', () async {
        final r = await admin.call('clients', method: 'POST', data: {
          'company_name': name('Client'),
          'contact_name': 'Sandbox Contact',
          'contact_email': 'sandbox.$stamp@example.test',
          'status': 'discovery',
        });
        final found = await admin.call('clients', query: {'search': name('Client')});
        final id = (resultOf(r)['id'] ?? (found['data'] as List).first['id']) as int;
        cleanup.add(() async => admin.call('clients/$id', method: 'DELETE'));
        return id;
      });
      if (clientId != null) {
        await step('client stage change', () => admin.call('clients/$clientId/status', method: 'PATCH', data: {'status': 'discovery', 'progress': 'Sandbox check'}));
      }

      final taskId = await step('task create', () async {
        final r = await admin.call('tasks', method: 'POST', data: {'title': name('Task'), 'priority': 'medium', 'assigned_to': admin.user['id']});
        final found = await admin.call('tasks', query: {'search': name('Task')});
        return (resultOf(r)['id'] ?? (found['data'] as List).first['id']) as int;
      });
      if (taskId != null) {
        await step('task status in_progress', () => admin.call('tasks/$taskId/status', method: 'PATCH', data: {'status': 'in_progress'}));
        await step('task status completed', () => admin.call('tasks/$taskId/status', method: 'PATCH', data: {'status': 'completed'}));
      }

      if (admin.user['can_manage_rooms'] == true) {
        final roomId = await step('room create', () async {
          await admin.call('rooms', method: 'POST', data: {
            'name': name('Room'),
            'code': 'TST$stamp'.substring(0, 10),
            'location': 'Sandbox',
            'capacity': '4',
            'amenities_text': 'Screen',
            'amenities': ['Screen'],
            'is_active': true,
          });
          final found = await admin.call('rooms', query: {'search': name('Room')});
          final id = (found['data'] as List).first['id'] as int;
          cleanup.add(() async => admin.call('rooms/$id', method: 'DELETE'));
          return id;
        });
        if (roomId != null) await step('room read', () => admin.call('rooms/$roomId'));
      }

      final eventId = await step('event create', () async {
        await admin.call('events', method: 'POST', data: {
          'title': name('Event'),
          'category': 'general',
          'start_time': slot.add(const Duration(days: 1)).toIso8601String(),
          'end_time': slot.add(const Duration(days: 1, hours: 1)).toIso8601String(),
          'is_all_day': false,
          'is_company_wide': false,
        });
        final found = await admin.call('events', query: {'search': name('Event')});
        final id = (found['data'] as List).first['id'] as int;
        cleanup.add(() async => admin.call('events/$id', method: 'DELETE'));
        return id;
      });
      if (eventId != null) await step('event read', () => admin.call('events/$eventId'));

      await step('notifications read and unread restore state', () async {
        final list = await admin.call('notifications', query: {'filter': 'unread', 'status': 'unread'});
        final items = list['data'] as List;
        if (items.isEmpty) return;
        final id = items.first['id'];
        await admin.call('notifications/$id/read', method: 'PATCH');
        await admin.call('notifications/$id/unread', method: 'PATCH');
      });

      if (admin.user['can_administer'] == true) {
        await step('registration submit and reject', () async {
          final email = 'sandbox.applicant.$stamp@example.test';
          final password = 'Sandbox-$stamp-Aa1!';
          final public = Api(client: Dio(BaseOptions(baseUrl: Api.baseUrl, headers: {'Accept': 'application/json'})));
          await public.request('auth/register', method: 'POST', data: {
            'name': name('Applicant'),
            'email': email,
            'password': password,
            'password_confirmation': password,
            'registration_type': 'employee',
            'company_id': companyId,
          });
          final pending = await admin.call('admin/registration-requests', query: {'status': 'pending'});
          final request = (pending['data'] as List).firstWhere((x) => x['email'] == email);
          await admin.call('admin/registration-requests/${request['id']}/options');
          await admin.call('admin/registration-requests/${request['id']}/reject', method: 'PATCH', data: {'rejection_reason': 'Sandbox test'});
        });
      }

      if (staffEmail.isNotEmpty && staffPassword.isNotEmpty) {
        final staff = await Session.signIn(staffEmail, staffPassword);
        await step('staff is in the sandbox company', () async => expectTrue(asMap(staff.user['company'])?['id'] == companyId, 'staff company differs'));
        await step('staff cannot open admin approvals', () => expectStatus(staff.call('admin/registration-requests'), {403}));
        if (meetingId != null) {
          await step('staff cannot delete the admin meeting', () => expectStatus(staff.call('meetings/$meetingId', method: 'DELETE'), {403, 404}));
        }
        await staff.signOut();
      }
    } finally {
      for (final undo in cleanup.reversed) {
        try {
          await undo();
        } catch (_) {}
      }
      debugPrint('SANDBOX cleanup: ${cleanup.length} created records deleted');
      await admin.signOut();
    }
    debugPrint('SANDBOX SUMMARY: ${results.where((r) => r.contains('PASS')).length} pass, ${failures.length} fail');
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
