import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;

/// Sync test 05 (mobile -> website). Moves only task 16 to In Progress through
/// the app's own task workflow (My Tasks -> task 16 -> Update status -> In
/// Progress), driven by this test because adb taps are blocked on the phone.
/// Verifies through the API and in My Tasks; task 17 must stay unchanged.
const targetId = 16;
const otherId = 17;
const targetTitle = '[TEST] Sync Task 01';
const desired = 'in_progress';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('sync 05: task 16 to In Progress in the app', (tester) async {
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
      debugPrint('SYNC5 $what: ${ok ? 'PASS' : 'FAIL'}');
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

    String summary(Json t) =>
        'id ${t['id']}, title "${t['title']}", status ${t['status']}, priority ${t['priority']}, due ${t['due_date']}, '
        'meeting_id ${t['meeting_id']}, assignee ${nameOf(t['assignee'])} (id ${asInt(t['assignee'])}), completed_at ${t['completed_at']}';

    Finder rowFor(int id) => find.byWidgetPredicate((w) => w is RecordTile && w.record.id == '$id');

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    final api = container.read(apiProvider);

    // Guards.
    final me = (await async(() => api.request('auth/me')))['data'] as Json;
    final company = asMap(me['company']);
    debugPrint('SYNC5 account: ${me['name']} (user ${me['id']}), company ${company?['id']} ${company?['name']}');
    if (asInt(company?['id']) != 1) fail('Refusing: not company 1');
    log('account is in Schedio HQ (company 1)', true);
    final lookups = await async(() => container.read(repositoryProvider).lookups());
    debugPrint('SYNC5 production task statuses: ${lookups.taskStatuses}');
    if (!lookups.taskStatuses.contains(desired)) fail('Refusing: "$desired" is not in the production status list');
    log('production status contract includes $desired', true);
    final before16 = resultOf(await async(() => api.request('tasks/$targetId')));
    final before17 = resultOf(await async(() => api.request('tasks/$otherId')));
    debugPrint('SYNC5 API before task $targetId: ${summary(before16)}');
    debugPrint('SYNC5 API before task $otherId: ${summary(before17)}');
    if (before16['title'] != targetTitle || before16['status'] != 'todo') fail('Refusing: task $targetId is not "$targetTitle" in todo');

    // App workflow: My Tasks -> task 16 -> Update status -> In Progress.
    await settle();
    await tester.tap(find.byType(CenterFab));
    await settle();
    final myTasks = find.descendant(of: find.byType(AppSheet), matching: find.text('My Tasks'));
    await tester.ensureVisible(myTasks);
    await tester.tap(myTasks);
    await settle();
    log('My Tasks lists task $targetId and task $otherId', rowFor(targetId).evaluate().isNotEmpty && rowFor(otherId).evaluate().isNotEmpty);
    await tester.ensureVisible(rowFor(targetId));
    await settle();
    await shot('18-sync05-my-tasks-before');
    await tester.tap(rowFor(targetId));
    await settle();
    final pill = find.widgetWithText(FilterPill, 'In Progress');
    log('task $targetId detail offers "In Progress" in Update status', find.text('Update status').evaluate().isNotEmpty && pill.evaluate().isNotEmpty);
    await tester.ensureVisible(pill.first);
    await settle();
    await shot('19-sync05-task16-detail-before');
    await tester.tap(pill.first);
    var toast = false;
    for (var i = 0; i < 60 && !toast; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      toast = find.text('Status updated').evaluate().isNotEmpty;
    }
    log('app confirms "Status updated"', toast);
    await settle();
    await shot('20-sync05-task16-detail-after');

    // API.
    final after16 = resultOf(await async(() => api.request('tasks/$targetId')));
    final after17 = resultOf(await async(() => api.request('tasks/$otherId')));
    debugPrint('SYNC5 API after task $targetId: ${summary(after16)}');
    debugPrint('SYNC5 API after task $otherId: ${summary(after17)}');
    log('API: task $targetId status is $desired', after16['status'] == desired);
    log('API: task $targetId other fields unchanged',
        ['title', 'priority', 'due_date', 'meeting_id', 'description'].every((k) => '${after16[k]}' == '${before16[k]}') &&
            asInt(after16['assignee']) == asInt(before16['assignee']));
    log('API: task $otherId unchanged', summary(after17) == summary(before17));

    // Refresh My Tasks.
    await back();
    container.read(refreshProvider.notifier).refresh();
    await settle();
    final row16 = rowFor(targetId);
    final shows = row16.evaluate().isNotEmpty && (tester.widget<RecordTile>(row16).record.status == desired) &&
        find.descendant(of: row16, matching: find.textContaining('in progress')).evaluate().isNotEmpty;
    log('after refresh My Tasks shows task $targetId as in progress', shows);
    final row17 = rowFor(otherId);
    log('My Tasks still shows task $otherId as todo', row17.evaluate().isNotEmpty && tester.widget<RecordTile>(row17).record.status == 'todo');
    if (row16.evaluate().isNotEmpty) {
      await tester.ensureVisible(row16);
      await settle();
    }
    await shot('21-sync05-my-tasks-after');
    debugPrint('SYNC5 SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
    expect(failures, isEmpty);
  });
}
