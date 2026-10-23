import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';

String shape(Object? v, [int depth = 0]) {
  if (v is Map) {
    if (depth >= 3) return 'Map(${v.length} keys)';
    return '{${v.entries.map((e) => '${e.key}: ${shape(e.value, depth + 1)}').join(', ')}}';
  }
  if (v is List) return v.isEmpty ? '[]' : '[${shape(v.first, depth + 1)}] x${v.length}';
  if (v == null) return 'null';
  return v.runtimeType.toString().replaceAll('_', '');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('read-only API shape probe with the saved session (types only, no values)', (tester) async {
    await tester.runAsync(() async {
      final api = Api();
      await api.restore();
      if (api.token == null) {
        debugPrint('SHAPE BLOCKED: no saved session');
        return;
      }
      final now = DateTime.now();
      final day = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));
      final monthStart = DateTime(now.year, now.month).toUtc().toIso8601String();
      final monthEnd = DateTime(now.year, now.month + 1).toUtc().toIso8601String();
      final me = await api.request('auth/me');
      final username = '${asMap(me['data'])?['booking_username'] ?? ''}';
      final probes = <String, Json?>{
        'auth/me': null,
        'dashboard': null,
        'lookups': null,
        'notifications/preferences': null,
        'meetings': {'per_page': 1},
        'clients': {'per_page': 1},
        'clients?status=discovery': {'status': 'discovery', 'per_page': 1},
        'tasks': {'per_page': 1},
        'rooms': {'per_page': 1},
        'events': {'per_page': 1},
        'notifications': {'per_page': 1},
        'admin/registration-requests': {'status': 'pending', 'per_page': 1},
        'departments': null,
        'users': {'per_page': 1},
        'calendar/feed': {'start': monthStart, 'end': monthEnd},
        'availability/suggestions': {'date': day, 'duration_minutes': 30},
        if (username.isNotEmpty) 'public/booking/{username}/slots': {'date': day, 'duration': 30},
      };
      for (final entry in probes.entries) {
        final path = entry.key.split('?').first.replaceAll('{username}', Uri.encodeComponent(username));
        try {
          final r = await api.request(path, query: entry.value);
          debugPrint('SHAPE ${entry.key}: ${shape(r)}');
        } on ApiFailure catch (e) {
          debugPrint('SHAPE ${entry.key}: HTTP ${e.status} ${e.unsupported ? '(route missing)' : ''} ${e.message}');
        } catch (e) {
          debugPrint('SHAPE ${entry.key}: ERROR ${e.runtimeType}');
        }
      }
      final prefs = asMap(asMap(me['data'])?['notification_preferences']) ?? const {};
      final channels = asMap(prefs['channels']) ?? const {};
      final categories = asMap(prefs['categories']) ?? const {};
      final payload = {
        'channel_in_app': channels['in_app'] == true,
        'channel_email': channels['email'] == true,
        'channels': {'in_app': channels['in_app'] == true, 'email': channels['email'] == true},
        'categories': {
          for (final e in categories.entries)
            e.key: {'in_app': asMap(e.value)?['in_app'] == true, 'email': asMap(e.value)?['email'] == true},
        },
      };
      debugPrint('PREFS payload shape (current values, unchanged): ${shape(payload)}');
      try {
        final r = await api.request('notifications/preferences', method: 'POST', data: payload);
        debugPrint('PREFS save same values: OK ${shape(r)}');
      } on ApiFailure catch (e) {
        debugPrint('PREFS save same values: HTTP ${e.status}: ${e.message}');
      } catch (e) {
        debugPrint('PREFS save same values: ERROR ${e.runtimeType}');
      }
      debugPrint('SHAPE DONE');
    });
  });
}
