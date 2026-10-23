import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';

/// Read-only: compares the unread badge source (dashboard metrics) with the
/// notifications list. Prints counts, keys and types only.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('inbox vs badge probe (read-only)', (tester) async {
    await tester.runAsync(() async {
      final api = Api();
      await api.restore();
      String shape(Object? v) => v is Map ? '{${v.keys.join(', ')}}' : v is List ? 'List(${v.length})' : '$v';
      final dash = resultOf(await api.request('dashboard'));
      final metrics = asMap(dash['metrics']);
      debugPrint('INBOX dashboard keys ${shape(dash)}');
      debugPrint('INBOX dashboard metrics ${jsonEncode(metrics)}');
      for (final q in <Map<String, Object>>[
        {},
        {'filter': 'unread', 'status': 'unread'},
        {'filter': 'unread'},
        {'status': 'unread'},
        {'filter': 'all'},
        {'page': 1, 'per_page': 50},
      ]) {
        final r = await api.request('notifications', query: q);
        final data = r['data'];
        final first = data is List && data.isNotEmpty ? asMap(data.first) : null;
        debugPrint('INBOX notifications $q -> data ${shape(data)}, meta ${jsonEncode(r['meta'])}, top keys ${shape(r)}, first item keys ${first == null ? '-' : shape(first)}');
      }
      debugPrint('INBOX DONE');
    });
  });
}
