import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('read-only tour of every screen against the configured API', (tester) async {
    final results = <String>[];
    final failures = <String>[];

    Future<void> pumpFor(Duration d) async {
      final end = DateTime.now().add(d);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<bool> waitFor(Finder f, {int seconds = 45}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (f.evaluate().isEmpty && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      return f.evaluate().isNotEmpty;
    }

    Future<void> settleLoad() async {
      await pumpFor(const Duration(milliseconds: 600));
      final end = DateTime.now().add(const Duration(seconds: 40));
      while (find.byWidgetPredicate((w) => w is SchedioLoadingIndicator && w.isLoading).evaluate().isNotEmpty && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await pumpFor(const Duration(milliseconds: 400));
    }

    void record(String screen) {
      final layout = tester.takeException();
      final errors = find.byType(ErrorPanel).evaluate().map((e) => (e.widget as ErrorPanel).message).toList();
      final rows = find.byType(RecordTile).evaluate().length;
      if (layout != null || errors.isNotEmpty) {
        final why = errors.isNotEmpty ? errors.first : '$layout'.split('\n').first;
        failures.add('$screen: $why');
        results.add('TOUR $screen: FAIL ($why)');
      } else {
        results.add('TOUR $screen: PASS${rows > 0 ? ' ($rows rows)' : ''}');
      }
      debugPrint(results.last);
    }

    Future<void> back() async {
      final chip = find.byTooltip('Back');
      if (chip.evaluate().isNotEmpty) {
        await tester.tap(chip.first);
      } else {
        await tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
      }
      await settleLoad();
    }

    Future<void> openFirstRow(String screen) async {
      final rows = find.byType(RecordTile);
      if (rows.evaluate().isEmpty) {
        results.add('TOUR $screen: NOT TESTED (no records)');
        debugPrint(results.last);
        return;
      }
      await tester.ensureVisible(rows.first);
      await tester.tap(rows.first);
      await settleLoad();
      record(screen);
      await back();
    }

    Future<void> quickAction(String label, String screen, {Future<void> Function()? then}) async {
      await tester.tap(find.byType(CenterFab));
      await settleLoad();
      final item = find.descendant(of: find.byType(AppSheet), matching: find.text(label));
      if (!await waitFor(item, seconds: 10)) {
        results.add('TOUR $screen: NOT TESTED (quick action hidden for this role)');
        debugPrint(results.last);
        await tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
        await settleLoad();
        return;
      }
      await tester.ensureVisible(item);
      await tester.tap(item);
      await settleLoad();
      record(screen);
      if (then != null) await then();
      await back();
    }

    debugPrint('TOUR server host: ${Uri.parse(Api.baseUrl).host}');
    app.main();
    final shell = find.byType(WorkspaceShell);
    final signIn = find.text('Sign In to Workspace');
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (shell.evaluate().isEmpty && signIn.evaluate().isEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (shell.evaluate().isEmpty) {
      final notice = ProviderScope.containerOf(tester.element(find.byType(SchedioApp))).read(authNoticeProvider);
      debugPrint('TOUR sign-out reason from the app: ${notice == null ? 'none (no token was stored)' : '${notice.status}: ${notice.message}'}');
      debugPrint('TOUR BLOCKED: no saved session on this device. Sign in by hand once, then rerun.');
      fail('No saved session');
    }
    await settleLoad();
    record('dashboard');

    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    final account = container.read(authProvider).value;
    debugPrint('TOUR account role: ${account?.role}, administer: ${account?.canAdminister}, rooms: ${account?.canManageRooms}');

    for (final tab in ['Calendar', 'Meetings', 'Pipeline']) {
      await tester.tap(find.text(tab).last);
      await settleLoad();
      record('$tab tab');
      if (tab == 'Calendar') {
        for (final view in ['Week', 'Day', 'Agenda', 'Month']) {
          await tester.tap(find.text(view).first);
          await settleLoad();
          record('calendar $view');
        }
      }
      if (tab == 'Meetings') await openFirstRow('meeting detail');
    }
    await tester.tap(find.text('Home').last);
    await settleLoad();

    await quickAction('Schedule Meeting', 'meeting editor (lookups)');
    await quickAction('Reminders and Alerts', 'notifications list');
    await quickAction('My Tasks', 'tasks list', then: () => openFirstRow('task detail'));
    await quickAction('Meeting Suites', 'rooms list', then: () => openFirstRow('room detail'));
    await quickAction('Events and Holidays', 'events list', then: () => openFirstRow('event detail'));
    await quickAction('Check Availability', 'availability');
    await quickAction('My Booking Page', 'booking', then: () async {
      final open = find.text('Open booking profile');
      if (open.evaluate().isNotEmpty) {
        await tester.ensureVisible(open);
        await tester.tap(open);
        await settleLoad();
        record('booking profile and slots');
      }
    });
    await quickAction('Registration Queue', 'registration queue');
    await quickAction('Settings', 'settings');

    final profile = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Your profile');
    if (profile.evaluate().isEmpty) {
      results.add('TOUR profile: FAIL (profile button not found)');
      failures.add('profile: button not found');
      debugPrint(results.last);
    } else {
      await tester.tap(profile.first);
      await settleLoad();
      record('profile');
      await back();
    }

    final push = container.read(pushServiceProvider);
    debugPrint('TOUR push enabled: ${push.enabled}, device token registered with the server: ${push.registeredToken != null ? 'yes' : 'no'}');

    debugPrint('TOUR SUMMARY: ${results.where((r) => r.contains(': PASS')).length} pass, ${failures.length} fail, ${results.where((r) => r.contains('NOT TESTED')).length} not tested');
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
