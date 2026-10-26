import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/calendar/calendar_math.dart';
import 'package:schedio_mobile/features/calendar/calendar_screen.dart';
import 'package:table_calendar/table_calendar.dart';

import 'support/fake_backend.dart';

/// Day numbers the grid actually renders, in reading order.
List<int> renderedDays(WidgetTester tester) => [
  for (final e in find.descendant(of: find.byType(TableCalendar<CalendarEntry>), matching: find.byType(Text)).evaluate())
    if (int.tryParse((e.widget as Text).data ?? '') case final int n) n,
];

List<String> renderedHeaders(WidgetTester tester) => [
  for (final e in find.descendant(of: find.byType(TableCalendar<CalendarEntry>), matching: find.byType(Text)).evaluate())
    if (RegExp(r'^[A-Z]{3}$').hasMatch((e.widget as Text).data ?? '')) (e.widget as Text).data!,
];

Widget grid(DateTime focused, {DateTime? today, DateTime? selected, bool week = false, ValueChanged<DateTime>? onPage}) =>
    MaterialApp(
      theme: schedioTheme(),
      home: Scaffold(
        body: SizedBox(
          width: 380,
          child: StyledCalendar(
            focused: focused,
            selected: selected ?? focused,
            today: today ?? DateTime.utc(1999, 1, 1),
            week: week,
            events: (_) => const [],
            onSelect: (_, _) {},
            onPage: onPage ?? (_) {},
          ),
        ),
      ),
    );

String title(WidgetTester tester) =>
    (tester.widget<Text>(find.byKey(const ValueKey('calendar-range-title')))).data!;

Future<void> tapView(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await settle(tester);
}

Future<void> tapNav(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await settle(tester);
}

