import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/app/push_routing.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/push.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';

import 'support/fake_backend.dart';

/// A Laravel database notification as `GET notifications` returns it
/// (`$user->notifications()->paginate()`): uuid id, notification class in
/// `type`, the payload in `data`, and `read_at`.
Map<String, dynamic> dbNotification(
  String id, {
  required String category,
  String cls = 'App\\Notifications\\SessionReminderNotification',
  String title = '[TEST] Upcoming Call',
  String message = '[TEST] Your meeting starts soon',
  bool read = false,
  String createdAt = '2026-10-27T09:00:00.000000Z',
  Map<String, dynamic> extra = const {},
}) => {
  'id': id,
  'type': cls,
  'notifiable_type': 'App\\Models\\User',
  'notifiable_id': 3,
  'data': {'category': category, 'title': title, 'message': message, ...extra},
  'read_at': read ? '2026-10-27T09:30:00.000000Z' : null,
  'created_at': createdAt,
  'updated_at': createdAt,
};

/// A stateful inbox on the fake server: filters, pages, and read/unread
/// writes change what later requests return.
class FakeInbox {
  final List<Map<String, dynamic>> items;
  final int perPage;
  FakeInbox(this.items, {this.perPage = 20});

  int get unread => items.where((n) => n['read_at'] == null).length;

  void install(FakeBackend backend) {
    backend.routes['GET notifications'] = (o) {
      final q = o.queryParameters;
      final onlyUnread = q['status'] == 'unread' || q['filter'] == 'unread';
      final list = onlyUnread ? items.where((n) => n['read_at'] == null).toList() : items;
      final size = int.tryParse('${q['per_page'] ?? perPage}') ?? perPage;
      final page = int.tryParse('${q['page'] ?? 1}') ?? 1;
      final last = list.isEmpty ? 1 : (list.length / size).ceil();
      return (200, {
        'data': list.skip((page - 1) * size).take(size).toList(),
        'meta': {'current_page': page, 'last_page': last, 'per_page': size, 'total': list.length, 'unread_count': unread},
      });
    };
    for (final n in items) {
      backend.routes['PATCH notifications/${n['id']}/read'] = (_) {
        n['read_at'] = '2026-10-27T10:00:00.000000Z';
        return (200, {'message': 'Marked read'});
      };
      backend.routes['PATCH notifications/${n['id']}/unread'] = (_) {
        n['read_at'] = null;
        return (200, {'message': 'Marked unread'});
      };
    }
    backend.routes['POST notifications/mark-all-read'] = (_) {
      for (final n in items) {
        n['read_at'] ??= '2026-10-27T10:00:00.000000Z';
      }
      return (200, {'message': 'All read'});
    };
    backend.routes['GET dashboard'] = (_) => (200, {
      'data': {'metrics': {'unread_notifications': unread}, 'today_meetings': <Object>[], 'upcoming_meetings': <Object>[]},
    });
  }
}

Record parse(Map<String, dynamic> j) => Record.fromJson(j, Module.notifications);

