import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;
import 'package:timezone/timezone.dart' as tz;

/// READ-ONLY My Meetings / Calendar probe (GET requests only).
/// Prints ids, HTTP status codes, field names and value TYPES only - never
/// values, tokens or personal data. For any item the app cannot parse, it
/// finds the exact field by nulling one field at a time.
String shape(Object? v) => switch (v) {
  null => 'null',
  String() => 'String',
  int() => 'int',
  double() => 'double',
  bool() => 'bool',
  List() => 'List(${v.length})${v.isEmpty ? '' : '<${shape(v.first)}>'}',
  Map() => 'Map{${v.keys.join(',')}}',
  _ => v.runtimeType.toString(),
};

/// Returns the field(s) that make [parse] fail, or empty if it parses.
List<String> culprits(Json item, void Function(Json) parse) {
  try {
    parse(item);
    return const [];
  } catch (_) {}
  final found = <String>[];
  for (final k in item.keys) {
    if (k == 'id') continue;
    try {
      parse({...item, k: null});
      found.add(k);
    } catch (_) {}
  }
  return found;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('My Meetings + calendar probe (read-only)', (tester) async {
    Future<T> async<T>(Future<T> Function() f) async {
      Object? error;
      StackTrace? trace;
      T? value;
      await tester.runAsync(() async {
        try {
          value = await f();
        } catch (e, s) {
          error = e;
          trace = s;
        }
      });
      if (error != null) Error.throwWithStackTrace(error!, trace!);
      return value as T;
    }

    Future<void> pumpFor(Duration d) async {
      final end = DateTime.now().add(d);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> settle() async {
      await pumpFor(const Duration(milliseconds: 600));
      final end = DateTime.now().add(const Duration(seconds: 40));
      while (find.byWidgetPredicate((w) => w is SchedioLoadingIndicator && w.isLoading).evaluate().isNotEmpty &&
          DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await pumpFor(const Duration(milliseconds: 800));
    }

    Future<void> shot(String name) async {
      debugPrint('QAMARK SHOT $name');
      await pumpFor(const Duration(seconds: 4));
    }

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    final api = container.read(apiProvider);
    final repo = container.read(repositoryProvider);
    final raw = Dio(BaseOptions(
      baseUrl: Api.baseUrl,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer ${api.token}'},
      validateStatus: (_) => true,
    ));

    final me = (await async(() => api.request('auth/me')))['data'] as Json;
    debugPrint('MP account user ${me['id']}, company ${asInt(asMap(me['company'])?['id'])}, timezone ${me['timezone']}, role ${me['role']}');

    // 1. Exactly what the My Meetings screen requests, for "All" and each filter.
    final ids = <int>{};
    for (final status in ['', 'scheduled', 'in_progress', 'completed', 'cancelled', 'rescheduled']) {
      var page = 1, last = 1;
      do {
        final r = await async(() => raw.get('meetings', queryParameters: {'page': page, if (status.isNotEmpty) 'status': status}));
        final body = r.data;
        final rows = body is Map && body['data'] is List ? body['data'] as List : null;
        last = asInt(asMap(body is Map ? body['meta'] : null)?['last_page'] ?? (body is Map ? body['last_page'] : null)) ?? 1;
        debugPrint('MP GET meetings?page=$page${status.isEmpty ? '' : '&status=$status'} -> HTTP ${r.statusCode}, '
            'body ${shape(body)}, ${rows?.length} rows, last_page $last');
        Object? appError;
        try {
          await async(() => repo.list(Module.meetings, page: page, status: status));
        } catch (e) {
          appError = e;
        }
        debugPrint('MP   app parse: ${appError == null ? 'OK' : '${appError.runtimeType}: ${friendlyError(appError)} | ${'$appError'.split('\n').first}'}');
        for (final m in rows ?? const []) {
          if (m is! Json) {
            debugPrint('MP   row is ${shape(m)} (not an object)');
            continue;
          }
          final id = asInt(m['id']);
          if (id != null) ids.add(id);
          final bad = culprits(m, (j) => Record.fromJson(j, Module.meetings));
          if (bad.isNotEmpty || appError != null && status.isEmpty) {
            debugPrint('MP   meeting $id FAILS on ${bad.isEmpty ? '(whole item)' : bad.join(', ')}: '
                '${[for (final k in bad) '$k=${shape(m[k])}'].join('; ')}');
            debugPrint('MP   meeting $id shape: ${{for (final e in m.entries) e.key: shape(e.value)}}');
          }
        }
        page++;
      } while (page <= last && page <= 10);
    }

    // 2. Every meeting detail, exactly as the detail screen parses it.
    final sorted = ids.toList()..sort();
    debugPrint('MP meeting ids in list: $sorted');
    for (final id in [...sorted, if (!ids.contains(11)) 11]) {
      final r = await async(() => raw.get('meetings/$id'));
      final body = r.data;
      final data = body is Map ? (body['data'] is Map ? body['data'] as Json : body as Json) : null;
      Object? appError;
      try {
        await async(() => repo.detail(Module.meetings, '$id'));
      } catch (e) {
        appError = e;
      }
      final bad = r.statusCode == 200 && data != null ? culprits(data, (j) => Record.fromJson(j, Module.meetings)) : const <String>[];
      debugPrint('MP GET meetings/$id -> HTTP ${r.statusCode}, content-type ${r.headers.value('content-type')}, '
          'app ${appError == null ? 'OK' : '${appError.runtimeType} "${friendlyError(appError)}"'}'
          '${bad.isEmpty ? '' : ', FAILS on ${[for (final k in bad) '$k=${shape(data![k])}'].join('; ')}'}'
          '${r.statusCode != 200 && body is Map ? ', message type ${shape(body['message'])}, exception ${body['exception'] ?? '-'}' : ''}');
    }

    // 3. Calendar feed for every month of 2026, Jan 2027 and Feb 2028.
    final location = locationFor('${me['timezone'] ?? 'UTC'}');
    for (final (y, mo) in [for (var m = 1; m <= 12; m++) (2026, m), (2027, 1), (2028, 2)]) {
      final start = tz.TZDateTime(location, y, mo, -6);
      final end = tz.TZDateTime(location, y, mo + 1, 8);
      Object? appError;
      var count = 0;
      try {
        count = (await async(() => repo.calendar(start, end))).length;
      } catch (e) {
        appError = e;
      }
      debugPrint('MP calendar $y-${'$mo'.padLeft(2, '0')}: ${appError == null ? '$count entries OK' : '${appError.runtimeType} "${friendlyError(appError)}"'}');
      if (appError != null) {
        final r = await async(() => raw.get('calendar/feed', queryParameters: {'start': start.toIso8601String(), 'end': end.toIso8601String()}));
        for (final e in r.data is Map && r.data['data'] is List ? r.data['data'] as List : const []) {
          if (e is Json) {
            final bad = culprits(e, CalendarEntry.fromJson);
            if (bad.isNotEmpty) debugPrint('MP   calendar entry ${e['entity_type']} ${e['id']} FAILS on ${[for (final k in bad) '$k=${shape(e[k])}'].join('; ')}');
          }
        }
      }
    }

    // 4. What the phone shows: My Meetings and Calendar Hub.
    container.read(shellTabProvider.notifier).go(ShellTab.meetings);
    await settle();
    final errorPanel = find.byType(ErrorPanel);
    debugPrint('MP UI My Meetings: ${errorPanel.evaluate().isEmpty ? 'list shown, ${find.byType(RecordTile).evaluate().length} rows' : 'ERROR PANEL: ${tester.widget<ErrorPanel>(errorPanel.first).message}'}');
    await shot('mp-01-my-meetings');
    container.read(shellTabProvider.notifier).go(ShellTab.calendar);
    await settle();
    debugPrint('MP UI Calendar: ${find.byType(ErrorPanel).evaluate().isEmpty ? 'OK' : 'ERROR PANEL'}');
    await shot('mp-02-calendar');
    debugPrint('MP DONE');
  });
}
