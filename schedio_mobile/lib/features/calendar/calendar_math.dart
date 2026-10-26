import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Calendar date maths for Calendar Hub. Calendar days are plain dates held as
/// UTC midnights (the same convention table_calendar uses), so adding days is
/// never affected by daylight saving on the phone. Events are exact instants;
/// they are placed on days in the account's timezone.

/// Weeks start on Monday everywhere in Calendar Hub (grid, week view, titles).
const calendarWeekStart = DateTime.monday;

/// First and last day Calendar Hub can show.
final calendarFirstDay = DateTime.utc(1900, 1, 1);
final calendarLastDay = DateTime.utc(2199, 12, 31);

/// The calendar date of [value], ignoring its time and timezone fields.
DateTime dateOf(DateTime value) => DateTime.utc(value.year, value.month, value.day);

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

bool isLeapYear(int year) => year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Today's date in the account's timezone (not the phone's).
DateTime todayIn(tz.Location location, {DateTime? now}) {
  final local = tz.TZDateTime.from(now ?? DateTime.now(), location);
  return DateTime.utc(local.year, local.month, local.day);
}

/// Monday (or [firstWeekday]) of the week containing [d].
DateTime weekStartOf(DateTime d, {int firstWeekday = calendarWeekStart}) {
  final date = dateOf(d);
  return DateTime.utc(date.year, date.month, date.day - (date.weekday - firstWeekday + 7) % 7);
}

List<DateTime> weekOf(DateTime d, {int firstWeekday = calendarWeekStart}) {
  final start = weekStartOf(d, firstWeekday: firstWeekday);
  return [for (var i = 0; i < 7; i++) DateTime.utc(start.year, start.month, start.day + i)];
}

/// Every cell of a month grid: leading days from the previous month, the whole
/// month, and trailing days to finish the last week (4 to 6 rows).
List<DateTime> monthGrid(int year, int month, {int firstWeekday = calendarWeekStart}) {
  final first = weekStartOf(DateTime.utc(year, month, 1), firstWeekday: firstWeekday);
  final lastWeek = weekStartOf(DateTime.utc(year, month, daysInMonth(year, month)), firstWeekday: firstWeekday);
  final cells = DateTime.utc(lastWeek.year, lastWeek.month, lastWeek.day + 7).difference(first).inDays;
  return [for (var i = 0; i < cells; i++) DateTime.utc(first.year, first.month, first.day + i)];
}

/// First day of the month [delta] months away (Dec + 1 = Jan of next year).
DateTime addMonths(DateTime d, int delta) => DateTime.utc(d.year, d.month + delta, 1);

DateTime addDays(DateTime d, int delta) => DateTime.utc(d.year, d.month, d.day + delta);

DateTime clampDay(DateTime d) =>
    d.isBefore(calendarFirstDay) ? calendarFirstDay : (d.isAfter(calendarLastDay) ? calendarLastDay : d);

/// Which day to select when a month is shown: today if it is in that month,
/// otherwise the 1st.
DateTime selectionForMonth(DateTime month, DateTime today) =>
    today.year == month.year && today.month == month.month ? today : DateTime.utc(month.year, month.month, 1);

/// Start of calendar [date] in [location], as an exact instant.
tz.TZDateTime startOfDay(DateTime date, tz.Location location) =>
    tz.TZDateTime(location, date.year, date.month, date.day);

/// Whether an event from [start] to [end] is on any part of calendar [date]
/// in [location]. A zero-length (or reversed) event counts on its start day.
bool occursOn(DateTime start, DateTime end, DateTime date, tz.Location location) =>
    overlaps(start, end, startOfDay(date, location), startOfDay(addDays(date, 1), location));

/// Whether [start]-[end] overlaps the half-open range [from, to).
bool overlaps(DateTime start, DateTime end, DateTime from, DateTime to) {
  if (!end.isAfter(start)) return !start.isBefore(from) && start.isBefore(to);
  return start.isBefore(to) && end.isAfter(from);
}

/// Instants to request from the calendar feed so every visible cell of the
/// month containing [focused] (leading and trailing days included) is covered.
({tz.TZDateTime start, tz.TZDateTime end}) feedRange(DateTime focused, tz.Location location) {
  final cells = monthGrid(focused.year, focused.month);
  return (start: startOfDay(cells.first, location), end: startOfDay(addDays(cells.last, 1), location));
}

/// Minutes after local midnight of [date] at which [instant] falls on the
/// wall clock in [location]; clamped to the day (0 to 1440). Uses wall-clock
/// time, so on daylight-saving days 10:00 is still drawn at 10:00.
int wallMinutes(DateTime instant, DateTime date, tz.Location location) {
  final local = tz.TZDateTime.from(instant, location);
  final localDate = DateTime.utc(local.year, local.month, local.day);
  if (localDate.isBefore(date)) return 0;
  if (localDate.isAfter(date)) return 24 * 60;
  return local.hour * 60 + local.minute;
}

String weekTitle(DateTime d) {
  final days = weekOf(d);
  final from = days.first, to = days.last;
  if (from.year != to.year) {
    return '${DateFormat('MMM d, yyyy').format(from)} to ${DateFormat('MMM d, yyyy').format(to)}';
  }
  return from.month == to.month
      ? '${DateFormat('MMM d').format(from)} to ${to.day}'
      : '${DateFormat('MMM d').format(from)} to ${DateFormat('MMM d').format(to)}';
}
