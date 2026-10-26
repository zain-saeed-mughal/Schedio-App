import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/push.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';
import 'package:schedio_mobile/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

/// Push checks on the phone with the sandbox account (company 1 only).
/// Launch 1: foreground test push, background test push (the host brings the
/// home screen forward on QAMARK GO_HOME), then one [TEST] meeting whose
/// 15-minute reminder fires about two minutes later for the closed-app and
/// locked-screen check. Launch 2: reads the inbox (read/unread, mark all read
/// when a reminder created an entry) and deletes the [TEST] meeting.
const sandboxCompanyId = int.fromEnvironment('SANDBOX_COMPANY_ID', defaultValue: 1);
const meetingKey = 'qa_push_meeting';
const step = String.fromEnvironment('PUSH_STEP', defaultValue: 'all');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('push in every app state', (tester) async {
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

    final failures = <String>[];
    void log(String what, bool ok) {
      debugPrint('PUSHQA $what: ${ok ? 'PASS' : 'FAIL'}');
      if (!ok) failures.add(what);
    }

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    final api = container.read(apiProvider);
    final me = (await async(() => api.request('auth/me')))['data'] as Json;
    if (asInt(asMap(me['company'])?['id']) != sandboxCompanyId) fail('Not the sandbox company');
    final zone = '${me['timezone'] ?? 'UTC'}';
    final prefs = await async(SharedPreferences.getInstance);
    final push = container.read(pushServiceProvider);
    for (var i = 0; i < 60 && push.status.value != PushStatus.active; i++) {
      await async(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
    }
    log('push registered with the server (status ${push.status.value.name})', push.status.value == PushStatus.active);

    final pending = prefs.getInt(meetingKey);
    if (step == 'tap') {
      // Send while still in front; the host brings the home screen forward at
      // the same moment, so the push lands with Schedio in the background.
      await async(() => Future<void>.delayed(const Duration(seconds: 3)));
      debugPrint('QAMARK HOME_NOW');
      try {
        await async(() => api.request('notifications/test-push', method: 'POST', data: {
          'title': 'Schedio QA tap test',
          'body': 'Tap this notification to open Schedio.',
        }));
        debugPrint('PUSHQA tap-test push sent');
      } on ApiFailure catch (e) {
        debugPrint('PUSHQA tap-test push request: ${e.message}');
      }
      // Keep the real app running so the user's tap is handled by the app
      // itself, and check that it routes to the notifications inbox.
      final inbox = find.text(ModuleCopy.of(Module.notifications).title);
      var opened = false;
      for (var i = 0; i < 180 && !opened; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        opened = inbox.evaluate().isNotEmpty;
      }
      log('tapping the notification opens the notifications inbox', opened);
      await async(() => Future<void>.delayed(const Duration(seconds: 5)));
      debugPrint('PUSHQA SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
      return;
    }
    if (step == 'closed') {
      // Clean up the reminder meeting from the previous run first.
      if (pending != null) {
        await async(() => api.request('meetings/$pending', method: 'DELETE'));
        var gone = false;
        try {
          await async(() => api.request('meetings/$pending'));
        } on ApiFailure catch (e) {
          gone = e.status == 404;
        }
        log('reminder [TEST] meeting $pending deleted', gone);
        await async(() => prefs.remove(meetingKey));
      }
      // Closed app on a locked screen: the user locks the phone, the push is
      // sent and the host kills the process before it arrives.
      debugPrint('QAMARK LOCK_NOW (20 s)');
      await async(() => Future<void>.delayed(const Duration(seconds: 20)));
      final sent = api.request('notifications/test-push', method: 'POST', data: {
        'title': 'Schedio QA closed app',
        'body': 'Closed-app and locked-screen check. Tap to open Schedio.',
      });
      await async(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      debugPrint('QAMARK KILL_ME');
      await async(() => sent.timeout(const Duration(seconds: 20)));
      debugPrint('PUSHQA closed-app push sent but the process was not killed in time');
      return;
    }
    if (pending == null) {
      // Foreground.
      final received = <RemoteMessage>[];
      final sub = FirebaseMessaging.onMessage.listen(received.add);
      await async(() => api.request('notifications/test-push', method: 'POST', data: {
        'title': 'Schedio QA foreground',
        'body': 'Foreground delivery check',
      }));
      for (var i = 0; i < 60 && received.isEmpty; i++) {
        await async(() => Future<void>.delayed(const Duration(milliseconds: 500)));
        await tester.pump();
      }
      await sub.cancel();
      log('foreground test push received in the app (channel ${received.isEmpty ? '-' : received.first.notification?.android?.channelId})', received.length == 1);

      // Background: the host brings the launcher forward, then we send.
      debugPrint('QAMARK GO_HOME');
      await async(() => Future<void>.delayed(const Duration(seconds: 12)));
      try {
        await async(() => api.request('notifications/test-push', method: 'POST', data: {
          'title': 'Schedio QA background',
          'body': 'Background delivery check. Tap to open Schedio.',
        }));
        debugPrint('PUSHQA background test push sent (host checks the tray)');
      } on ApiFailure catch (e) {
        debugPrint('PUSHQA background test push request: ${e.message} (Android may limit a backgrounded app; host checks the tray)');
      }

      // Closed app / locked screen: a real reminder from the server.
      final now = DateTime.now().toUtc();
      final start = DateTime.utc(now.year, now.month, now.day, now.hour, now.minute).add(const Duration(minutes: 17));
      final title = '[TEST] Reminder push ${DateTime.now().millisecondsSinceEpoch}';
      final reply = await async(() => api.request('meetings', method: 'POST', data: {
        'title': title,
        'description': 'Automated QA: reminder delivery check',
        'type': 'virtual',
        'is_private': false,
        'is_client_meeting': false,
        'reminder_minutes': 15,
        'recurrence_frequency': 'none',
        'participant_ids': <int>[],
        'timezone': zone,
        'start_time': apiTime(start, zone),
        'end_time': apiTime(start.add(const Duration(minutes: 15)), zone),
      }));
      var id = asInt(resultOf(reply)['id']);
      if (id == null) {
        final found = (await async(() => api.request('meetings', query: {'search': title})))['data'] as List;
        id = asInt((found.cast<Map>()).firstWhere((m) => m['title'] == title)['id']);
      }
      await async(() => prefs.setInt(meetingKey, id!));
      final at = start.subtract(const Duration(minutes: 15));
      debugPrint('PUSHQA reminder meeting $id created; reminder due at ${timeLabel(at, zone)} ($zone), meeting at ${timeLabel(start, zone)}');
      debugPrint('QAMARK REMINDER_DUE ${at.toIso8601String()}');
    } else {
      // Launch 2: inbox and cleanup.
      final rows = ((await async(() => api.request('notifications', query: {'per_page': 20})))['data'] as List).whereType<Json>().toList();
      debugPrint('PUSHQA inbox entries: ${rows.length}; latest: ${rows.isEmpty ? '-' : '${rows.first['title'] ?? asMap(rows.first['data'])?['title']} at ${rows.first['created_at']}'}');
      if (rows.isNotEmpty) {
        final n = rows.first;
        Future<Map> current() async => ((await api.request('notifications', query: {'per_page': 20}))['data'] as List)
            .cast<Map>()
            .firstWhere((x) => x['id'] == n['id']);
        final wasRead = n['read_at'] != null;
        await async(() => api.request('notifications/${n['id']}/read', method: 'PATCH'));
        log('mark as read persists', (await async(current))['read_at'] != null);
        await async(() => api.request('notifications/${n['id']}/unread', method: 'PATCH'));
        log('mark as unread persists', (await async(current))['read_at'] == null);
        final unread = ((await async(() => api.request('notifications', query: {'filter': 'unread', 'status': 'unread', 'per_page': 100})))['data'] as List)
            .cast<Map>()
            .map((x) => x['id'])
            .toList();
        await async(() => api.request('notifications/mark-all-read', method: 'POST'));
        final left = ((await async(() => api.request('notifications', query: {'filter': 'unread', 'status': 'unread', 'per_page': 100})))['data'] as List).length;
        log('mark all as read leaves 0 unread', left == 0);
        for (final id in unread) {
          await async(() => api.request('notifications/$id/unread', method: 'PATCH'));
        }
        if (wasRead) await async(() => api.request('notifications/${n['id']}/read', method: 'PATCH'));
        final badge = await async(() => container.read(repositoryProvider).inboxUnread());
        log('badge count equals the inbox unread count ($badge vs ${unread.length})', badge == unread.length);
      } else {
        debugPrint('PUSHQA read/unread: NOT TESTED (no inbox entry was created)');
      }
      await async(() => api.request('meetings/$pending', method: 'DELETE'));
      var gone = false;
      try {
        await async(() => api.request('meetings/$pending'));
      } on ApiFailure catch (e) {
        gone = e.status == 404;
      }
      log('reminder [TEST] meeting deleted', gone);
      await async(() => prefs.remove(meetingKey));
    }
    debugPrint('PUSHQA SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
    expect(failures, isEmpty);
  });
}
