import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;

import 'staging_test.dart' show signIn, waitFor;

const email = String.fromEnvironment('STAGING_EMAIL');
const password = String.fromEnvironment('STAGING_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('HTTPS staging smoke: read-only tour of the app', (tester) async {
    final uri = Uri.parse(Api.baseUrl);
    expect(uri.scheme, 'https', reason: 'Staging smoke tests run only over HTTPS.');
    expect(Env.isPrivateHost(uri.host), isFalse, reason: 'No localhost, emulator or LAN servers.');
    expect(Env.current, AppEnvironment.staging, reason: 'Build with --dart-define=APP_ENV=staging.');
    expect(email.isNotEmpty && password.isNotEmpty, isTrue,
        reason: 'Pass STAGING_EMAIL and STAGING_PASSWORD with --dart-define.');
    debugPrint('SMOKE server ${uri.host}');

    await Api().clearToken();
    app.main();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.tap(signIn);
    await waitFor(tester, find.byType(WorkspaceShell));
    await waitFor(tester, find.text('Warm welcome:)'));
    debugPrint('SMOKE sign-in and dashboard PASS');

    for (final (tab, marker) in [
      ('Calendar', 'Calendar Hub'),
      ('Meetings', 'My Meetings'),
      ('Pipeline', 'Deal Pipeline'),
      ('Home', 'Warm welcome:)'),
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await waitFor(tester, find.text(marker).first);
      expect(find.text('We could not load this'), findsNothing, reason: '$tab failed to load');
      debugPrint('SMOKE $tab PASS');
    }

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('We could not load this'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    debugPrint('SMOKE notifications PASS');

    await tester.tap(find.byType(CenterFab));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Booking Page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open booking profile'));
    await waitFor(tester, find.text('Verified Host'));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    debugPrint('SMOKE public booking profile PASS');

    await tester.tap(find.byType(CenterFab));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sign Out'), 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Sign Out'));
    await waitFor(tester, signIn);
    debugPrint('SMOKE sign-out PASS');
  });
}
