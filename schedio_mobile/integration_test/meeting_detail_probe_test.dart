import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/core/api.dart';

/// Read-only: lists meetings and requests each meeting's detail and notes,
/// printing status codes and response keys only.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('meeting detail probe (read-only)', (tester) async {
    await tester.runAsync(() async {
      final api = Api();
      await api.restore();
      final raw = Dio(BaseOptions(
        baseUrl: Api.baseUrl,
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer ${api.token}'},
        validateStatus: (_) => true,
      ));
      final list = await raw.get('meetings', queryParameters: {'per_page': 50});
      final rows = (list.data is Map && list.data['data'] is List) ? list.data['data'] as List : const [];
      debugPrint('MDP list -> HTTP ${list.statusCode}, ${rows.length} meetings');
      for (final m in rows.whereType<Map>()) {
        final id = m['id'];
        debugPrint('MDP list item $id: status ${m['status']}, keys ${m.keys.toList()}');
        for (final path in ['meetings/$id', 'meetings/$id/notes']) {
          final r = await raw.get(path);
          final body = r.data is Map ? r.data as Map : const {};
          debugPrint('MDP $path -> HTTP ${r.statusCode}${r.statusCode == 200 ? ', keys ${(body['data'] is Map ? (body['data'] as Map).keys.toList() : body.keys.toList())}' : ', message ${body['message']}'}');
        }
      }
      debugPrint('MDP DONE');
    });
  });
}
