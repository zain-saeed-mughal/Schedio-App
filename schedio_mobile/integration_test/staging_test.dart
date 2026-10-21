import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(finder, findsOneWidget);
}

final signIn = find.text('Sign In to Workspace');

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppField && w.label == label),
  matching: find.byType(TextFormField),
);

Finder pickerTile(String label) =>
    find.byWidgetPredicate((w) => w is PickerTile && w.label == label);

Future<void> openQuickAction(WidgetTester tester, String label) async {
  await tester.tap(find.byType(CenterFab));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;
  const identities = [
    (
      email: String.fromEnvironment('ADMIN_A_EMAIL'),
      password: String.fromEnvironment('ADMIN_A_PASSWORD'),
      role: 'super_admin',
    ),
    (
      email: String.fromEnvironment('EMPLOYEE_A_EMAIL'),
      password: String.fromEnvironment('EMPLOYEE_A_PASSWORD'),
      role: 'employee',
    ),
    (
      email: String.fromEnvironment('EMPLOYEE_B_EMAIL'),
      password: String.fromEnvironment('EMPLOYEE_B_PASSWORD'),
      role: 'employee',
    ),
  ];
  testWidgets(
    'isolated staging: native logins, task write, roles and isolation',
    (tester) async {
      final host = Uri.parse(Api.baseUrl).host;
      expect(
        ['10.0.2.2', '127.0.0.1', 'localhost', 'staging.schedio.live'],
        contains(host),
        reason: 'Never execute fixture writes against production.',
      );
      expect(identities.every((u) => u.password.length >= 24), isTrue);
      await Api().clearToken();
      app.main();
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SchedioApp)),
      );
      int? taskId;
      final title = 'STAGING-ANDROID-${DateTime.now().millisecondsSinceEpoch}';
      for (final identity in identities) {
        await tester.enterText(
          find.byType(TextFormField).at(0),
          identity.email,
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          identity.password,
        );
        await tester.tap(signIn);
        await waitFor(tester, find.byType(WorkspaceShell));
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        expect(find.byType(WorkspaceShell), findsOneWidget);
        expect(container.read(authProvider).value?.email, identity.email);
        expect(container.read(authProvider).value?.role, identity.role);
        final api = container.read(apiProvider);
        if (identity.role == 'super_admin') {
          await api.request('admin/registration-requests');
          await openQuickAction(tester, 'My Tasks');
          await tester.tap(find.text('New Task').first);
          await tester.pumpAndSettle();
          await tester.enterText(field('Title'), title);
          final save = find.text('Save');
          await tester.ensureVisible(save);
          await tester.tap(save);
          await waitFor(tester, find.widgetWithText(RecordTile, title));
          await tester.pumpAndSettle(const Duration(milliseconds: 300));
          expect(find.text(title), findsOneWidget);
          final result = await api.request('tasks', query: {'search': title});
          taskId = (result['data'] as List).single['id'] as int;
          Future<bool> changeViaWebsite() async {
            final browser = Dio(
              BaseOptions(
                baseUrl: Api.baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), ''),
                followRedirects: false,
                validateStatus: (status) => status != null && status < 400,
                contentType: Headers.formUrlEncodedContentType,
              ),
            );
            final cookies = <String, String>{};
            browser.interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  options.headers['Cookie'] = cookies.entries
                      .map((e) => '${e.key}=${e.value}')
                      .join('; ');
                  handler.next(options);
                },
                onResponse: (response, handler) {
                  for (final value
                      in response.headers['set-cookie'] ?? <String>[]) {
                    final cookie = Cookie.fromSetCookieValue(value);
                    cookies[cookie.name] = cookie.value;
                  }
                  handler.next(response);
                },
              ),
            );
            final Response<String> login;
            try {
              login = await browser.get<String>('/login');
            } on DioException catch (e) {
              browser.close();
              if ((e.response?.statusCode ?? 0) >= 500) return false;
              rethrow;
            }
            final csrf = RegExp(r'name="_token"\s+value="([^"]+)"')
                .firstMatch(login.data!)!
                .group(1)!;
            await browser.post<dynamic>(
              '/login',
              data: {
                '_token': csrf,
                'email': identity.email,
                'password': identity.password,
              },
            );
            final dashboard = await browser.get<String>('/dashboard');
            final sessionCsrf = RegExp(r'name="csrf-token"\s+content="([^"]+)"')
                .firstMatch(dashboard.data!)!
                .group(1)!;
            await browser.post<dynamic>(
              '/tasks/$taskId/status',
              data: {
                '_token': sessionCsrf,
                '_method': 'PATCH',
                'status': 'in_progress',
              },
            );
            await browser.post<dynamic>('/logout', data: {'_token': sessionCsrf});
            browser.close();
            return true;
          }

          if (!await changeViaWebsite()) {
            debugPrint('Website pages unavailable locally; changing the task from a second API session.');
            final other = Api();
            final session = await other.request(
              'auth/login',
              method: 'POST',
              data: {
                'email': identity.email,
                'password': identity.password,
                'device_name': 'Second session',
              },
            );
            other.token = session['token'] as String;
            await other.request(
              'tasks/$taskId/status',
              method: 'PATCH',
              data: {'status': 'in_progress'},
            );
            await other.request('auth/logout', method: 'POST');
          }
          await tester.drag(
            find
                .descendant(
                  of: find.byType(RefreshIndicator),
                  matching: find.byType(ListView),
                )
                .first,
            const Offset(0, 500),
          );
          await tester.pumpAndSettle(const Duration(milliseconds: 300));
          final tile = find.ancestor(
            of: find.text(title),
            matching: find.byType(RecordTile),
          );
          expect(
            find.descendant(of: tile, matching: find.text('in progress')),
            findsOneWidget,
          );
          await api.request(
            'tasks/$taskId/status',
            method: 'PATCH',
            data: {'status': 'cancelled'},
          );
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
        } else {
          await expectLater(
            api.request('admin/registration-requests'),
            throwsA(isA<ApiFailure>().having((e) => e.status, 'HTTP', 403)),
          );
          await expectLater(
            api.request('tasks/$taskId'),
            throwsA(isA<ApiFailure>().having((e) => e.status, 'HTTP', 404)),
          );
          final result = await api.request('tasks', query: {'search': title});
          expect(result['data'], isEmpty);
        }
        await tester.tap(find.byType(CenterFab));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Sign Out'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Sign Out'));
        await waitFor(tester, signIn);
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        expect(signIn, findsOneWidget);
      }
    },
  );
}
