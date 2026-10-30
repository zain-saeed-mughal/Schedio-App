import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/app/shell.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/availability/availability_screen.dart';
import 'package:schedio_mobile/features/booking/booking_screen.dart';
import 'package:schedio_mobile/features/settings/settings_screen.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';
import 'package:schedio_mobile/main.dart' as app;

/// Client-demo smoke test on the phone against production. READ-ONLY: it only
/// opens screens and reads data with the saved sandbox session; it creates,
/// edits and deletes nothing, and never types credentials.
/// `QAMARK SHOT name` lines tell the host script to take a screenshot.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('client demo smoke test (read-only, production)', (tester) async {
    final failures = <String>[];
    void log(String what, bool ok, [String detail = '']) {
      debugPrint('DEMO $what: ${ok ? 'PASS' : 'FAIL'}${detail.isEmpty ? '' : ' ($detail)'}');
      if (!ok) failures.add(what);
    }

    void info(String s) => debugPrint('DEMO INFO $s');

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
      await pumpFor(const Duration(milliseconds: 900));
    }

    Future<void> shot(String name) async {
      debugPrint('QAMARK SHOT $name');
      await pumpFor(const Duration(seconds: 3));
    }

    String? errorText() =>
        find.byType(ErrorPanel).evaluate().isEmpty ? null : tester.widget<ErrorPanel>(find.byType(ErrorPanel).first).message;

    Future<void> back() async {
      await tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
      await settle();
    }

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session (sign in once on the phone first)');
    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    await settle();
    final account = container.read(authProvider).value!;
    final api = container.read(apiProvider);
    info('environment ${Env.current.name}; API ${Uri.parse(Api.baseUrl).host}; account ${account.id} (${account.timezone}); '
        'phone clock ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())} ${DateTime.now().timeZoneName}');
    log('production API and environment', Env.current == AppEnvironment.production && Api.baseUrl == 'https://schedio.live/api/v1/', Api.baseUrl);
    log('signed in with the saved sandbox session', account.id > 0, 'user ${account.id}');

    // Times after the TZ-RC1 deployment: stored instants unchanged, now returned in UTC.
    for (final (id, expected) in [(28, '2026-10-27T05:00:00Z'), (29, '2026-10-27T14:45:00Z')]) {
      try {
        final m = resultOf(await api.request('meetings/$id'));
        final raw = '${m['start_time']}';
        final ok = DateTime.parse(raw).isAtSameMomentAs(DateTime.parse(expected));
        log('meeting $id start instant unchanged after TZ-RC1', ok, '$raw = ${DateTime.parse(raw).toUtc().toIso8601String()}');
      } on ApiFailure catch (e) {
        info('meeting $id not readable (HTTP ${e.status})');
      }
    }

    final shellContext = tester.element(find.byType(WorkspaceShell));
    Future<void> openScreen(String name, Widget screen, {String? expectText}) async {
      pushScreen(shellContext, screen);
      await settle();
      final err = errorText();
      final textOk = expectText == null || find.textContaining(expectText).evaluate().isNotEmpty;
      log('$name opens without an error', err == null && textOk && tester.takeException() == null, err ?? (textOk ? '' : 'missing "$expectText"'));
      await shot('demo-${name.toLowerCase().replaceAll(' ', '-')}');
      await back();
    }

    // Dashboard
    container.read(shellTabProvider.notifier).go(ShellTab.home);
    await settle();
    log('dashboard loads', errorText() == null && tester.takeException() == null, errorText() ?? '');
    await shot('demo-01-dashboard');

    // Meetings tab and details
    await tester.tap(find.text('Meetings').last);
    await settle();
    final rows = find.byType(RecordTile);
    log('My Meetings list loads', errorText() == null && rows.evaluate().isNotEmpty, '${rows.evaluate().length} meetings');
    await shot('demo-02-meetings');
    if (rows.evaluate().isNotEmpty) {
      await tester.tap(rows.first);
      await settle();
      log('meeting detail opens', errorText() == null && tester.takeException() == null, errorText() ?? '');
      await shot('demo-03-meeting-detail');
      await back();
    }

    // Calendar tab, all views
    await tester.tap(find.text('Calendar').last);
    await settle();
    log('calendar (week) loads', errorText() == null, errorText() ?? '');
    await shot('demo-04-calendar-week');
    for (final view in ['Month', 'Day', 'Agenda']) {
      final tab = find.text(view);
      if (tab.evaluate().isEmpty) {
        log('calendar $view view available', false);
        continue;
      }
      await tester.tap(tab.first);
      await settle();
      log('calendar ${view.toLowerCase()} view loads', errorText() == null && tester.takeException() == null, errorText() ?? '');
      if (view == 'Month') await shot('demo-05-calendar-month');
    }

    // Pipeline tab
    await tester.tap(find.text('Pipeline').last);
    await settle();
    log('pipeline loads', errorText() == null && tester.takeException() == null, errorText() ?? '');
    await shot('demo-06-pipeline');

    // Back to Home through the bottom bar
    await tester.tap(find.text('Home').last);
    await settle();
    log('bottom navigation returns home', container.read(shellTabProvider) == ShellTab.home);

    // Quick-action screens
    await openScreen('Tasks', const RecordsScreen(module: Module.tasks));
    await openScreen('Notifications', const RecordsScreen(module: Module.notifications));
    await openScreen('Booking', const BookingScreen());
    await openScreen('Rooms', const RecordsScreen(module: Module.rooms));
    await openScreen('Events', const RecordsScreen(module: Module.events));
    await openScreen('Availability', const AvailabilityScreen());

    // Settings and push status
    pushScreen(shellContext, const SettingsScreen());
    await settle();
    await pumpFor(const Duration(seconds: 3));
    final pushText = find.textContaining('for this device').evaluate().map((e) => (e.widget as Text).data ?? '').firstOrNull;
    log('settings opens', errorText() == null && tester.takeException() == null, errorText() ?? '');
    info('push status: ${pushText ?? 'not shown'}');
    await shot('demo-07-settings');
    await back();

    debugPrint('DEMO SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
  });
}
