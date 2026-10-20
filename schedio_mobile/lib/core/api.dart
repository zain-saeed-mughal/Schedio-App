import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

class ApiFailure implements Exception {
  final String message;
  final int? status;
  final String? accountStatus;
  const ApiFailure(this.message, {this.status, this.accountStatus});
  @override
  String toString() => message;
}

class Api {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://schedio.live/api/v1/',
  );
  final Dio dio;
  final FlutterSecureStorage storage;
  String? token;
  VoidCallback? onSessionExpired;
  Api({Dio? client, FlutterSecureStorage? secureStorage})
    : dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
              followRedirects: false,
              headers: {'Accept': 'application/json'},
            ),
          ),
      storage = secureStorage ?? const FlutterSecureStorage() {
    final uri = Uri.parse(dio.options.baseUrl);
    if (uri.scheme != 'https' &&
        !(kDebugMode &&
            ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host))) {
      throw const ApiFailure('The server address must use HTTPS.');
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
          if (token != null &&
              e.response?.statusCode == 401 &&
              e.requestOptions.path != 'auth/login') {
            onSessionExpired?.call();
          }
          h.next(e);
        },
      ),
    );
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
      final errors = body is Json ? body['errors'] : null;
      final message = errors is Json && errors.isNotEmpty
          ? (errors.values.first as List).first.toString()
          : body is Json
          ? body['message']?.toString()
          : null;
      throw ApiFailure(
        message ?? 'Could not connect. Check your connection and try again.',
        status: e.response?.statusCode,
        accountStatus: body is Json ? body['account_status'] as String? : null,
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