void main() {
  setUpAll(prepareWidgetTests);

  group('rendered month grid matches the Gregorian calendar', () {
    final months = [
      for (var m = 1; m <= 12; m++) (2026, m),
      for (var m = 1; m <= 12; m++) (2027, m),
      (2024, 2), (2028, 2), (2100, 2), (2000, 2), (2021, 2),
    ];
    for (final (y, m) in months) {
      testWidgets('$y-${'$m'.padLeft(2, '0')}', (tester) async {
        await tester.pumpWidget(grid(DateTime.utc(y, m, 1)));
        await tester.pump();
        expect(renderedHeaders(tester), ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']);
        expect(renderedDays(tester), [for (final d in monthGrid(y, m)) d.day]);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('week view renders the Monday-to-Sunday week, across a year boundary', (tester) async {
    await tester.pumpWidget(grid(DateTime.utc(2026, 12, 31), week: true));
    await tester.pump();
    expect(renderedDays(tester), [28, 29, 30, 31, 1, 2, 3]);
  });

  testWidgets('today is highlighted from the account date passed in, not the phone clock', (tester) async {
    await tester.pumpWidget(grid(DateTime.utc(2026, 10, 1), today: DateTime.utc(2026, 10, 28), selected: DateTime.utc(2026, 10, 5)));
    await tester.pump();
    Color? colorOf(String day) => tester
        .widget<Text>(find.descendant(of: find.byType(TableCalendar<CalendarEntry>), matching: find.text(day)).last)
        .style
        ?.color;
    expect(colorOf('28'), AppColors.amber400, reason: 'account today');
    expect(colorOf('27'), isNot(AppColors.amber400));
  });

  group('Calendar Hub screen', () {
    // The phone's real "today" in UTC (the fixture account's timezone).
    DateTime today() => todayIn(locationFor('UTC'));

    Future<FakeBackend> open(WidgetTester tester, {String zone = 'UTC'}) async {
      phoneSize(tester, height: 2000);
      final backend = FakeBackend(user: {...userFixture(), 'timezone': zone});
      await tester.pumpWidget(harness(backend, const CalendarScreen()));
      await settle(tester);
      return backend;
    }

    testWidgets('month view: 14 months forward and back, no skips, year rolls over, Today returns', (tester) async {
      await open(tester);
      await tapView(tester, 'Month');
      final start = DateTime.utc(today().year, today().month, 1);
      expect(title(tester), DateFormat('MMMM yyyy').format(start));
      for (var i = 1; i <= 14; i++) {
        await tapNav(tester, 'Next');
        final expected = addMonths(start, i);
        expect(title(tester), DateFormat('MMMM yyyy').format(expected), reason: 'next $i');
        expect(renderedDays(tester), [for (final d in monthGrid(expected.year, expected.month)) d.day], reason: 'grid $i');
        expect(find.text(dayHeader(DateTime.utc(expected.year, expected.month, 1))), findsOneWidget,
            reason: 'list follows the shown month');
      }
      for (var i = 13; i >= 0; i--) {
        await tapNav(tester, 'Previous');
        expect(title(tester), DateFormat('MMMM yyyy').format(addMonths(start, i)), reason: 'back to $i');
      }
      await tapNav(tester, 'Next');
      await tester.tap(find.text('Today').last);
      await settle(tester);
      expect(title(tester), DateFormat('MMMM yyyy').format(start));
      expect(find.text(dayHeader(today())), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('week view: title, grid and list move together with the buttons and with a swipe', (tester) async {
      await open(tester);
      final t = today();
      expect(title(tester), weekTitle(t));
      expect(find.text('This week'), findsOneWidget);
      await tapNav(tester, 'Next');
      final next = addDays(t, 7);
      expect(title(tester), weekTitle(next));
      expect(renderedDays(tester), [for (final d in weekOf(next)) d.day]);
      expect(find.text('Week of ${DateFormat('MMM d').format(weekStartOf(next))}'), findsOneWidget);
      // Swipe forward one more week: title and list must follow the grid.
      await tester.drag(find.byType(TableCalendar<CalendarEntry>), const Offset(-330, 0));
      await settle(tester);
      final swiped = addDays(t, 14);
      expect(renderedDays(tester), [for (final d in weekOf(swiped)) d.day]);
      expect(title(tester), weekTitle(swiped), reason: 'title follows a swipe');
      expect(find.text('Week of ${DateFormat('MMM d').format(weekStartOf(swiped))}'), findsOneWidget);
      await tester.tap(find.text('Today').last);
      await settle(tester);
      expect(title(tester), weekTitle(t));
    });

    testWidgets('day view steps across days; agenda steps across months', (tester) async {
      await open(tester);
      await tapView(tester, 'Day');
      final t = today();
      for (var i = 1; i <= 3; i++) {
        await tapNav(tester, 'Next');
      }
      final d = addDays(t, 3);
      expect(title(tester), DateFormat(d.year == t.year ? 'EEE, MMM d' : 'EEE, MMM d, y').format(d));
      expect(find.text(DateFormat('EEE d').format(d).toUpperCase()), findsOneWidget, reason: 'day grid header');
      await tapView(tester, 'Agenda');
      expect(title(tester), DateFormat('MMMM yyyy').format(d));
      await tapNav(tester, 'Next');
      expect(title(tester), DateFormat('MMMM yyyy').format(addMonths(d, 1)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('feed requests cover the visible grid in the account timezone (Asia/Karachi)', (tester) async {
      final backend = await open(tester, zone: 'Asia/Karachi');
      await tapView(tester, 'Month');
      await tapNav(tester, 'Next');
      final feed = backend.requests.where((r) => r.path == 'calendar/feed').last;
      final shown = addMonths(todayIn(locationFor('Asia/Karachi')), 1);
      final range = feedRange(shown, locationFor('Asia/Karachi'));
      expect(DateTime.parse('${feed.queryParameters['start']}').millisecondsSinceEpoch, range.start.millisecondsSinceEpoch);
      expect(DateTime.parse('${feed.queryParameters['end']}').millisecondsSinceEpoch, range.end.millisecondsSinceEpoch);
    });

    testWidgets('events are listed on their local day: 22:00 UTC is the next day in Karachi', (tester) async {
      final t = today();
      final at = DateTime.utc(t.year, t.month, t.day, 22);
      Future<void> check(String zone, DateTime expectedDay) async {
        phoneSize(tester, height: 2000);
        final backend = FakeBackend(user: {...userFixture(), 'timezone': zone});
        backend.routes['GET calendar/feed'] = (_) => (200, {
          'data': [
            {'id': 501, 'title': 'Late call', 'entity_type': 'meeting', 'start_time': at.toIso8601String(), 'end_time': at.add(const Duration(minutes: 30)).toIso8601String()},
          ],
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(harness(backend, CalendarScreen(key: UniqueKey())));
        await settle(tester);
        await tapView(tester, 'Agenda');
        expect(find.text('Late call'), findsOneWidget, reason: zone);
        expect(find.text(dayHeader(expectedDay)), findsOneWidget, reason: '$zone groups it on ${dayHeader(expectedDay)}');
      }
      await check('UTC', t);
      await check('Asia/Karachi', addDays(t, 1));
    });

    testWidgets('a feed error shows a retry that loads again and then shows the data (no stale error)', (tester) async {
      phoneSize(tester, height: 2000);
      final backend = FakeBackend();
      var calls = 0;
      var failing = true;
      backend.routes['GET calendar/feed'] = (_) {
        calls++;
        return failing ? (500, {'message': 'Server Error'}) : (200, {'data': <Object>[]});
      };
      await tester.pumpWidget(harness(backend, const CalendarScreen()));
      await settle(tester);
      expect(find.text('The Schedio server had a problem. Please try again shortly.'), findsOneWidget);
      expect(find.byType(TableCalendar<CalendarEntry>), findsOneWidget, reason: 'grid stays visible');
      final before = calls;
      failing = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(calls, before + 1, reason: 'retry fetched again');
      expect(find.byType(ErrorPanel), findsNothing);
      expect(find.text('A little breathing room'), findsOneWidget);
    });
  });

  testWidgets('day grid draws a 10:00 New York meeting at 10:00 on the DST change day', (tester) async {
    final entry = CalendarEntry.fromJson({
      'id': 1, 'title': 'DST meeting', 'entity_type': 'meeting',
      'start_time': '2026-03-08T14:00:00Z', 'end_time': '2026-03-08T15:00:00Z',
    });
    await tester.pumpWidget(MaterialApp(
      theme: schedioTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 380,
            child: DayTimeGrid(day: DateTime.utc(2026, 3, 8), entries: [entry], timezone: 'America/New_York', onTap: (_) {}),
          ),
        ),
      ),
    ));
    await tester.pump();
    final block = tester.widget<Positioned>(
        find.ancestor(of: find.text('DST meeting'), matching: find.byType(Positioned)).first);
    expect(block.top, (10 - DayTimeGrid.startHour) * DayTimeGrid.hourHeight + 1);
    expect(block.height, closeTo(DayTimeGrid.hourHeight - 2, 0.01));
  });
}
