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
  const ApiFailure(this.message, {this.status, this.accountStatus});
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
      _ => server ?? 'Something went wrong. Please try again.',
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
      if (r.data is! Map<String, dynamic>) {
        throw const ApiFailure('The server returned an unexpected response.');
      }
      return r.data as Json;
    } on DioException catch (e) {
      final body = e.response?.data;
      throw ApiFailure(
        messageFor(e),
        status: e.response?.statusCode,
        accountStatus: body is Json && body['account_status'] is String
            ? body['account_status'] as String
            : null,
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
  Future<Dashboard> dashboard() async =>
      Dashboard.fromJson((await api.request('dashboard'))['data'] as Json);
  Future<Lookups> lookups() async =>
      Lookups.fromJson((await api.request('lookups'))['data'] as Json);
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
      },
    ),
    module,
  );
  Future<Record> detail(Module module, String id) async => Record.fromJson(
    (await api.request('${module.path}/$id'))['data'] as Json,
    module,
  );
  Future<List<CalendarEntry>> calendar(DateTime start, DateTime end) async =>
      ((await api.request(
                'calendar/feed',
                query: {
                  'start': start.toUtc().toIso8601String(),
                  'end': end.toUtc().toIso8601String(),
                },
              ))['data']
              as List)
          .map((e) => CalendarEntry.fromJson(e as Json))
          .toList();
}
