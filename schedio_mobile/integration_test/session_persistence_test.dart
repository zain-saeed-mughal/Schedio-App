import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;

import 'staging_test.dart' show signIn, waitFor;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('session: sign in over the network, then survive a restart', (tester) async {
    expect(Env.isPrivateHost(Uri.parse(Api.baseUrl).host), isTrue,
        reason: 'Fixture accounts are only used against a local server.');
    final probe = Api();
    await probe.restore();
    final restoring = probe.token != null;
    debugPrint('PHASE ${restoring ? 'restore' : 'signin'} via ${Api.baseUrl}');
    app.main();
    await tester.pumpAndSettle();
    if (restoring) {
      await waitFor(tester, find.byType(WorkspaceShell));
      expect(signIn, findsNothing);
      await waitFor(tester, find.text('Warm welcome:)'));
      debugPrint('CHECK restart keeps session PASS');
      return;
    }
    await waitFor(tester, signIn);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      const String.fromEnvironment('ADMIN_A_EMAIL'),
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      const String.fromEnvironment('ADMIN_A_PASSWORD'),
    );
    await tester.tap(signIn);
    await waitFor(tester, find.byType(WorkspaceShell));
    await waitFor(tester, find.text('Warm welcome:)'));
    debugPrint('CHECK network sign-in and dashboard PASS');
  });
}
