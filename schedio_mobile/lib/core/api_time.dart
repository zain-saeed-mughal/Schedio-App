import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// How the app writes date-times it sends to the Schedio API.
///
/// Every value is an exact ISO 8601 instant with its UTC offset, so a server
/// that honours offsets always stores the right moment.
///
/// TEMPORARY BACKEND COMPATIBILITY (`API_WALL_CLOCK_ZONE`)
/// Production currently drops the offset when saving (Laravel writes
/// `Y-m-d H:i:s` into PostgreSQL `timestamptz` columns, and Postgres then reads
/// that wall-clock time in its session timezone, Asia/Karachi). Until that is
/// fixed, build with `--dart-define=API_WALL_CLOCK_ZONE=Asia/Karachi`: values
/// are then written as wall-clock time in that zone with that zone's own
/// offset (daylight saving included). Such a value is still an exact instant,
/// so it stays correct after the backend is fixed and cannot be converted
/// twice. Remove the define once the backend stores offsets correctly (see
/// docs/handover/BACKEND_TIMEZONE_FIX.md); the default then sends UTC.
const apiWallClockZone = String.fromEnvironment('API_WALL_CLOCK_ZONE');

/// Encodes [instant] for the API. [compatZone] defaults to the build setting.
String encodeApiTime(DateTime instant, {String compatZone = apiWallClockZone}) {
  if (compatZone.isNotEmpty) {
    try {
      final location = const ['UTC', 'Etc/UTC', 'GMT', 'Etc/GMT'].contains(compatZone)
          ? tz.UTC
          : tz.getLocation(compatZone);
      return isoWithOffset(tz.TZDateTime.from(instant, location));
    } on tz.LocationNotFoundException {
      if (kDebugMode) debugPrint('API_WALL_CLOCK_ZONE "$compatZone" is not a known timezone; sending UTC');
    }
  }
  return isoWithOffset(instant.toUtc());
}
