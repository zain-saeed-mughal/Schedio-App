// ignore_for_file: deprecated_member_use

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;

Object? redact(Object? v) {
  if (v is Map) return {for (final e in v.entries) '${e.key}': redact(e.value)};
  if (v is List) return [for (final x in v.take(5)) redact(x)];
  if (v is String && v.length > 40) return '<redacted ${v.length} chars>';
  return v;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('push diagnosis: token match, registration reply, one test push, foreground receipt', (tester) async {
    Future<T> async<T>(Future<T> Function() f) async => (await tester.runAsync(f)) as T;

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    final api = container.read(apiProvider);
    final push = container.read(pushServiceProvider);
    for (var i = 0; i < 40 && push.registeredToken == null; i++) {
      await async(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    }

    final current = await async(() => FirebaseMessaging.instance.getToken());
    debugPrint('DIAG current FCM token present: ${current != null}, length: ${current?.length}');
    debugPrint('DIAG token the app registered equals the current token: ${current != null && current == push.registeredToken}');
    debugPrint('DIAG Firebase auto init: ${FirebaseMessaging.instance.isAutoInitEnabled}');

    try {
      final r = await async(() => api.request('devices', method: 'POST', data: {'token': current, 'platform': 'android'}));
      debugPrint('DIAG POST devices reply: ${redact(r)}');
    } on ApiFailure catch (e) {
      debugPrint('DIAG POST devices FAILED: HTTP ${e.status}: ${e.message}');
    }

    final received = <RemoteMessage>[];
    final sub = FirebaseMessaging.onMessage.listen(received.add);
    addTearDown(sub.cancel);
    try {
      final r = await async(() => api.request('notifications/test-push', method: 'POST', data: {
        'title': 'Schedio Push Verification',
        'body': 'Diagnostic delivery check.',
      }));
      debugPrint('DIAG test-push reply: ${redact(r)}');
    } on ApiFailure catch (e) {
      debugPrint('DIAG test-push FAILED: HTTP ${e.status}: ${e.message}');
    }
    for (var i = 0; i < 50 && received.isEmpty; i++) {
      await async(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
    }
    debugPrint(received.isEmpty
        ? 'DIAG foreground receipt: NONE within 25 s'
        : 'DIAG foreground receipt: YES (has notification block: ${received.first.notification != null}, channel: ${received.first.notification?.android?.channelId}, data keys: ${received.first.data.keys.toList()})');
    debugPrint('DIAG DONE');
  });
}
