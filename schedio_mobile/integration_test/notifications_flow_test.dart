import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;

/// Inbox checks on the phone against the real reminder notification of the
/// approved [TEST] meeting 29 (sandbox account only; touches only this
/// account's own notifications).
///
/// Run 1 (the reminder is unread): open it, server read state, Mark unread,
/// View meeting, Mark all read, badge after each step.
/// Run 2 (fresh process, everything read): state persisted after a restart,
/// then the approved cleanup: delete [TEST] meeting 29.
const meetingId = 29;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('notification inbox flow on the phone', (tester) async {
    final failures = <String>[];
    void log(String what, bool ok, [String detail = '']) {
      debugPrint('NFLOW $what: ${ok ? 'PASS' : 'FAIL'}${detail.isEmpty ? '' : ' ($detail)'}');
      if (!ok) failures.add(what);
    }

    void info(String s) => debugPrint('NFLOW INFO $s');

    Future<void> pumpFor(Duration d) async {
      final end = DateTime.now().add(d);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> settle() async {
      await pumpFor(const Duration(milliseconds: 500));
      final end = DateTime.now().add(const Duration(seconds: 40));
      while (find.byWidgetPredicate((w) => w is SchedioLoadingIndicator && w.isLoading).evaluate().isNotEmpty &&
          DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await pumpFor(const Duration(milliseconds: 800));
    }

    Future<void> shot(String name) async {
      debugPrint('QAMARK SHOT $name');
      await pumpFor(const Duration(seconds: 3));
    }

    Future<void> back() async {
      await tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
      await settle();
    }

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    await settle();
    final api = container.read(apiProvider);
    final account = container.read(authProvider).value!;
    info('account ${account.id} timezone ${account.timezone}');

    Future<Json> inbox() => api.request('notifications', query: {'per_page': 50});
    int unreadOf(Json r) => asInt(asMap(r['meta'])?['unread_count']) ?? -1;
    bool forMeeting(Map n) {
      final d = notificationData(asMap(n)!);
      return asInt(d?['meeting_id']) == meetingId || asInt(asMap(d?['payload'])?['meeting_id']) == meetingId;
    }

    Future<Map?> reminder() async =>
        ((await inbox())['data'] as List).whereType<Map>().where(forMeeting).firstOrNull;
    Future<int?> badge() async {
      container.invalidate(dashboardProvider);
      return (await container.read(dashboardProvider.future)).unread;
    }

    final metrics = asMap(resultOf(await api.request('dashboard'))['metrics']) ?? const {};
    info('dashboard reminder metrics ${{for (final e in metrics.entries) if (e.key.contains('remind') || e.key.contains('unread')) e.key: e.value}}');
    try {
      final m = resultOf(await api.request('meetings/$meetingId'));
      info('meeting $meetingId start ${m['start_time']} status ${m['status']}');
    } on ApiFailure catch (e) {
      info('meeting $meetingId HTTP ${e.status}');
    }
    final first = await inbox();
    final mine = (first['data'] as List).whereType<Map>().where(forMeeting).toList();
    info('inbox total ${asMap(first['meta'])?['total']} unread_count ${unreadOf(first)}; notifications for meeting $meetingId: ${mine.length}');
    final n = mine.firstOrNull;
    if (n == null) {
      log('a persistent inbox notification exists for the reminder of meeting $meetingId', false, 'none found');
    } else {
      final d = notificationData(asMap(n)!) ?? const {};
      info('shape: keys ${n.keys.toList()}, type ${n['type']}, data keys ${d.keys.toList()}');
      info('category ${d['category']} created_at ${n['created_at']} read_at ${n['read_at']} remind_at ${d['remind_at']}');
      info('title "${d['title']}" message "${d['message']}"');
      log('a persistent inbox notification exists for the reminder of meeting $meetingId', true, '${n['type']}');
      log('exactly one reminder notification for the meeting (no duplicates)', mine.length == 1, '${mine.length}');
    }

    final run1 = n != null && n['read_at'] == null;
    info(run1 ? 'mode: run 1 (reminder unread)' : 'mode: run 2 (verify after restart)');

    // Open the inbox through the bell.
    await tester.tap(find.byTooltip('Notifications').first);
    await settle();
    final row = find.ancestor(of: find.text('${notificationData(asMap(n ?? {})!)?['title'] ?? '[TEST]'}'), matching: find.byType(RecordTile));
    final meta = find.byKey(const ValueKey('notification-meta'));
    log('inbox shows the reminder row', row.evaluate().isNotEmpty);
    if (meta.evaluate().isNotEmpty) info('row meta "${tester.widget<Text>(meta.first).data}"');
    await shot(run1 ? 'nf-01-inbox-unread' : 'nf-05-inbox-after-restart');

    if (run1 && row.evaluate().isNotEmpty) {
      final badge0 = await badge();
      info('badge before opening $badge0');
      await tester.tap(row.first);
      await settle();
      await pumpFor(const Duration(seconds: 2));
      final afterOpen = await reminder();
      log('opening the notification marks it read on the server', afterOpen?['read_at'] != null);
      final badge1 = await badge();
      log('badge drops after opening', badge0 != null && badge1 == badge0 - 1, '$badge0 -> $badge1');
      await shot('nf-02-detail-read');

      await tester.tap(find.text('Mark unread'));
      await settle();
      final afterUnread = await reminder();
      log('Mark unread persists on the server', afterUnread?['read_at'] == null);
      final badge2 = await badge();
      log('badge rises after Mark unread', badge2 == badge0, '$badge1 -> $badge2');
      await shot('nf-03-detail-unread');

      final view = find.text('View meeting');
      log('detail offers View meeting', view.evaluate().isNotEmpty);
      if (view.evaluate().isNotEmpty) {
        await tester.tap(view);
        await settle();
        log('View meeting opens meeting $meetingId', find.text('[TEST] Reminder Check 01').evaluate().isNotEmpty && find.byType(ErrorPanel).evaluate().isEmpty);
        await shot('nf-04-view-meeting');
        await back();
      }
      await back();

      await tester.tap(find.text('Mark all read'));
      await settle();
      final all = await inbox();
      log('Mark all read: server unread_count is 0', unreadOf(all) == 0, '${unreadOf(all)}');
      final badge3 = await badge();
      log('badge is 0 after Mark all read', badge3 == 0, '$badge3');
      final rowAfter = find.ancestor(of: find.text('${notificationData(asMap(n)!)?['title']}'), matching: find.byType(Opacity));
      log('the row is shown as read after the refresh',
          rowAfter.evaluate().isNotEmpty && tester.widget<Opacity>(rowAfter.first).opacity < 1);
      await shot('nf-04-all-read');
    } else if (n != null) {
      log('after a restart the notification is still read (persisted)', n['read_at'] != null);
      log('after a restart the server unread count is 0', unreadOf(first) == 0, '${unreadOf(first)}');
      log('after a restart the badge is 0', await badge() == 0);
      // Approved cleanup: delete the [TEST] reminder meeting.
      final m = resultOf(await api.request('meetings/$meetingId'));
      if ('${m['title']}'.startsWith('[TEST] Reminder')) {
        try {
          await api.request('meetings/$meetingId', method: 'DELETE');
          info('cleanup: deleted [TEST] meeting $meetingId');
        } on ApiFailure catch (e) {
          info('cleanup: delete failed HTTP ${e.status}');
        }
        try {
          await api.request('meetings/$meetingId');
          info('cleanup: meeting $meetingId still readable');
        } on ApiFailure catch (e) {
          info('cleanup: meeting $meetingId now returns HTTP ${e.status}');
        }
        final after = await reminder();
        info('cleanup: reminder notification after delete ${after == null ? 'gone' : 'kept'}');
      }
    }
    debugPrint('NFLOW SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
  });
}
