import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';

/// Read-only website <-> mobile sync probe. Prints the signed-in account's
/// company and every client whose name starts with "[TEST] Sync", as the
/// production API returns them through the app's own client. No emails or
/// tokens are printed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sync probe (read-only)', (tester) async {
    await tester.runAsync(() async {
      final api = Api();
      await api.restore();
      final me = (await api.request('auth/me'))['data'] as Json;
      final company = asMap(me['company']);
      debugPrint('SYNC account: ${me['name']} (user ${me['id']}), role ${me['role']}, company ${company?['id']} ${company?['name']}');
      final list = await api.request('clients', query: {'search': '[TEST] Sync', 'per_page': 100});
      final rows = (list['data'] as List).whereType<Json>().where((c) => '${c['company_name']}'.startsWith('[TEST] Sync')).toList();
      debugPrint('SYNC clients matching "[TEST] Sync": ${rows.length}');
      for (final c in rows) {
        final detail = resultOf(await api.request('clients/${c['id']}'));
        final record = Record.fromJson(detail, Module.clients);
        debugPrint('SYNC client id ${detail['id']}: company_name "${detail['company_name']}", contact_name "${detail['contact_name']}", '
            'status ${detail['status']} (${detail['status_label']}), assigned_to ${nameOf(detail['assigned_to']) ?? detail['assigned_to']} '
            '(id ${asInt(detail['assigned_to'])}), campaign "${detail['campaign']}", deal_value ${detail['deal_value']}, '
            'created ${detail['created_at']}, created_by ${nameOf(detail['created_by'])}, app model stage "${record.status}" owner "${record.owner}"');
      }
      debugPrint('SYNC DONE');
    });
  });
}
