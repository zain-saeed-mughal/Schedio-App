import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/calendar/calendar_math.dart';
import 'package:schedio_mobile/main.dart' as app;
import 'package:table_calendar/table_calendar.dart';

/// READ-ONLY device verification for the Calendar Hub and My Meetings fixes,
/// driven through the app's own screens (adb taps are blocked on the phone).
/// The host script reacts to "QAMARK NET OFF/ON" by switching the network.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('calendar + My Meetings on the phone (read-only)', (tester) async {
    final failures = <String>[];
    void log(String what, bool ok, [String detail = '']) {
      debugPrint('CMD $what: ${ok ? 'PASS' : 'FAIL'}${detail.isEmpty ? '' : ' ($detail)'}');
      if (!ok) failures.add(what);
    }

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
      await pumpFor(const Duration(milliseconds: 600));
    }

    Future<void> shot(String name) async {
      debugPrint('QAMARK SHOT $name');
      await pumpFor(const Duration(seconds: 3));
    }

    Object? exception() => tester.takeException();
    List<int> rendered() => [
      for (final e in find.descendant(of: find.byType(TableCalendar<CalendarEntry>), matching: find.byType(Text)).evaluate())
        if (int.tryParse((e.widget as Text).data ?? '') case final int n) n,
    ];
    String title() => tester.widget<Text>(find.byKey(const ValueKey('calendar-range-title'))).data!;
    String? errorText() =>
        find.byType(ErrorPanel).evaluate().isEmpty ? null : tester.widget<ErrorPanel>(find.byType(ErrorPanel).first).message;

    // Detail pages are long lists; scroll until [f] is built and visible.
    Future<bool> reach(Finder f) async {
      for (var i = 0; i < 20; i++) {
        if (f.evaluate().isNotEmpty) {
          final box = tester.getRect(f.first);
          final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
          if (box.top >= 0 && box.bottom <= screen.height - 80) return true;
        }
        await tester.dragFrom(Offset(20, (tester.view.physicalSize / tester.view.devicePixelRatio).height * 0.7), const Offset(0, -420));
        await pumpFor(const Duration(milliseconds: 700));
      }
      return f.evaluate().isNotEmpty;
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
    await settle();
    final account = container.read(authProvider).value!;
    final location = locationFor(account.timezone);
    final today = todayIn(location);
    debugPrint('CMD account user ${account.id}, timezone ${account.timezone}, account today ${DateFormat('yyyy-MM-dd').format(today)}, '
        'phone clock ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())} ${DateTime.now().timeZoneName}');

    // ---------------- My Meetings ----------------
    container.read(shellTabProvider.notifier).go(ShellTab.meetings);
    await settle();
    final rows = find.byType(RecordTile);
    final ids = [for (final e in rows.evaluate()) (e.widget as RecordTile).record.id];
    log('My Meetings list loads (no error)', errorText() == null && ids.isNotEmpty, 'rows ${ids.join(', ')}');
    await shot('cm-01-my-meetings');
    for (final id in ['11', '28']) {
      final row = find.byWidgetPredicate((w) => w is RecordTile && w.record.id == id);
      if (row.evaluate().isEmpty) {
        log('meeting $id is in the list', false);
        continue;
      }
      await tester.ensureVisible(row.first);
      await tester.tap(row.first);
      await settle();
      final err = errorText();
      final notes = find.textContaining('Meeting notes').evaluate().map((e) => (e.widget as Text).data).firstOrNull;
      log('meeting $id detail opens without an error', err == null, err ?? '$notes');
      await shot('cm-02-meeting-$id-detail');
      if (id == '28') log('meeting 28 lists its action items', await reach(find.text('Action items (2)')));
      log('meeting $id detail shows its notes and actions', await reach(find.textContaining('Meeting notes')) && await reach(find.text('Create action item')));
      await shot('cm-02-meeting-$id-actions');
      await back();
    }

    // Retry after a real network failure (Wi-Fi and mobile data off).
    final row28 = find.byWidgetPredicate((w) => w is RecordTile && w.record.id == '28');
    if (row28.evaluate().isNotEmpty) {
      debugPrint('QAMARK NET OFF');
      await pumpFor(const Duration(seconds: 6));
      await tester.ensureVisible(row28.first);
      await tester.tap(row28.first);
      // Network errors are retried 3 times (2, 4, 6 s) before the error shows.
      final end = DateTime.now().add(const Duration(seconds: 60));
      while (errorText() == null && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      final offline = errorText();
      log('offline: meeting detail shows a network error (not a read error)',
          offline != null && offline.startsWith('Could not') && !offline.contains('could not read'), offline ?? 'no error');
      await shot('cm-03-offline-error');
      debugPrint('QAMARK NET ON');
      await pumpFor(const Duration(seconds: 12));
      if (find.text('Try again').evaluate().isNotEmpty) {
        await tester.tap(find.text('Try again').first);
        await settle();
      }
      log('online again: Try again loads the meeting, no stale error', errorText() == null && await reach(find.text('Create action item')),
          errorText() ?? '');
      await shot('cm-04-after-retry');
      await back();
    }

    // Search field + keyboard: no overflow.
    final search = find.byType(TextField).first;
    await tester.tap(search);
    await pumpFor(const Duration(seconds: 2));
    final inset = tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
    final kbError = exception();
    log('My Meetings search with keyboard open: no overflow', kbError == null, 'keyboard ${inset.round()} dp');
    await shot('cm-05-search-keyboard');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();

    // ---------------- Calendar Hub ----------------
    container.read(shellTabProvider.notifier).go(ShellTab.calendar);
    await settle();
    log('week view opens on this week', title() == weekTitle(today), title());
    log('week grid is Monday-Sunday of this week', rendered().join(',') == weekOf(today).map((d) => d.day).join(','), rendered().join(','));
    await shot('cm-10-week');

    await tester.tap(find.text('Month').first);
    await settle();
    log('month view shows this month', title() == DateFormat('MMMM yyyy').format(today), title());
    // Back to January 2026, then forward through December 2026.
    var shown = DateTime.utc(today.year, today.month, 1);
    while (shown.isAfter(DateTime.utc(2026, 1, 1))) {
      await tester.tap(find.byTooltip('Previous'));
      await settle();
      shown = addMonths(shown, -1);
    }
    for (var m = 1; m <= 12; m++) {
      final month = DateTime.utc(2026, m, 1);
      final ok = title() == DateFormat('MMMM yyyy').format(month) &&
          rendered().join(',') == monthGrid(2026, m).map((d) => d.day).join(',');
      log('${DateFormat('MMM yyyy').format(month)}: title and grid', ok,
          '${title()}, 1st is ${DateFormat('EEEE').format(month)}, ${rendered().length} cells');
      log('${DateFormat('MMM yyyy').format(month)}: no layout error', exception() == null);
      await shot('cm-11-month-2026-${'$m'.padLeft(2, '0')}');
      if (m < 12) {
        await tester.tap(find.byTooltip('Next'));
        await settle();
      }
    }
    // Dec 2026 -> Jan 2027 -> ... -> Feb 2028.
    for (var i = 0; i < 14; i++) {
      await tester.tap(find.byTooltip('Next'));
      await settle();
      if (i == 0) log('Dec 2026 -> Next -> January 2027', title() == 'January 2027', title());
    }
    log('Feb 2028: title and 29-day grid', title() == 'February 2028' &&
        rendered().join(',') == monthGrid(2028, 2).map((d) => d.day).join(','), '${title()}, ${rendered().length} cells');
    await shot('cm-12-month-2028-02');
    // Select 29 Feb 2028.
    final feb29 = find.descendant(of: find.byType(TableCalendar<CalendarEntry>), matching: find.text('29'));
    if (feb29.evaluate().isNotEmpty) {
      await tester.tap(feb29.first);
      await settle();
    }
    log('tapping 29 Feb 2028 selects it', find.text('Tuesday, Feb 29').evaluate().isNotEmpty);
    await shot('cm-13-feb29-selected');

    await tester.tap(find.text('Today').last);
    await settle();
    log('Today returns to this month', title() == DateFormat('MMMM yyyy').format(today), title());

    await tester.tap(find.text('Day').first);
    await settle();
    log('day view shows today', title() == DateFormat('EEE, MMM d').format(today) && exception() == null, title());
    await shot('cm-14-day');
    await tester.tap(find.byTooltip('Next'));
    await settle();
    log('day view Next goes to tomorrow', title().contains(DateFormat('MMM d').format(addDays(today, 1))), title());

    await tester.tap(find.text('Agenda').first);
    await settle();
    log('agenda view shows the month', title() == DateFormat('MMMM yyyy').format(addDays(today, 1)) && errorText() == null && exception() == null,
        title());
    await shot('cm-15-agenda');

    await tester.tap(find.text('Week').first);
    await settle();
    await tester.drag(find.byType(TableCalendar<CalendarEntry>), const Offset(-330, 0));
    await settle();
    final swiped = rendered();
    log('week swipe: title follows the grid', swiped.isNotEmpty && title() == weekTitle(addDays(addDays(today, 1), 7)), '${title()} / ${swiped.join(',')}');
    await shot('cm-16-week-swiped');

    Future<void> swipe() async {
      await tester.drag(find.byType(TableCalendar<CalendarEntry>), const Offset(-330, 0));
      await settle();
    }

    // Swipe right after programmatic page changes (where the jump was seen).
    await tester.tap(find.byTooltip('Next'));
    await settle();
    await swipe();
    final afterNext = addDays(addDays(today, 1), 21);
    log('week: Next then swipe moves exactly one more week', title() == weekTitle(afterNext) &&
        rendered().join(',') == weekOf(afterNext).map((d) => d.day).join(','), title());
    await tester.tap(find.text('Today').last);
    await settle();
    await swipe();
    log('week: Today then swipe shows next week', title() == weekTitle(addDays(today, 7)), title());
    await swipe();
    await swipe();
    log('week: three swipes in a row move three weeks', title() == weekTitle(addDays(today, 21)), title());
    await shot('cm-17-week-swipes');

    await tester.tap(find.text('Month').first);
    await settle();
    await tester.tap(find.text('Today').last);
    await settle();
    final thisMonth = DateTime.utc(today.year, today.month, 1);
    for (var i = 1; i <= 3; i++) {
      await swipe();
      final m = addMonths(thisMonth, i);
      log('month swipe $i shows ${DateFormat('MMMM yyyy').format(m)}', title() == DateFormat('MMMM yyyy').format(m) &&
          rendered().join(',') == monthGrid(m.year, m.month).map((d) => d.day).join(','), title());
    }
    await tester.drag(find.byType(TableCalendar<CalendarEntry>), const Offset(330, 0));
    await settle();
    log('month swipe back', title() == DateFormat('MMMM yyyy').format(addMonths(thisMonth, 2)), title());
    await shot('cm-18-month-swipes');
    log('no layout errors in Calendar Hub', exception() == null);

    debugPrint('CMD SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
  });
}
