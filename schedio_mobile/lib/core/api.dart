import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'env.dart';
import 'models.dart';

export 'env.dart';

class ApiFailure implements Exception {
  final String message;
  final int? status;
  final String? accountStatus;
  final bool unsupported;
  const ApiFailure(
    this.message, {
    this.status,
    this.accountStatus,
    this.unsupported = false,
  });
  @override
  String toString() => message;
}

class Api {
  static String get baseUrl => Env.apiBaseUrl;
  final Dio dio;
  final FlutterSecureStorage storage;
  String? token;
  VoidCallback? onSessionExpired;
  void Function(String status, String message)? onAccountBlocked;
  Api({Dio? client, FlutterSecureStorage? secureStorage})
    : dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 25),
              followRedirects: false,
              headers: {'Accept': 'application/json'},
            ),
          ),
      storage = secureStorage ?? const FlutterSecureStorage() {
    try {
      Env.validate(dio.options.baseUrl);
    } on EnvironmentError catch (e) {
      throw ApiFailure(e.message);
    }
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          if (token != null &&
              !o.path.startsWith('public/') &&
              !o.path.startsWith('auth/login')) {
            o.headers['Authorization'] = 'Bearer $token';
          }
          h.next(o);
        },
        onError: (e, h) {
          final status = e.response?.statusCode;
          final body = e.response?.data;
          if (token != null && e.requestOptions.path != 'auth/login') {
            if (status == 401) {
              onSessionExpired?.call();
            } else if (status == 403 &&
                body is Json &&
                body['account_status'] is String) {
              onAccountBlocked?.call(
                body['account_status'] as String,
                safeMessage(body['message']) ??
                    'Your account or company is not currently active.',
              );
            }
          }
          h.next(e);
        },
      ),
    );
  }

  static String? safeMessage(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    if (text.isEmpty || text.length > 300) return null;
    const leaks = [
      'SQLSTATE',
      'Exception',
      'Stack trace',
      '#0 ',
      '.php',
      'Illuminate\\',
      'vendor/',
    ];
    if (leaks.any(text.contains)) return null;
    return text;
  }

  static String messageFor(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    final errors = body is Json ? body['errors'] : null;
    if (errors is Json && errors.isNotEmpty) {
      final first = errors.values.first;
      final text = safeMessage(first is List && first.isNotEmpty ? first.first : first);
      if (text != null) return text;
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server took too long to respond. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'Could not reach the Schedio server. Check your internet connection and try again.';
      case DioExceptionType.badCertificate:
        return 'The server certificate could not be verified.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      default:
        break;
    }
    final server = body is Json ? safeMessage(body['message']) : null;
    return switch (status) {
      null => 'Could not connect. Check your connection and try again.',
      401 => server ?? 'Your session has ended. Please sign in again.',
      403 => server ?? 'You do not have permission to do that.',
      404 => body is! Json || (server ?? '').startsWith('The route')
          ? 'This feature is not available on the connected Schedio server yet.'
          : server ?? 'That item could not be found. It may have been removed.',
      409 => server ?? 'That time conflicts with another booking.',
      419 || 440 => 'Your session has ended. Please sign in again.',
      422 => server ?? 'Some details need attention. Check the form and try again.',
      429 => 'Too many attempts. Please wait a minute and try again.',
      >= 500 => 'The Schedio server had a problem. Please try again shortly.',
      _ => server ?? 'Something went wrong (HTTP $status). Please try again.',
    };
  }
  Future<Json> request(
    String path, {
    String method = 'GET',
    Json? data,
    Json? query,
  }) async {
    try {
      final r = await dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method),
      );
      final reply = r.data;
      if (r.statusCode == 204 || reply == null || (reply is String && reply.trim().isEmpty)) {
        return <String, dynamic>{};
      }
      if (reply is! Map<String, dynamic>) {
        throw const ApiFailure('The server returned an unexpected response.');
      }
      return reply;
    } on DioException catch (e) {
      final body = e.response?.data;
      final status = e.response?.statusCode;
      throw ApiFailure(
        messageFor(e),
        status: status,
        accountStatus: body is Json && body['account_status'] is String
            ? body['account_status'] as String
            : null,
        unsupported: status == 404 &&
            (body is! Json || '${body['message'] ?? ''}'.startsWith('The route')),
      );
    }
  }

  Future<void> restore() async =>
      token = await storage.read(key: 'schedio_token');
  Future<void> saveToken(String value) async {
    await storage.write(key: 'schedio_token', value: value);
    token = value;
  }

  Future<void> clearToken() async {
    token = null;
    await storage.delete(key: 'schedio_token');
  }
}