Future<void> pumpFor(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(prepareWidgetTests);

  group('parsing the production notification shape', () {
    test('a reminder: title, message, meeting link, kind, unread and time', () {
      final r = parse(dbNotification('9b1f', category: 'meeting_reminders', extra: {'meeting_id': 28, 'remind_at': '2026-10-27T09:45:00+00:00'}));
      expect(r.id, '9b1f');
      expect(r.title, '[TEST] Upcoming Call');
      expect(r.description, '[TEST] Your meeting starts soon');
      expect(r.meetingId, 28);
      expect(r.notificationKind, NotificationKind.reminder);
      expect(r.isRead, isFalse);
      expect(r.created, DateTime.utc(2026, 10, 27, 9));
    });

    test('the exact production item shape (top-level title, type and is_read; sandbox notification 2026-10-27)', () {
      final r = parse({
        'id': 'd75f2da1-a4d0-4ea8-b7d3-ad40e326b9bb',
        'title': '[TEST] Schedio Notification Inbox',
        'message': '[TEST] message',
        'type': 'meeting_reminder',
        'meeting_id': null,
        'task_id': null,
        'read_at': null,
        'is_read': false,
        'created_at': '2026-10-27T14:41:51+00:00',
        'created_at_formatted': 'Oct 27, 2026 02:41 PM',
        'time_formatted': '02:41 PM',
        'timezone': 'UTC',
        'data': {'category': 'meeting_reminders', 'type': 'meeting_reminder', 'title': '[TEST] Schedio Notification Inbox', 'message': '[TEST] message', 'meeting_id': null, 'action_url': 'https://example.test/dashboard', 'icon': 'bell', 'color': 'amber'},
      });
      expect(r.title, '[TEST] Schedio Notification Inbox');
      expect(r.description, '[TEST] message');
      expect(r.notificationKind, NotificationKind.reminder);
      expect(r.isRead, isFalse);
      expect(r.meetingId, isNull);
      expect(r.taskId, isNull);
      expect(notificationTime(r.created, 'UTC', now: DateTime.utc(2026, 10, 27, 15)), 'Today, 2:41 PM', reason: 'matches the server time_formatted');
    });

    test('each backend category maps to its kind', () {
      const cases = {
        'meeting_reminders': NotificationKind.reminder,
        'meeting_invitations': NotificationKind.invitation,
        'meeting_updates': NotificationKind.update,
        'meeting_cancellations': NotificationKind.cancellation,
        'participant_responses': NotificationKind.response,
        'task_activity': NotificationKind.task,
        'booking_confirmed': NotificationKind.booking,
        'system': NotificationKind.other,
      };
      cases.forEach((category, kind) {
        expect(parse(dbNotification('x', category: category, cls: 'App\\Notifications\\Generic')).notificationKind, kind, reason: category);
      });
    });

    test('without a category the Laravel class name decides the kind', () {
      Record of(String cls) => parse({'id': 'a', 'type': cls, 'data': {'title': 't'}, 'read_at': null});
      expect(of('App\\Notifications\\MeetingCancelledNotification').notificationKind, NotificationKind.cancellation);
      expect(of('App\\Notifications\\MeetingInvitationNotification').notificationKind, NotificationKind.invitation);
      expect(of('App\\Notifications\\TaskActivityNotification').notificationKind, NotificationKind.task);
      expect(of('App\\Notifications\\ParticipantResponseNotification').notificationKind, NotificationKind.response);
    });

    test('a task notification links to its task', () {
      final r = parse(dbNotification('t', category: 'task_activity', cls: 'App\\Notifications\\TaskActivityNotification', extra: {'task_id': 16, 'activity_type': 'assigned'}));
      expect(r.taskId, 16);
      expect(r.meetingId, isNull);
      expect(r.notificationKind, NotificationKind.task);
    });

    test('a reminder whose meeting id is only in the payload still links to it', () {
      final r = parse(dbNotification('p', category: 'meeting_reminders', extra: {'payload': {'meeting_id': 11, 'minutes_before': 15}}));
      expect(r.meetingId, 11);
    });

    test('`data` sent as a JSON string is read', () {
      final r = parse({
        'id': 's',
        'type': 'App\\Notifications\\MeetingUpdatedNotification',
        'data': jsonEncode({'category': 'meeting_updates', 'title': 'Moved', 'message': 'Now at 3 PM', 'meeting_id': 11}),
        'read_at': null,
      });
      expect(r.title, 'Moved');
      expect(r.meetingId, 11);
      expect(r.notificationKind, NotificationKind.update);
    });

    test('null and malformed optional fields do not break a notification', () {
      final r = parse({'id': 7, 'type': null, 'data': {'title': null, 'message': 42, 'meeting_id': 'abc', 'task_id': {'x': 1}}, 'read_at': null, 'created_at': 'not a date'});
      expect(r.id, '7');
      expect(r.title, 'Notification', reason: 'not "Meeting note"');
      expect(r.description, '42');
      expect(r.meetingId, isNull);
      expect(r.created, isNull);
      expect(r.notificationKind, NotificationKind.other);
      final empty = parse({'id': 'e', 'data': null});
      expect(empty.title, 'Notification');
      expect(empty.description, '');
    });

    test('read state comes from read_at (or is_read)', () {
      expect(parse(dbNotification('r', category: 'meeting_updates', read: true)).isRead, isTrue);
      expect(parse({'id': 'b', 'data': {'title': 't'}, 'is_read': true}).isRead, isTrue);
    });
  });

  group('notification times are shown in the account timezone', () {
    final now = DateTime.utc(2026, 10, 27, 12);
    test('today, yesterday, this year and another year', () {
      expect(notificationTime(DateTime.utc(2026, 10, 27, 9, 5), 'UTC', now: now), 'Today, 9:05 AM');
      expect(notificationTime(DateTime.utc(2026, 10, 26, 21), 'UTC', now: now), 'Yesterday, 9:00 PM');
      expect(notificationTime(DateTime.utc(2026, 10, 20, 9), 'UTC', now: now), 'Oct 20, 9:00 AM');
      expect(notificationTime(DateTime.utc(2025, 12, 30, 9), 'UTC', now: now), 'Dec 30, 2025, 9:00 AM');
      expect(notificationTime(null, 'UTC', now: now), '');
    });

    test('midnight: 20:30 UTC is already the next day in Karachi', () {
      final at = DateTime.utc(2026, 10, 26, 20, 30);
      final nowUtc = DateTime.utc(2026, 10, 26, 22);
      expect(notificationTime(at, 'UTC', now: nowUtc), 'Today, 8:30 PM');
      expect(notificationTime(at, 'Asia/Karachi', now: nowUtc), 'Today, 1:30 AM');
      expect(notificationTime(at, 'Asia/Karachi', now: DateTime.utc(2026, 10, 27, 20)), 'Yesterday, 1:30 AM');
    });

    test('New York daylight saving: the same UTC hour shows an hour apart', () {
      final now = DateTime.utc(2026, 11, 10);
      expect(notificationTime(DateTime.utc(2026, 10, 31, 14), 'America/New_York', now: now), 'Oct 31, 10:00 AM');
      expect(notificationTime(DateTime.utc(2026, 11, 2, 14), 'America/New_York', now: now), 'Nov 2, 9:00 AM');
    });
  });

  group('push taps open the right screen', () {
    Widget open(Map<String, dynamic> data) => screenForPush(PushMessage.fromData(data));
    bool opensMeeting(Widget w, String id) => w is RecordScreen && w.initial.module == Module.meetings && w.initial.id == id;
    bool opensTask(Widget w, String id) => w is RecordScreen && w.initial.module == Module.tasks && w.initial.id == id;

    test('meeting events open the meeting', () {
      for (final type in ['meeting_reminder', 'meeting_invitation', 'meeting_updated', 'meeting_cancelled', 'rsvp', 'participant_responses', 'meeting_reminders']) {
        expect(opensMeeting(open({'type': type, 'meeting_id': '28'}), '28'), isTrue, reason: type);
      }
    });

    test('task events open the task, even when the task belongs to a meeting', () {
      expect(opensTask(open({'type': 'task_assigned', 'task_id': '16', 'meeting_id': '28'}), '16'), isTrue);
      expect(opensTask(open({'category': 'task_activity', 'task_id': '17'}), '17'), isTrue, reason: 'category when type is missing');
    });

    test('no target, or an unknown type, opens the inbox', () {
      expect(open({'type': 'meeting_reminder'}), isA<RecordsScreen>());
      expect(open({'type': 'test', 'meeting_id': '5'}), isA<RecordsScreen>());
      expect(open({}), isA<RecordsScreen>());
    });

    test('duplicate FCM deliveries share one key', () {
      final a = PushMessage.fromData({'notification_id': 'n-1', 'type': 'meeting_reminder', 'meeting_id': '28'});
      final b = PushMessage.fromData({'notification_id': 'n-1', 'type': 'meeting_reminder', 'meeting_id': '28'}, title: 'again');
      expect(a.dedupeKey, b.dedupeKey);
    });
  });

  group('Notifications inbox screen', () {
    Future<(FakeBackend, FakeInbox)> openInbox(WidgetTester tester, List<Map<String, dynamic>> items, {int perPage = 20, String zone = 'UTC'}) async {
      phoneSize(tester, height: 2400);
      final backend = FakeBackend(user: {...userFixture(), 'id': 3, 'timezone': zone});
      final inbox = FakeInbox(items, perPage: perPage)..install(backend);
      await tester.pumpWidget(harness(backend, const RecordsScreen(module: Module.notifications)));
      await settle(tester);
      return (backend, inbox);
    }

    testWidgets('a confirmed empty inbox shows the empty state', (tester) async {
      await openInbox(tester, []);
      expect(find.byType(ErrorPanel), findsNothing);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('a server error is shown as an error, never as an empty inbox', (tester) async {
      phoneSize(tester, height: 2400);
      final backend = FakeBackend();
      backend.routes['GET notifications'] = (_) => (500, {'message': 'Server Error'});
      await tester.pumpWidget(harness(backend, const RecordsScreen(module: Module.notifications)));
      await settle(tester);
      expect(find.text('Nothing here yet'), findsNothing);
      expect(find.text('The Schedio server had a problem. Please try again shortly.'), findsOneWidget);
    });

    testWidgets('an unreadable response is an error, not an empty inbox', (tester) async {
      phoneSize(tester, height: 2400);
      final backend = FakeBackend();
      backend.routes['GET notifications'] = (_) => (200, {'data': 'oops'});
      await tester.pumpWidget(harness(backend, const RecordsScreen(module: Module.notifications)));
      await settle(tester);
      expect(find.text('Nothing here yet'), findsNothing);
      expect(find.byType(ErrorPanel), findsOneWidget);
    });

    testWidgets('offline: network error, then Try again loads the inbox', (tester) async {
      phoneSize(tester, height: 2400);
      final backend = FakeBackend(user: {...userFixture(), 'id': 3});
      FakeInbox([dbNotification('n1', category: 'meeting_reminders', extra: {'meeting_id': 28})]).install(backend);
      backend.offline = true;
      await tester.pumpWidget(harness(backend, const RecordsScreen(module: Module.notifications)));
      await settle(tester);
      await pumpFor(tester, 160); // three automatic retries (2, 4, 6 s)
      expect(find.textContaining('Could not reach the Schedio server'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsNothing);
      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.byType(ErrorPanel), findsNothing);
      expect(find.text('[TEST] Upcoming Call'), findsOneWidget);
    });

    testWidgets('a populated inbox shows kind, time, title and message', (tester) async {
      final today = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      await openInbox(tester, [
        dbNotification('n1', category: 'meeting_reminders', createdAt: today.toIso8601String(), extra: {'meeting_id': 28}),
        dbNotification('n2', category: 'task_activity', cls: 'App\\Notifications\\TaskActivityNotification',
            title: '[TEST] New Task Assigned', message: '[TEST] Task assigned', read: true, createdAt: '2025-12-30T09:00:00Z', extra: {'task_id': 16}),
      ]);
      expect(find.text('[TEST] Upcoming Call'), findsOneWidget);
      expect(find.text('[TEST] Your meeting starts soon'), findsOneWidget);
      expect(find.text('[TEST] New Task Assigned'), findsOneWidget);
      final metas = tester.widgetList<Text>(find.byKey(const ValueKey('notification-meta'))).map((t) => t.data).toList();
      expect(metas.first, startsWith('REMINDER  ·  Today, '));
      expect(metas.last, 'TASK  ·  Dec 30, 2025, 9:00 AM');
      expect(find.byIcon(Icons.alarm_rounded), findsOneWidget);
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    });

    testWidgets('pages: Next asks the server for page 2', (tester) async {
      final items = [for (var i = 1; i <= 25; i++) dbNotification('n$i', category: 'meeting_updates', title: '[TEST] Update $i')];
      final (backend, _) = await openInbox(tester, items);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('[TEST] Update 1'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(backend.requests.where((r) => r.path == 'notifications').last.queryParameters['page'], 2);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('[TEST] Update 21'), findsOneWidget);
      expect(find.text('[TEST] Update 1'), findsNothing);
    });

    testWidgets('the Unread filter asks the server for unread only', (tester) async {
      final (backend, _) = await openInbox(tester, [
        dbNotification('n1', category: 'meeting_updates', title: '[TEST] New one'),
        dbNotification('n2', category: 'meeting_updates', title: '[TEST] Old one', read: true),
      ]);
      await tester.tap(find.text('Unread'));
      await settle(tester);
      final q = backend.requests.where((r) => r.path == 'notifications').last.queryParameters;
      expect(q['status'], 'unread');
      expect(find.text('[TEST] New one'), findsOneWidget);
      expect(find.text('[TEST] Old one'), findsNothing);
    });

    testWidgets('opening marks it read on the server; Mark unread and Mark read persist', (tester) async {
      final (backend, inbox) = await openInbox(tester, [dbNotification('n1', category: 'meeting_reminders', extra: {'meeting_id': 28})]);
      expect(inbox.unread, 1);
      await tester.tap(find.text('[TEST] Upcoming Call'));
      await settle(tester);
      expect(backend.requests.any((r) => r.method == 'PATCH' && r.path == 'notifications/n1/read'), isTrue);
      expect(inbox.unread, 0);
      expect(find.text('View meeting'), findsOneWidget);
      await tester.tap(find.text('Mark unread'));
      await settle(tester);
      expect(backend.requests.last.path, isNot('notifications/n1/read'));
      expect(backend.requests.any((r) => r.method == 'PATCH' && r.path == 'notifications/n1/unread'), isTrue);
      expect(inbox.unread, 1);
      expect(find.text('Mark read'), findsOneWidget);
      await tester.tap(find.text('Mark read'));
      await settle(tester);
      expect(inbox.unread, 0);
      // Back in the inbox, the list was refreshed from the server.
      await tester.pageBack();
      await settle(tester);
      final row = tester.widget<Opacity>(find.ancestor(of: find.text('[TEST] Upcoming Call'), matching: find.byType(Opacity)).first);
      expect(row.opacity, 0.7, reason: 'shown as read after the refresh');
    });

    testWidgets('a task notification offers View task', (tester) async {
      await openInbox(tester, [
        dbNotification('t1', category: 'task_activity', cls: 'App\\Notifications\\TaskActivityNotification', title: '[TEST] New Task Assigned', extra: {'task_id': 16}),
      ]);
      await tester.tap(find.text('[TEST] New Task Assigned'));
      await settle(tester);
      expect(find.text('View task'), findsOneWidget);
      expect(find.text('View meeting'), findsNothing);
    });

    testWidgets('Mark all read clears every unread item and the list refreshes', (tester) async {
      final (backend, inbox) = await openInbox(tester, [
        dbNotification('n1', category: 'meeting_updates', title: '[TEST] A'),
        dbNotification('n2', category: 'meeting_invitations', title: '[TEST] B'),
      ]);
      expect(inbox.unread, 2);
      final before = backend.requests.where((r) => r.path == 'notifications').length;
      await tester.tap(find.text('Mark all read'));
      await settle(tester);
      expect(backend.requests.any((r) => r.method == 'POST' && r.path == 'notifications/mark-all-read'), isTrue);
      expect(inbox.unread, 0);
      expect(backend.requests.where((r) => r.path == 'notifications').length, greaterThan(before), reason: 'refetched');
      expect(find.text('All caught up.'), findsOneWidget);
      for (final t in ['[TEST] A', '[TEST] B']) {
        final row = tester.widget<Opacity>(find.ancestor(of: find.text(t), matching: find.byType(Opacity)).first);
        expect(row.opacity, 0.7, reason: '$t shown as read');
      }
    });

    testWidgets('a failed mark read keeps the item unread and says so', (tester) async {
      final (backend, inbox) = await openInbox(tester, [dbNotification('n1', category: 'meeting_reminders')]);
      backend.routes['PATCH notifications/n1/read'] = (_) => (500, {'message': 'Server Error'});
      await tester.tap(find.text('[TEST] Upcoming Call'));
      await settle(tester);
      expect(inbox.unread, 1);
      expect(find.text('Mark read'), findsOneWidget, reason: 'the detail falls back to unread');
    });
  });
}
