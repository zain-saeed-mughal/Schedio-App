import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/calendar/calendar_math.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Independent weekday reference (Zeller's congruence), 1 = Monday .. 7 = Sunday.
int zellerWeekday(int year, int month, int day) {
  var m = month, y = year;
  if (m < 3) {
    m += 12;
    y -= 1;
  }
  final k = y % 100, j = y ~/ 100;
  final h = (day + (13 * (m + 1)) ~/ 5 + k + k ~/ 4 + j ~/ 4 + 5 * j) % 7; // 0 = Saturday
  return (h + 5) % 7 + 1;
}

const weekdayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('month grids match the real Gregorian calendar', () {
    final years = [1900, 2000, 2024, 2025, 2026, 2027, 2028, 2029, 2100];
    for (final year in years) {
      test('every month of $year', () {
        for (var month = 1; month <= 12; month++) {
          final cells = monthGrid(year, month);
          final where = '$year-$month';
          final first = zellerWeekday(year, month, 1);
          expect(DateTime.utc(year, month, 1).weekday, first, reason: '$where weekday of the 1st');
          expect(cells.first.weekday, DateTime.monday, reason: '$where grid starts on Monday');
          expect(cells.last.weekday, DateTime.sunday, reason: '$where grid ends on Sunday');
          expect(cells.length % 7, 0, reason: where);
          expect(cells.length ~/ 7, inInclusiveRange(4, 6), reason: '$where rows');
          final leading = cells.takeWhile((d) => d.month != month).length;
          expect(leading, first - 1, reason: '$where leading cells');
          final inMonth = cells.where((d) => d.month == month && d.year == year).map((d) => d.day).toList();
          expect(inMonth, List.generate(daysInMonth(year, month), (i) => i + 1), reason: '$where every day once, in order');
          for (var i = 1; i < cells.length; i++) {
            expect(cells[i].difference(cells[i - 1]).inDays, 1, reason: '$where consecutive cells');
          }
        }
      });
    }

    test('months do not all start on the same weekday (2026 check)', () {
      final starts = {for (var m = 1; m <= 12; m++) m: weekdayNames[DateTime.utc(2026, m, 1).weekday]};
      expect(starts, {
        1: 'Thursday', 2: 'Sunday', 3: 'Sunday', 4: 'Wednesday', 5: 'Friday', 6: 'Monday',
        7: 'Wednesday', 8: 'Saturday', 9: 'Tuesday', 10: 'Thursday', 11: 'Sunday', 12: 'Tuesday',
      });
    });

    test('2027 month starts', () {
      expect([for (var m = 1; m <= 12; m++) weekdayNames[DateTime.utc(2027, m, 1).weekday]], [
        'Friday', 'Monday', 'Monday', 'Thursday', 'Saturday', 'Tuesday',
        'Thursday', 'Sunday', 'Wednesday', 'Friday', 'Monday', 'Wednesday',
      ]);
    });

    test('months starting on Sunday, Monday, Wednesday and Saturday get 6, 0, 2 and 5 leading cells', () {
      expect(monthGrid(2026, 2).takeWhile((d) => d.month != 2).length, 6); // Sunday
      expect(monthGrid(2026, 6).takeWhile((d) => d.month != 6).length, 0); // Monday
      expect(monthGrid(2026, 7).takeWhile((d) => d.month != 7).length, 2); // Wednesday
      expect(monthGrid(2026, 8).takeWhile((d) => d.month != 8).length, 5); // Saturday
    });

    test('a 28-day February starting on Monday fills exactly 4 rows (Feb 2027)', () {
      final cells = monthGrid(2027, 2);
      expect(cells.length, 28);
      expect(cells.first, DateTime.utc(2027, 2, 1));
      expect(cells.last, DateTime.utc(2027, 2, 28));
    });

    test('a 31-day month starting on Sunday needs 6 rows (Mar 2026)', () {
      expect(monthGrid(2026, 3).length, 42);
    });
  });

  group('leap years', () {
    test('2024 and 2028 are leap years, 2026, 2027 and 2100 are not, 2000 is', () {
      expect({for (final y in [2000, 2024, 2026, 2027, 2028, 2100]) y: isLeapYear(y)},
          {2000: true, 2024: true, 2026: false, 2027: false, 2028: true, 2100: false});
    });

    test('February lengths: 2024 = 29, 2026 = 28, 2028 = 29, 2100 = 28', () {
      expect([daysInMonth(2024, 2), daysInMonth(2026, 2), daysInMonth(2028, 2), daysInMonth(2100, 2)], [29, 28, 29, 28]);
    });

    test('Feb 2026 vs Feb 2028: different start days and lengths', () {
      final a = monthGrid(2026, 2), b = monthGrid(2028, 2);
      expect(DateTime.utc(2026, 2, 1).weekday, DateTime.sunday);
      expect(DateTime.utc(2028, 2, 1).weekday, DateTime.tuesday);
      expect(a.where((d) => d.month == 2).length, 28);
      expect(b.where((d) => d.month == 2).length, 29);
      expect(b.contains(DateTime.utc(2028, 2, 29)), isTrue);
      expect(monthGrid(2100, 2).contains(DateTime.utc(2100, 2, 29)), isFalse);
    });

    test('month lengths for every month of 2026 and 2027', () {
      const normal = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      for (final y in [2026, 2027]) {
        expect([for (var m = 1; m <= 12; m++) daysInMonth(y, m)], normal, reason: '$y');
      }
    });
  });

  group('navigation', () {
    test('24 months forward from Jan 2026: no skipped or repeated months', () {
      var d = DateTime.utc(2026, 1, 1);
      final seen = <String>[];
      for (var i = 0; i < 24; i++) {
        seen.add('${d.year}-${d.month}');
        d = addMonths(d, 1);
      }
      expect(seen, [for (var i = 0; i < 24; i++) '${2026 + i ~/ 12}-${i % 12 + 1}']);
    });

    test('Dec 2026 -> Jan 2027 and back', () {
      expect(addMonths(DateTime.utc(2026, 12, 15), 1), DateTime.utc(2027, 1, 1));
      expect(addMonths(DateTime.utc(2027, 1, 31), -1), DateTime.utc(2026, 12, 1));
    });

    test('moving from the 31st never skips a short month', () {
      expect(addMonths(DateTime.utc(2026, 1, 31), 1), DateTime.utc(2026, 2, 1));
      expect(addMonths(DateTime.utc(2026, 3, 31), -1), DateTime.utc(2026, 2, 1));
    });

    test('day and week steps cross months and years', () {
      expect(addDays(DateTime.utc(2026, 12, 31), 1), DateTime.utc(2027, 1, 1));
      expect(addDays(DateTime.utc(2028, 2, 28), 1), DateTime.utc(2028, 2, 29));
      expect(addDays(DateTime.utc(2026, 2, 28), 1), DateTime.utc(2026, 3, 1));
      expect(addDays(DateTime.utc(2026, 12, 29), 7), DateTime.utc(2027, 1, 5));
    });

    test('a 1000-day walk matches real day counts (no DST drift)', () {
      var d = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 1000; i++) {
        d = addDays(d, 1);
      }
      expect(d, DateTime.utc(2026, 1, 1).add(const Duration(days: 1000)));
    });

    test('selection follows the shown month: today if inside it, otherwise the 1st', () {
      final today = DateTime.utc(2026, 10, 27);
      expect(selectionForMonth(DateTime.utc(2026, 10, 1), today), today);
      expect(selectionForMonth(DateTime.utc(2026, 11, 1), today), DateTime.utc(2026, 11, 1));
    });

    test('the calendar can show Feb 2100 and clamps far dates', () {
      expect(calendarLastDay.isAfter(DateTime.utc(2100, 2, 28)), isTrue);
      expect(clampDay(DateTime.utc(2300, 1, 1)), calendarLastDay);
      expect(clampDay(DateTime.utc(1800, 1, 1)), calendarFirstDay);
    });
  });

  group('weeks (Monday to Sunday)', () {
    test('cross-month week: 29 Oct 2026 is in Mon 26 Oct to Sun 1 Nov', () {
      final w = weekOf(DateTime.utc(2026, 10, 29));
      expect(w.first, DateTime.utc(2026, 10, 26));
      expect(w.last, DateTime.utc(2026, 11, 1));
      expect(weekTitle(DateTime.utc(2026, 10, 29)), 'Oct 26 to Nov 1');
    });

    test('cross-year week: 31 Dec 2026 is in Mon 28 Dec 2026 to Sun 3 Jan 2027', () {
      final w = weekOf(DateTime.utc(2026, 12, 31));
      expect(w.first, DateTime.utc(2026, 12, 28));
      expect(w.last, DateTime.utc(2027, 1, 3));
      expect(weekTitle(DateTime.utc(2027, 1, 2)), 'Dec 28, 2026 to Jan 3, 2027');
    });

    test('same-month week title', () {
      expect(weekTitle(DateTime.utc(2026, 10, 14)), 'Oct 12 to 18');
    });

    test('Sunday belongs to the week that started the Monday before', () {
      expect(weekStartOf(DateTime.utc(2026, 11, 1)), DateTime.utc(2026, 10, 26));
      expect(weekStartOf(DateTime.utc(2026, 10, 26)), DateTime.utc(2026, 10, 26));
    });

    test('every day of 2026-2028 maps to a Monday at most 6 days earlier', () {
      for (var d = DateTime.utc(2026, 1, 1); d.year < 2029; d = addDays(d, 1)) {
        final s = weekStartOf(d);
        expect(s.weekday, DateTime.monday);
        expect(d.difference(s).inDays, inInclusiveRange(0, 6));
      }
    });
  });

  group('timezones', () {
    late final utcZone = locationFor('UTC');
    late final karachi = locationFor('Asia/Karachi');
    late final newYork = locationFor('America/New_York');

    test('today uses the account timezone, not the phone: 20:00 UTC on 27 Oct is already 28 Oct in Karachi', () {
      final now = DateTime.utc(2026, 10, 27, 20);
      expect(todayIn(utcZone, now: now), DateTime.utc(2026, 10, 27));
      expect(todayIn(karachi, now: now), DateTime.utc(2026, 10, 28));
      expect(todayIn(newYork, now: now), DateTime.utc(2026, 10, 27));
      expect(todayIn(newYork, now: DateTime.utc(2026, 10, 28, 3)), DateTime.utc(2026, 10, 27));
    });

    test('New Year: 31 Dec 21:00 UTC is 1 Jan 2027 in Karachi', () {
      expect(todayIn(karachi, now: DateTime.utc(2026, 12, 31, 21)), DateTime.utc(2027, 1, 1));
    });

    test('an event at 22:00 UTC sits on 27 Oct for UTC and 28 Oct for Karachi', () {
      final s = DateTime.utc(2026, 10, 27, 22), e = DateTime.utc(2026, 10, 27, 23);
      expect(occursOn(s, e, DateTime.utc(2026, 10, 27), utcZone), isTrue);
      expect(occursOn(s, e, DateTime.utc(2026, 10, 28), utcZone), isFalse);
      expect(occursOn(s, e, DateTime.utc(2026, 10, 27), karachi), isFalse);
      expect(occursOn(s, e, DateTime.utc(2026, 10, 28), karachi), isTrue);
    });

    test('a production +05:00 time is placed by its instant', () {
      final s = DateTime.parse('2026-10-27T10:00:00+05:00'), e = DateTime.parse('2026-10-27T10:30:00+05:00');
      expect(occursOn(s, e, DateTime.utc(2026, 10, 27), utcZone), isTrue);
      expect(wallMinutes(s, DateTime.utc(2026, 10, 27), utcZone), 5 * 60);
      expect(wallMinutes(s, DateTime.utc(2026, 10, 27), karachi), 10 * 60);
    });

    test('an event ending exactly at midnight does not spill into the next day', () {
      final s = DateTime.utc(2026, 10, 27, 23), e = DateTime.utc(2026, 10, 28);
      expect(occursOn(s, e, DateTime.utc(2026, 10, 28), utcZone), isFalse);
    });

    test('multi-day and cross-year events appear on every day they cover', () {
      final s = DateTime.utc(2026, 12, 30, 9), e = DateTime.utc(2027, 1, 2, 17);
      final days = [for (var d = DateTime.utc(2026, 12, 28); d.isBefore(DateTime.utc(2027, 1, 5)); d = addDays(d, 1)) if (occursOn(s, e, d, utcZone)) d.day];
      expect(days, [30, 31, 1, 2]);
    });

    test('a zero-length event still shows on its day', () {
      final s = DateTime.utc(2026, 10, 27, 9);
      expect(occursOn(s, s, DateTime.utc(2026, 10, 27), utcZone), isTrue);
      expect(occursOn(s, s, DateTime.utc(2026, 10, 26), utcZone), isFalse);
    });

    test('New York DST: days are 23 and 25 hours, events stay on their local day', () {
      expect(startOfDay(DateTime.utc(2026, 3, 9), newYork).difference(startOfDay(DateTime.utc(2026, 3, 8), newYork)).inHours, 23);
      expect(startOfDay(DateTime.utc(2026, 11, 2), newYork).difference(startOfDay(DateTime.utc(2026, 11, 1), newYork)).inHours, 25);
      // 23:30 local on 8 Mar (EDT, 03:30 UTC next day) belongs to 8 Mar.
      final late = DateTime.utc(2026, 3, 9, 3, 30);
      expect(occursOn(late, late.add(const Duration(minutes: 20)), DateTime.utc(2026, 3, 8), newYork), isTrue);
      expect(occursOn(late, late.add(const Duration(minutes: 20)), DateTime.utc(2026, 3, 9), newYork), isFalse);
    });

    test('New York DST: a 10:00 meeting is drawn at 10:00 on both change days (wall clock, not elapsed time)', () {
      expect(wallMinutes(DateTime.utc(2026, 3, 8, 14), DateTime.utc(2026, 3, 8), newYork), 600);
      expect(wallMinutes(DateTime.utc(2026, 11, 1, 15), DateTime.utc(2026, 11, 1), newYork), 600);
    });

    test('wall minutes clamp to the shown day', () {
      expect(wallMinutes(DateTime.utc(2026, 10, 26, 22), DateTime.utc(2026, 10, 27), utcZone), 0);
      expect(wallMinutes(DateTime.utc(2026, 10, 28, 1), DateTime.utc(2026, 10, 27), utcZone), 1440);
    });

    test('the feed request covers every visible cell, in the account timezone', () {
      for (final zone in ['UTC', 'Asia/Karachi', 'America/New_York']) {
        final location = locationFor(zone);
        for (final (y, m) in [(2026, 2), (2026, 3), (2026, 11), (2026, 12), (2027, 1), (2028, 2)]) {
          final r = feedRange(DateTime.utc(y, m, 15), location);
          final cells = monthGrid(y, m);
          expect(r.start, tz.TZDateTime(location, cells.first.year, cells.first.month, cells.first.day), reason: '$zone $y-$m');
          expect(r.end, tz.TZDateTime(location, cells.last.year, cells.last.month, cells.last.day + 1), reason: '$zone $y-$m');
        }
      }
    });

    test('Karachi feed range for Oct 2026 starts at 28 Sep 00:00 PKT (27 Sep 19:00 UTC)', () {
      final r = feedRange(DateTime.utc(2026, 10, 1), karachi);
      expect(r.start.toUtc(), DateTime.utc(2026, 9, 27, 19));
      expect(r.end.toUtc(), DateTime.utc(2026, 11, 1, 19));
    });
  });
}
