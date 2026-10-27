import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

/// Device checks against the real production sandbox notification created by
/// the backend team for user 3. Touches only this account's notifications;
/// Mark all read runs only if this is the account's only notification.
///
/// Run 1: inbox, Unread filter, refresh, open (marks read), Mark unread,
/// Mark read, detail navigation, Mark all read, badge after each step.
/// Run 2 (fresh process): read state persisted, then the original read state
/// recorded in run 1 is restored.
const target = 'd75f2da1-a4d0-4ea8-b7d3-ad40e326b9bb';
const phaseKey = 'qa_nreal_phase';
const origKey = 'qa_nreal_original_read';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('real sandbox notification on the phone', (tester) async {
    final failures = <String>[];
    void log(String what, bool ok, [String detail = '']) {
      debugPrint('NREAL $what: ${ok ? 'PASS' : 'FAIL'}${detail.isEmpty ? '' : ' ($detail)'}');
      if (!ok) failures.add(what);
    }

    void info(String s) => debugPrint('NREAL INFO $s');

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

    final prefs = await SharedPreferences.getInstance();
    final run2 = prefs.getInt(phaseKey) == 2;

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    await settle();
    final api = container.read(apiProvider);
    final account = container.read(authProvider).value!;
    info('${run2 ? 'run 2 (after restart)' : 'run 1'}; account ${account.id} timezone ${account.timezone}; API ${Uri.parse(Api.baseUrl).host}; '
        'phone clock ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())} ${DateTime.now().timeZoneName}');

    Future<Json> inbox([Map<String, Object> q = const {}]) => api.request('notifications', query: {'per_page': 50, ...q});
    int unreadOf(Json r) => asInt(asMap(r['meta'])?['unread_count']) ?? -1;
    Future<Map?> fetch() async => ((await inbox())['data'] as List).whereType<Map>().where((n) => n['id'] == target).firstOrNull;
    Future<int?> badge() async {
      container.invalidate(dashboardProvider);
      return (await container.read(dashboardProvider.future)).unread;
    }

    final first = await inbox();
    final items = (first['data'] as List).whereType<Map>().toList();
    final total = asInt(asMap(first['meta'])?['total']) ?? items.length;
    final n = items.where((n) => n['id'] == target).firstOrNull;
    info('production inbox: total $total, unread_count ${unreadOf(first)}, ids ${items.map((e) => '${e['id']}'.substring(0, 8)).toList()}');
    log('the sandbox notification is fetched from the production API', n != null, Uri.parse(Api.baseUrl).host);
    if (n == null) {
      debugPrint('NREAL SUMMARY: ${failures.join(' | ')}');
      return;
    }
    final d = notificationData(asMap(n)!) ?? const {};
    final record = Record.fromJson(asMap(n)!, Module.notifications);
    info('shape: keys ${n.keys.toList()}; type ${n['type']}; data keys ${d.keys.toList()}; data is ${n['data'].runtimeType}');
    info('server formatting: timezone ${n['timezone']}; created_at_formatted "${n['created_at_formatted']}"; time_formatted "${n['time_formatted']}"; top-level type ${n['type']}');
    info('category ${d['category']}; title "${d['title']}"; read_at ${n['read_at']}; created_at ${n['created_at']}; meeting_id ${record.meetingId}; task_id ${record.taskId}');
    log('parsed: title, kind and time', record.title == '[TEST] Schedio Notification Inbox' && record.notificationKind == NotificationKind.reminder && record.created != null,
        '${record.title} / ${record.notificationKind} / ${record.created}');
    final safeMarkAll = total == 1;
    info('Mark all read is ${safeMarkAll ? 'safe (this is the only notification)' : 'skipped (other notifications exist)'}');

    final b0 = await badge();
    log('badge equals the server unread count', b0 == unreadOf(first), 'badge $b0, server ${unreadOf(first)}');

    // Inbox through the bell.
    await tester.tap(find.byTooltip('Notifications').first);
    await settle();
    final row = find.ancestor(of: find.text(record.title), matching: find.byType(RecordTile));
    log('inbox shows the notification', row.evaluate().isNotEmpty);
    final metaText = find.descendant(of: row, matching: find.byKey(const ValueKey('notification-meta')));
    final shown = metaText.evaluate().isEmpty ? '' : tester.widget<Text>(metaText.first).data ?? '';
    final expected = 'REMINDER  ·  ${notificationTime(record.created, account.timezone)}';
    final wrongZone = DateFormat('h:mm a').format(record.created!.toLocal());
    info('row label "$shown"; expected "$expected"; phone-clock time would be $wrongZone');
    log('time shown in the account timezone (${account.timezone}), not the phone clock', shown == expected, shown);

    if (run2) {
      final now = await fetch();
      final opacity = tester.widget<Opacity>(find.ancestor(of: find.text(record.title), matching: find.byType(Opacity)).first).opacity;
      log('after a restart the notification is still read on the server', now?['read_at'] != null, '${now?['read_at']}');
      log('after a restart the row is shown as read', opacity < 1, 'opacity $opacity');
      log('after a restart the badge matches the server', await badge() == unreadOf(await inbox()));
      await shot('nr-07-after-restart');
      final original = prefs.getBool(origKey);
      if (original == false) {
        await api.request('notifications/$target/unread', method: 'PATCH');
      }
      final restored = await fetch();
      log('original read state restored', (restored?['read_at'] != null) == (original ?? true),
          'original ${original == false ? 'unread' : 'read'}, now ${restored?['read_at'] == null ? 'unread' : 'read'}');
      await prefs.remove(phaseKey);
      await prefs.remove(origKey);
      debugPrint('NREAL SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
      return;
    }

    await prefs.setBool(origKey, n['read_at'] != null);
    await shot('nr-01-inbox');

    // Make it unread through the app if it is read, so every step is exercised.
    if (n['read_at'] != null) {
      await tester.tap(row.first);
      await settle();
      await tester.tap(find.text('Mark unread'));
      await settle();
      await back();
    }
    final unread0 = unreadOf(await inbox());
    final b1 = await badge();
    log('badge follows the server after Mark unread', b1 == unread0, 'badge $b1, server $unread0');

    // Unread filter, then pull to refresh.
    await tester.tap(find.text('Unread').first);
    await settle();
    log('Unread filter shows the unread notification', find.text(record.title).evaluate().isNotEmpty);
    await shot('nr-02-unread-filter');
    await tester.tap(find.text('All').first);
    await settle();
    final before = (await inbox())['meta'];
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 500), 1500);
    await settle();
    log('pull to refresh keeps the list with no error', find.text(record.title).evaluate().isNotEmpty && find.byType(ErrorPanel).evaluate().isEmpty, 'meta $before');

    // Open: marks read on the server.
    await tester.tap(find.ancestor(of: find.text(record.title), matching: find.byType(RecordTile)).first);
    await settle();
    await pumpFor(const Duration(seconds: 2));
    log('detail opens with title and message', find.text(record.title).evaluate().isNotEmpty && find.byType(ErrorPanel).evaluate().isEmpty);
    log('opening marks it read on the server', (await fetch())?['read_at'] != null);
    final b2 = await badge();
    log('badge drops after opening', b1 != null && b2 == b1 - 1, '$b1 -> $b2');
    await shot('nr-03-detail-read');

    await tester.tap(find.text('Mark unread'));
    await settle();
    log('Mark unread persists on the server', (await fetch())?['read_at'] == null);
    log('badge rises after Mark unread', await badge() == b1);
    await shot('nr-04-detail-unread');
    await tester.tap(find.text('Mark read'));
    await settle();
    log('Mark read persists on the server', (await fetch())?['read_at'] != null);
    log('badge drops after Mark read', await badge() == b2);

    // Detail navigation.
    if (record.meetingId != null || record.taskId != null) {
      final label = record.meetingId != null ? 'View meeting' : 'View task';
      log('detail offers $label', find.text(label).evaluate().isNotEmpty);
      if (find.text(label).evaluate().isNotEmpty) {
        await tester.tap(find.text(label));
        await settle();
        final err = find.byType(ErrorPanel).evaluate().isEmpty ? null : tester.widget<ErrorPanel>(find.byType(ErrorPanel).first).message;
        info('$label opened: ${err == null ? 'detail loaded' : 'error shown: $err'}');
        log('$label opens a screen without crashing', tester.takeException() == null);
        await shot('nr-05-linked-record');
        await back();
      }
    } else {
      info('the notification has no meeting_id or task_id: the detail screen is its destination');
      log('detail has no link button when there is no target', find.text('View meeting').evaluate().isEmpty && find.text('View task').evaluate().isEmpty);
    }

    // Leave it unread, then Mark all read from the inbox (only if safe).
    await tester.tap(find.text('Mark unread'));
    await settle();
    await back();
    if (safeMarkAll) {
      await tester.tap(find.text('Mark all read'));
      await settle();
      final all = await inbox();
      log('Mark all read: server unread_count is 0', unreadOf(all) == 0, '${unreadOf(all)}');
      log('badge is 0 after Mark all read', await badge() == 0);
      final opacity = tester.widget<Opacity>(find.ancestor(of: find.text(record.title), matching: find.byType(Opacity)).first).opacity;
      log('row shown as read after Mark all read', opacity < 1, 'opacity $opacity');
      await shot('nr-06-all-read');
    } else {
      await api.request('notifications/$target/read', method: 'PATCH');
      info('Mark all read skipped; marked this one read for the restart check');
    }
    await prefs.setInt(phaseKey, 2);
    info('run 1 leaves the notification read; run 2 checks it after a restart and restores the original state');
    debugPrint('NREAL SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
  });
}
