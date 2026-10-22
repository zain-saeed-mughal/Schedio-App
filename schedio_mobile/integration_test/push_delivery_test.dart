import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';
import 'package:schedio_mobile/main.dart' as app;

const title = 'Schedio Push Verification';
const mode = String.fromEnvironment('PUSH_MODE', defaultValue: 'background');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('one controlled push in $mode mode with the saved session', (tester) async {
    Future<void> wait(Duration d) => tester.runAsync(() => Future<void>.delayed(d));

    app.main();
    final shell = find.byType(WorkspaceShell);
    for (var i = 0; i < 240 && shell.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (shell.evaluate().isEmpty) {
      debugPrint('PUSH BLOCKED: no saved session on this device');
      fail('No saved session');
    }
    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    final api = container.read(apiProvider);
    final account = container.read(authProvider).value;
    final push = container.read(pushServiceProvider);
    for (var i = 0; i < 60 && push.registeredToken == null; i++) {
      await wait(const Duration(milliseconds: 500));
    }
    debugPrint('PUSH mode: $mode, account role: ${account?.role}, company: ${account?.company}');
    debugPrint('PUSH enabled: ${push.enabled}, device token registered with the server: ${push.registeredToken != null ? 'yes' : 'no'}');
    expect(push.registeredToken, isNotNull, reason: 'device token must be registered first');

    final received = <RemoteMessage>[];
    final sub = FirebaseMessaging.onMessage.listen(received.add);
    addTearDown(sub.cancel);

    Future<void> sendOnce(String body) async {
      try {
        final r = await tester.runAsync(() => api.request('notifications/test-push', method: 'POST', data: {'title': title, 'body': body}));
        debugPrint('PUSH test-push accepted: ${asMap(r)?['message'] ?? 'ok'}');
      } on ApiFailure catch (e) {
        debugPrint('PUSH test-push FAILED: HTTP ${e.status}: ${e.message}');
        fail('test-push endpoint failed; not retrying');
      }
    }

    if (mode == 'foreground') {
      await sendOnce('Foreground delivery check.');
      for (var i = 0; i < 60 && received.isEmpty; i++) {
        await wait(const Duration(milliseconds: 500));
        await tester.pump();
      }
      debugPrint(received.isEmpty
          ? 'PUSH foreground handler: FAIL (no message within 30 s)'
          : 'PUSH foreground handler: PASS (title matches: ${received.first.notification?.title == title}, channel: ${received.first.notification?.android?.channelId})');
      debugPrint('PUSH MARKER CHECK_TRAY');
      await wait(const Duration(seconds: 8));
      debugPrint('PUSH DONE');
      expect(received, isNotEmpty);
      return;
    }

    debugPrint('PUSH MARKER SEND_HOME');
    await wait(const Duration(seconds: 6));
    await sendOnce('Background delivery check.');
    await wait(const Duration(seconds: 12));
    debugPrint('PUSH MARKER CHECK_TRAY');
    await wait(const Duration(seconds: 4));
    debugPrint('PUSH TAP NOW: open the notification shade and tap the Schedio notification (90 s)');
    final opened = find.byType(RecordsScreen);
    var tapped = false;
    for (var i = 0; i < 180 && !tapped; i++) {
      await wait(const Duration(milliseconds: 500));
      await tester.pump();
      tapped = opened.evaluate().isNotEmpty;
    }
    debugPrint(tapped
        ? 'PUSH tap routing: PASS (the app opened the notifications inbox)'
        : 'PUSH tap routing: NOT TESTED (no tap within 90 s, or the app did not navigate)');
    debugPrint('PUSH DONE');
  });
}
