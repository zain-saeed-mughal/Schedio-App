import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';

/// Read-only company isolation and role check. Run while signed in to an
/// account outside the sandbox company: it tries to read records known to
/// belong to sandbox company 1 and admin-only endpoints. GET requests only;
/// prints status codes and counts, never record contents.
const sandboxCompanyId = int.fromEnvironment('SANDBOX_COMPANY_ID', defaultValue: 1);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('company isolation probe (read-only)', (tester) async {
    await tester.runAsync(() async {
      final api = Api();
      await api.restore();
      final me = (await api.request('auth/me'))['data'] as Json;
      final company = asInt(asMap(me['company'])?['id']);
      debugPrint('ISO signed-in company $company, role ${me['role']}, can_administer ${me['can_administer']}');
      if (company == sandboxCompanyId) {
        debugPrint('ISO not run: signed in to the sandbox company itself');
        return;
      }
      var leaks = 0;
      Future<void> expectBlocked(String path) async {
        try {
          await api.request(path);
          leaks++;
          debugPrint('ISO $path -> 200 LEAK');
        } on ApiFailure catch (e) {
          final ok = e.status == 403 || e.status == 404;
          if (!ok) leaks++;
          debugPrint('ISO $path -> HTTP ${e.status} ${ok ? 'blocked' : 'UNEXPECTED'}');
        }
      }

      // Records created in sandbox company 1 during earlier QA runs.
      for (final id in [1, 5, 10]) {
        await expectBlocked('meetings/$id');
      }
      for (final id in [1, 6]) {
        await expectBlocked('tasks/$id');
      }
      await expectBlocked('meetings/1/notes');
      if (me['can_administer'] != true) {
        await expectBlocked('admin/registration-requests');
      }
      for (final path in ['meetings', 'tasks', 'clients', 'rooms', 'events', 'users']) {
        try {
          final r = await api.request(path, query: {'per_page': 100});
          final rows = (r['data'] is List ? r['data'] as List : const []).whereType<Map>();
          final test = rows.where((x) => '${x['title'] ?? x['name'] ?? x['company_name'] ?? ''}'.startsWith('[TEST]')).length;
          final foreign = rows.where((x) => asInt(asMap(x['company'])?['id'] ?? x['company_id']) == sandboxCompanyId).length;
          if (test > 0 || foreign > 0) leaks++;
          debugPrint('ISO list $path: ${rows.length} rows, sandbox [TEST] rows $test, rows tagged company $sandboxCompanyId $foreign');
        } on ApiFailure catch (e) {
          debugPrint('ISO list $path -> HTTP ${e.status}');
        }
      }
      debugPrint('ISO RESULT: ${leaks == 0 ? 'PASS (no sandbox data visible)' : 'FAIL ($leaks leaks)'}');
    });
  });
}