class Repository {
  final Api api;
  Repository(this.api);
  Future<Account> me() async =>
      Account.fromJson((await api.request('auth/me'))['data'] as Json);
  Future<Dashboard> dashboard() async {
    try {
      final inboxCount = inboxUnread(); // never throws
      final parsed = Dashboard.parse(await api.request('dashboard'));
      // The badge must match the inbox; the dashboard metric can count other
      // items (production reported 11 while the inbox held none).
      final inbox = await inboxCount;
      return inbox == null ? parsed : parsed.withUnread(inbox);
    } on ApiFailure catch (e) {
      if (!e.unsupported) rethrow;
      return composedDashboard();
    }
  }

  /// Unread count as the notifications inbox reports it, or null if unavailable.
  Future<int?> inboxUnread() async {
    try {
      final r = await api.request('notifications', query: {'filter': 'unread', 'status': 'unread', 'per_page': 1});
      final meta = asMap(r['meta']);
      return asInt(meta?['unread_count'] ?? meta?['total']);
    } catch (_) {
      return null;
    }
  }

  Future<Dashboard> composedDashboard() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    Future<int> count(String path, Json query) async {
      try {
        final r = await api.request(path, query: {...query, 'per_page': 1});
        final meta = asMap(r['meta']);
        final value = meta?['unread_count'] ?? meta?['total'] ?? r['total'] ?? r['count'];
        return value is int ? value : int.tryParse('$value') ?? 0;
      } on ApiFailure {
        return 0;
      }
    }

    final (feed, tasks, unread) = await (
      api.request(
        'calendar/feed',
        query: {
          'start': isoWithOffset(dayStart),
          'end': isoWithOffset(dayStart.add(const Duration(days: 30))),
          'type': 'meetings',
        },
      ),
      count('tasks', {'status': 'pending'}),
      count('notifications', {'filter': 'unread', 'status': 'unread'}),
    ).wait;
    final meetings = [
      for (final e in (feed['data'] as List? ?? const []).whereType<Json>())
        if ((e['entity_type'] ?? 'meeting') == 'meeting' &&
            e['status'] != 'cancelled' &&
            e['start_time'] is String)
          e,
    ]..sort((a, b) => '${a['start_time']}'.compareTo('${b['start_time']}'));
    DateTime at(Json e, String key) => DateTime.parse(e[key] as String).toLocal();
    final upcoming = meetings
        .where((e) => at(e, e['end_time'] is String ? 'end_time' : 'start_time').isAfter(now))
        .toList();
    return Dashboard(
      today: meetings.where((e) {
        final start = at(e, 'start_time');
        return !start.isBefore(dayStart) && start.isBefore(dayEnd);
      }).length,
      upcoming: upcoming.length,
      tasks: tasks,
      unread: unread,
      meetings: [
        for (final e in upcoming.take(8)) Record.fromJson(e, Module.meetings),
      ],
    );
  }

  Future<Lookups> lookups() async {
    final Json j;
    try {
      j = {...resultOf(await api.request('lookups'))};
    } on ApiFailure catch (e) {
      if (!e.unsupported) rethrow;
      return composedLookups();
    }
    if (j['clients'] is! List) j['clients'] = await namedList('clients');
    return Lookups.fromJson(j);
  }

  Future<List<Json>> namedList(String path) async {
    try {
      final r = await api.request(path, query: {'per_page': 100});
      final data = r['data'];
      return [
        for (final item in data is List ? data : const [])
          if (item is Json && item['id'] is int)
            {
              'id': item['id'],
              'name': '${item['name'] ?? item['company_name'] ?? item['title'] ?? '#${item['id']}'}',
            },
      ];
    } on ApiFailure {
      return const [];
    }
  }

  Future<Lookups> composedLookups() async {
    final (users, departments, rooms, clients) = await (
      namedList('users'),
      namedList('departments'),
      namedList('rooms'),
      namedList('clients'),
    ).wait;
    return Lookups.fromJson({
      'users': users,
      'departments': departments,
      'rooms': rooms,
      'clients': clients,
    });
  }

  Future<RecordPage> list(
    Module module, {
    int page = 1,
    String search = '',
    String status = '',
    String? path,
  }) async => RecordPage.fromJson(
    await api.request(
      path ?? module.path,
      query: {
        'page': page,
        if (search.isNotEmpty) 'search': search,
        if (status.isNotEmpty) 'status': status,
        if (status.isNotEmpty && module == Module.notifications) 'filter': status,
      },
    ),
    module,
  );
  Future<Record> detail(Module module, String id) async => Record.fromJson(
    resultOf(await api.request('${module.path}/$id')),
    module,
  );
  Future<List<CalendarEntry>> calendar(DateTime start, DateTime end) async =>
      ((await api.request(
                'calendar/feed',
                query: {
                  'start': isoWithOffset(start.toLocal()),
                  'end': isoWithOffset(end.toLocal()),
                },
              ))['data']
              as List)
          .map((e) => CalendarEntry.fromJson(e as Json))
          .toList();
}
