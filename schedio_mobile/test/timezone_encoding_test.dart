import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/api_time.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// A server that honours offsets (Laravel after the fix): the stored instant
/// is exactly what the ISO string says.
DateTime fixedServerStores(String sent) => DateTime.parse(sent).toUtc();

/// Today's production: Laravel drops the offset and Postgres reads the
/// wall-clock part in its session timezone.
DateTime brokenServerStores(String sent, String sessionZone) {
  final wall = DateTime.parse(sent.substring(0, 19));
  return utc(tz.TZDateTime(tz.getLocation(sessionZone), wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second));
}

/// What a user picks in the form: a wall-clock time in their account zone.
DateTime picked(String accountZone, int y, int m, int d, int h, [int min = 0]) =>
    utc(tz.TZDateTime(locationFor(accountZone), y, m, d, h, min));

/// The same moment as a plain UTC DateTime (TZDateTime never equals DateTime).
DateTime utc(DateTime t) => DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch, isUtc: true);

const accountZones = ['UTC', 'Asia/Karachi', 'America/New_York', 'America/Los_Angeles', 'Europe/London', 'Asia/Kolkata'];

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('default encoding (no compatibility zone): exact UTC instants', () {
    for (final zone in accountZones) {
      test('$zone: a picked time is sent as UTC and means the same moment', () {
        final instant = picked(zone, 2026, 10, 29, 15, 0);
        final sent = encodeApiTime(instant, compatZone: '');
        expect(sent, endsWith('+00:00'));
        expect(fixedServerStores(sent), instant.toUtc());
      });
    }

    test('documents the current bug: without compatibility, the broken server shifts UTC users by 5 hours', () {
      final instant = picked('UTC', 2026, 10, 29, 10, 0);
      final stored = brokenServerStores(encodeApiTime(instant, compatZone: ''), 'Asia/Karachi');
      expect(stored.difference(instant.toUtc()), const Duration(hours: -5));
    });
  });

  group('compatibility zone Asia/Karachi (current production)', () {
    for (final zone in accountZones) {
      test('$zone: correct on the broken server AND on the fixed server (no double conversion)', () {
        for (final instant in [
          picked(zone, 2026, 10, 29, 15, 0),
          picked(zone, 2026, 3, 8, 1, 30),
          picked(zone, 2026, 7, 1, 9, 15),
          picked(zone, 2026, 11, 1, 23, 45),
          picked(zone, 2026, 12, 31, 23, 59),
        ]) {
          final sent = encodeApiTime(instant, compatZone: 'Asia/Karachi');
          expect(sent, endsWith('+05:00'), reason: sent);
          expect(brokenServerStores(sent, 'Asia/Karachi'), instant.toUtc(), reason: 'broken server, $sent');
          expect(fixedServerStores(sent), instant.toUtc(), reason: 'fixed server, $sent');
        }
      });
    }

    test('Hammad (UTC account) picks 10:00: sent as 15:00+05:00, which is 10:00 UTC on both servers', () {
      final instant = picked('UTC', 2026, 10, 29, 10, 0);
      final sent = encodeApiTime(instant, compatZone: 'Asia/Karachi');
      expect(sent, '2026-10-29T15:00:00+05:00');
      expect(brokenServerStores(sent, 'Asia/Karachi'), DateTime.utc(2026, 10, 29, 10));
      expect(fixedServerStores(sent), DateTime.utc(2026, 10, 29, 10));
    });

    test('a Karachi account picking 3:00 PM sends exactly what r9 sent', () {
      final instant = picked('Asia/Karachi', 2026, 10, 29, 15, 0);
      expect(encodeApiTime(instant, compatZone: 'Asia/Karachi'), apiTime(instant, 'Asia/Karachi'));
      expect(encodeApiTime(instant, compatZone: 'Asia/Karachi'), '2026-10-29T15:00:00+05:00');
    });
  });

  group('daylight saving (compatibility zone with DST, e.g. a server in New York)', () {
    test('offsets follow the date: -05:00 in winter, -04:00 in summer', () {
      expect(encodeApiTime(DateTime.utc(2026, 1, 15, 17), compatZone: 'America/New_York'), '2026-01-15T12:00:00-05:00');
      expect(encodeApiTime(DateTime.utc(2026, 7, 15, 16), compatZone: 'America/New_York'), '2026-07-15T12:00:00-04:00');
    });

    test('around the spring change (8 Mar 2026) every instant round-trips on both servers', () {
      for (var m = 0; m < 6 * 60; m += 30) {
        final instant = DateTime.utc(2026, 3, 8, 5).add(Duration(minutes: m));
        final sent = encodeApiTime(instant, compatZone: 'America/New_York');
        expect(fixedServerStores(sent), instant, reason: sent);
        expect(brokenServerStores(sent, 'America/New_York'), instant, reason: sent);
      }
    });

    test('around the autumn change (1 Nov 2026): exact on a fixed server; the repeated hour is the only ambiguity on a broken one', () {
      var ambiguous = 0;
      for (var m = 0; m < 6 * 60; m += 30) {
        final instant = DateTime.utc(2026, 11, 1, 4).add(Duration(minutes: m));
        final sent = encodeApiTime(instant, compatZone: 'America/New_York');
        expect(fixedServerStores(sent), instant, reason: sent);
        if (brokenServerStores(sent, 'America/New_York') != instant) ambiguous++;
      }
      // 01:00-01:59 happens twice; a server that drops offsets cannot tell
      // which one was meant. Asia/Karachi has no DST, so production is not affected.
      expect(ambiguous, lessThanOrEqualTo(2));
    });

    test('Europe/London summer and winter', () {
      expect(encodeApiTime(DateTime.utc(2026, 6, 1, 9), compatZone: 'Europe/London'), '2026-06-01T10:00:00+01:00');
      expect(encodeApiTime(DateTime.utc(2026, 12, 1, 9), compatZone: 'Europe/London'), '2026-12-01T09:00:00+00:00');
    });
  });

  group('display uses the account timezone, whatever the server sends back', () {
    for (final zone in accountZones) {
      test('$zone: a server time read back shows the wall-clock time the user picked', () {
        final instant = picked(zone, 2026, 10, 29, 15, 0);
        // Production answers in +05:00, a fixed server may answer in +00:00.
        for (final reply in [encodeApiTime(instant, compatZone: 'Asia/Karachi'), encodeApiTime(instant, compatZone: '')]) {
          expect(timeLabel(DateTime.parse(reply), zone), '3:00 PM', reason: '$zone $reply');
        }
      });
    }
  });

  test('an unknown compatibility zone falls back to UTC instead of crashing', () {
    expect(encodeApiTime(DateTime.utc(2026, 10, 29, 10), compatZone: 'Not/AZone'), '2026-10-29T10:00:00+00:00');
  });
}
