import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';

/// Read-only. Reports which company the saved session belongs to, its
/// permissions and how much data the company holds. Prints counts only:
/// no names, emails or tokens.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sandbox probe (read-only)', (tester) async {
    final api = Api();
    await api.restore();
    if (api.token == null) fail('No saved session on this device');
    final me = (await api.request('auth/me'))['data'] as Json;
    final company = asMap(me['company']);
    debugPrint('PROBE company id: ${company?['id']}, name: ${company?['name']}');
    debugPrint('PROBE role: ${me['role']}, status: ${me['status']}');
    for (final k in me.keys.where((k) => k.startsWith('can_') || k.startsWith('is_'))) {
      debugPrint('PROBE $k: ${me[k]}');
    }

    Future<void> count(String path, [Json query = const {}]) async {
      try {
        final r = await api.request(path, query: {...query, 'per_page': 100});
        final meta = asMap(r['meta']);
        final rows = (r['data'] is List ? r['data'] as List : const []).whereType<Map>().toList();
        final testRows = rows.where((x) => '${x['title'] ?? x['name'] ?? x['company_name'] ?? x['agenda'] ?? ''}'.startsWith('[TEST]')).length;
        final companies = rows.map((x) => asMap(x['company'])?['id'] ?? x['company_id']).whereType<Object>().toSet();
        debugPrint('PROBE $path: total ${meta?['total'] ?? rows.length}, first page ${rows.length}, [TEST] on first page $testRows, company ids seen $companies');
      } on ApiFailure catch (e) {
        debugPrint('PROBE $path: HTTP ${e.status} ${e.message}');
      }
    }

    await count('clients');
    await count('tasks');
    await count('meetings');
    await count('events');
    await count('rooms');
    await count('notifications');
    await count('admin/registration-requests', {'status': 'pending'});
    await count('users');
    try {
      final options = resultOf(await api.request('auth/registration-options'));
      final companies = options['companies'];
      debugPrint('PROBE registration companies offered: ${companies is List ? companies.length : 'n/a'}');
    } on ApiFailure catch (e) {
      debugPrint('PROBE registration options: HTTP ${e.status}');
    }
    debugPrint('PROBE DONE (nothing was written)');
  });
}
