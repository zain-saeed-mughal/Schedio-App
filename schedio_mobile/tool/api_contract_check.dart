import 'dart:convert';
import 'dart:io';

class Route {
  final String method;
  final String path;
  final bool auth;
  final List<String> keys;
  final String query;
  const Route(
    this.method,
    this.path, {
    this.auth = true,
    this.keys = const [],
    this.query = '',
  });
  bool get readable => method == 'GET' && !path.contains('{');
}

const routes = [
  Route('POST', 'auth/login', auth: false),
  Route('POST', 'auth/register', auth: false),
  Route('GET', 'auth/registration-options', auth: false, keys: ['data']),
  Route('GET', 'auth/me', keys: ['data']),
  Route('POST', 'auth/logout'),
  Route('GET', 'dashboard', keys: ['data']),
  Route('GET', 'lookups', keys: ['data']),
  Route(
    'GET',
    'calendar/feed',
    keys: ['data'],
    query: 'start=2026-01-01T00:00:00Z&end=2026-01-08T00:00:00Z',
  ),
  Route('GET', 'meetings', keys: ['data']),
  Route('POST', 'meetings'),
  Route('GET', 'meetings/{id}'),
  Route('PUT', 'meetings/{id}'),
  Route('DELETE', 'meetings/{id}'),
  Route('PATCH', 'meetings/{id}/cancel'),
  Route('POST', 'meetings/{id}/rsvp'),
  Route('GET', 'meetings/{id}/notes'),
  Route('POST', 'meetings/{id}/notes'),
  Route('GET', 'meeting-notes/{id}'),
  Route('PUT', 'meeting-notes/{id}'),
  Route('DELETE', 'meeting-notes/{id}'),
  Route('POST', 'availability/check'),
  Route(
    'GET',
    'availability/suggestions',
    keys: ['data'],
    query: 'date=2026-01-05&duration_minutes=30',
  ),
  Route('GET', 'clients', keys: ['data', 'meta']),
  Route('POST', 'clients'),
  Route('GET', 'clients/{id}'),
  Route('PUT', 'clients/{id}'),
  Route('DELETE', 'clients/{id}'),
  Route('PATCH', 'clients/{id}/status'),
  Route('GET', 'clients/{id}/meetings'),
  Route('GET', 'tasks', keys: ['data', 'meta']),
  Route('POST', 'tasks'),
  Route('GET', 'tasks/{id}'),
  Route('PATCH', 'tasks/{id}/status'),
  Route('GET', 'rooms', keys: ['data']),
  Route('POST', 'rooms'),
  Route('PUT', 'rooms/{id}'),
  Route('GET', 'events', keys: ['data']),
  Route('POST', 'events'),
  Route('PUT', 'events/{id}'),
  Route('GET', 'notifications', keys: ['data']),
  Route('POST', 'notifications/mark-all-read'),
  Route('POST', 'notifications/preferences'),
  Route('PATCH', 'notifications/{id}/read'),
  Route('PATCH', 'notifications/{id}/unread'),
  Route('DELETE', 'notifications/{id}'),
  Route('GET', 'admin/registration-requests'),
  Route('GET', 'admin/registration-requests/{id}/options'),
  Route('PATCH', 'admin/registration-requests/{id}/approve'),
  Route('PATCH', 'admin/registration-requests/{id}/reject'),
  Route('GET', 'public/booking/{username}', auth: false),
  Route('GET', 'public/booking/{username}/slots', auth: false),
  Route('POST', 'public/booking/{username}', auth: false),
  Route('POST', 'devices'),
  Route('DELETE', 'devices/{token}'),
];

Future<({int status, String type, Object? body})> fetch(
  HttpClient client,
  Uri uri, {
  String? token,
}) async {
  final request = await client.getUrl(uri);
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  if (token != null) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  request.followRedirects = false;
  final response = await request.close().timeout(const Duration(seconds: 20));
  final text = await response.transform(utf8.decoder).join();
  final type = response.headers.contentType?.mimeType ?? '';
  Object? body;
  if (type == 'application/json') {
    try {
      body = jsonDecode(text);
    } catch (_) {}
  }
  return (status: response.statusCode, type: type, body: body);
}

String classify(({int status, String type, Object? body}) r) {
  final message = r.body is Map ? '${(r.body as Map)['message'] ?? ''}' : '';
  if (r.status == 404 && (r.type != 'application/json' || message.startsWith('The route'))) {
    return 'MISSING';
  }
  if (r.status >= 500) return 'ERROR';
  if (r.type != 'application/json') return 'NOT JSON';
  return 'PRESENT';
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/api_contract_check.dart <base url ending in /api/v1/>');
    stderr.writeln('Optional: set SCHEDIO_TOKEN to also check read-only endpoints with a bearer token.');
    exit(64);
  }
  final base = Uri.parse(args.first.endsWith('/') ? args.first : '${args.first}/');
  final token = Platform.environment['SCHEDIO_TOKEN'];
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  var missing = 0, problems = 0;
  stdout.writeln('Schedio mobile API contract check');
  stdout.writeln('Server: $base');
  stdout.writeln('Time: ${DateTime.now().toUtc().toIso8601String()}');
  stdout.writeln('');
  stdout.writeln('| Method | Endpoint | Route | Probe | Authenticated read |');
  stdout.writeln('|---|---|---|---|---|');
  for (final route in routes) {
    final path = route.path
        .replaceAll('{id}', '1')
        .replaceAll('{username}', 'contract-check')
        .replaceAll('{token}', 'contract-check');
    final uri = base.resolve(route.query.isEmpty ? path : '$path?${route.query}');
    String result, probe, authed = '-';
    try {
      final r = await fetch(client, uri);
      result = classify(r);
      probe = 'GET ${r.status} ${r.type.isEmpty ? 'no type' : r.type}';
      if (result == 'PRESENT' && route.auth && route.method == 'GET' && r.status != 401) {
        result = 'OPEN';
      }
      if (token != null && route.readable && result != 'MISSING') {
        final a = await fetch(client, uri, token: token);
        final keys = a.body is Map ? (a.body as Map).keys.toSet() : <dynamic>{};
        final lacking = route.keys.where((k) => !keys.contains(k)).toList();
        authed = a.status == 200 && a.type == 'application/json' && lacking.isEmpty
            ? 'OK 200'
            : 'FAIL ${a.status}${lacking.isEmpty ? '' : ' missing ${lacking.join(',')}'}';
        if (!authed.startsWith('OK')) problems++;
      }
    } catch (e) {
      result = 'UNREACHABLE';
      probe = e.runtimeType.toString();
    }
    if (result == 'MISSING' || result == 'UNREACHABLE') missing++;
    if (['ERROR', 'NOT JSON', 'OPEN'].contains(result)) problems++;
    stdout.writeln('| ${route.method} | `${route.path}` | $result | $probe | $authed |');
  }
  client.close(force: true);
  stdout.writeln('');
  stdout.writeln('Summary: ${routes.length} endpoints, $missing missing or unreachable, $problems with problems.');
  stdout.writeln('PRESENT: route exists (401, 405, 422 or 200 as JSON). MISSING: Laravel route-not-found or an HTML 404. '
      'OPEN: a protected read answered without a token. Probes are GET requests without side effects.');
  exit(missing == 0 && problems == 0 ? 0 : 1);
}
