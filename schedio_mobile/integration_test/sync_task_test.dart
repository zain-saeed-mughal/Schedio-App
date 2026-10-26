import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';
import 'package:schedio_mobile/main.dart' as app;

/// Read-only sync check for a meeting and its action items created on the
/// website. Prints what the API returns and checks the Meetings list, the
/// meeting detail and My Tasks in the app. Writes nothing.
const meetingTitle = String.fromEnvironment('SYNC_MEETING', defaultValue: '[TEST] Sync Meeting 01');
const taskTitle = String.fromEnvironment('SYNC_TASK', defaultValue: '[TEST] Sync Task 01');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('sync meeting + task check (read-only)', (tester) async {
    final failures = <String>[];
    void log(String what, bool ok) {
      debugPrint('SYNCT $what: ${ok ? 'PASS' : 'FAIL'}');
      if (!ok) failures.add(what);
    }

    Future<void> pumpFor(Duration d) async {
      final end = DateTime.now().add(d);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> settle() async {
      await pumpFor(const Duration(milliseconds: 600));
      final end = DateTime.now().add(const Duration(seconds: 30));
      while (find.byWidgetPredicate((w) => w is SchedioLoadingIndicator && w.isLoading).evaluate().isNotEmpty &&
          DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await pumpFor(const Duration(milliseconds: 600));
    }

    Future<void> shot(String name) async {
      debugPrint('QAMARK SHOT $name');
      await pumpFor(const Duration(seconds: 4));
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

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    final api = container.read(apiProvider);
    Future<T> async<T>(Future<T> Function() f) async => (await tester.runAsync(f)) as T;

    final me = (await async(() => api.request('auth/me')))['data'] as Json;
    final company = asMap(me['company']);
    debugPrint('SYNCT account: ${me['name']} (user ${me['id']}), timezone ${me['timezone']}, company ${company?['id']} ${company?['name']}');
    log('account is in Schedio HQ (company 1)', asInt(company?['id']) == 1);

    // API: meeting.
    final meetings = ((await async(() => api.request('meetings', query: {'search': meetingTitle, 'per_page': 50})))['data'] as List)
        .whereType<Json>()
        .where((m) => m['title'] == meetingTitle)
        .toList();
    log('API: exactly one meeting "$meetingTitle" (found ${meetings.length})', meetings.length == 1);
    int? meetingId;
    if (meetings.isNotEmpty) {
      final m = meetings.first;
      meetingId = asInt(m['id']);
      debugPrint('SYNCT API meeting: id ${m['id']}, start ${m['start_time']}, end ${m['end_time']}, timezone ${m['timezone']}, status ${m['status']}, '
          'type ${m['type']}, organizer ${nameOf(m['organizer'])}, client ${nameOf(m['client']) ?? m['client']}, description "${m['description']}"');
    }

    // API: tasks.
    final tasks = ((await async(() => api.request('tasks', query: {'per_page': 100})))['data'] as List)
        .whereType<Json>()
        .where((t) => t['title'] == taskTitle)
        .toList();
    debugPrint('SYNCT API tasks titled "$taskTitle": ${tasks.length}');
    for (final t in tasks) {
      final d = resultOf(await async(() => api.request('tasks/${t['id']}')));
      debugPrint('SYNCT API task: id ${d['id']}, meeting_id ${d['meeting_id']}, assignee ${nameOf(d['assignee'])} (id ${asInt(d['assignee'])}), '
          'creator ${nameOf(d['creator'])}, priority ${d['priority']}, status ${d['status']}, due ${d['due_date']}, description "${d['description']}"');
    }
    log('API: task(s) "$taskTitle" exist', tasks.isNotEmpty);
    log('API: every task is linked to the meeting', tasks.isNotEmpty && tasks.every((t) => asInt(t['meeting_id']) == meetingId));
    if (tasks.length > 1) debugPrint('SYNCT note: ${tasks.length} identical tasks (duplicate submit on the website)');

    // App: Meetings tab.
    await settle();
    await tester.tap(find.text('Meetings').last);
    await settle();
    container.read(refreshProvider.notifier).refresh();
    await settle();
    final meetingRow = find.textContaining(meetingTitle);
    log('Meetings list shows "$meetingTitle"', meetingRow.evaluate().isNotEmpty);
    if (meetingRow.evaluate().isNotEmpty) {
      await tester.ensureVisible(meetingRow.first);
      await settle();
      await shot('11-sync04-meetings-list');
      await tester.tap(meetingRow.first);
      await settle();
      final detail = find.byType(RecordScreen);
      log('meeting detail opens', detail.evaluate().isNotEmpty);
      final linked = find.descendant(of: detail, matching: find.textContaining(taskTitle)).evaluate().length;
      log('meeting detail does not show the title as Agenda', find.descendant(of: detail, matching: find.text('Agenda')).evaluate().isEmpty);
      for (var i = 0; i < 4 && find.textContaining('Action items (').evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
        await settle();
      }
      final card = find.textContaining('Action items (');
      log('meeting detail shows the Action items card (${card.evaluate().isEmpty ? '-' : tester.widget<Text>(card.first).data})', card.evaluate().isNotEmpty);
      if (card.evaluate().isNotEmpty) {
        await tester.ensureVisible(card.first);
        await settle();
        await shot('16-r9-meeting-action-items');
      }
      debugPrint('SYNCT meeting detail shows the task $linked time(s)');
      await shot('12-sync04-meeting-detail');
      for (var i = 0; i < 3 && find.textContaining(taskTitle).evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
        await settle();
      }
      log('meeting detail lists the action item', find.textContaining(taskTitle).evaluate().isNotEmpty);
      if (find.textContaining(taskTitle).evaluate().isNotEmpty) {
        await tester.ensureVisible(find.textContaining(taskTitle).first);
        await settle();
        await shot('13-sync04-meeting-detail-tasks');
      }
      await back();
    }

    // App: My Tasks.
    await tester.tap(find.text('Home').last);
    await settle();
    await tester.tap(find.byType(CenterFab));
    await settle();
    final myTasks = find.descendant(of: find.byType(AppSheet), matching: find.text('My Tasks'));
    await tester.ensureVisible(myTasks);
    await tester.tap(myTasks);
    await settle();
    final shown = find.textContaining(taskTitle).evaluate().length;
    log('My Tasks shows "$taskTitle" ($shown shown, ${tasks.length} in the API)', shown > 0 && shown == tasks.length);
    if (shown > 0) {
      await tester.ensureVisible(find.textContaining(taskTitle).first);
      await settle();
    }
    await shot('14-sync04-my-tasks');
    debugPrint('SYNCT SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
    expect(failures, isEmpty);
  });
}
