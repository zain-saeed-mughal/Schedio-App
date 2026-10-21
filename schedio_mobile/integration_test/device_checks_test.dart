import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/dashboard/home_screen.dart';
import 'package:schedio_mobile/main.dart' as app;

import 'staging_test.dart' show signIn, waitFor;

Future<void> waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 90),
  Future<void> Function()? each,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    if (each != null) await each();
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(condition(), isTrue);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('device checks: dashboard, booking, offline recovery', (tester) async {
    expect(
      ['10.0.2.2', '127.0.0.1', 'localhost'],
      contains(Uri.parse(Api.baseUrl).host),
      reason: 'Fixture writes are only allowed against a local server.',
    );
    await Api().clearToken();
    app.main();
    await tester.pumpAndSettle();
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
    final homeList = find
        .descendant(of: find.byType(HomeScreen), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Public Booking Link'), 250, scrollable: homeList);
    await tester.scrollUntilVisible(find.text("TODAY'S SCHEDULE"), 250, scrollable: homeList);
    await tester.drag(homeList, const Offset(0, 3000));
    await tester.pumpAndSettle();
    debugPrint('CHECK dashboard PASS');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(tester.getCenter(find.byType(CenterFab)).dy, lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio), reason: 'bottom bar visible after sign in');

    await tester.tap(find.byType(CenterFab));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Booking Page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open booking profile'));
    await waitFor(tester, find.text('Verified Host'));
    await tester.ensureVisible(find.byType(DateCard).at(1));
    await tester.tap(find.byType(DateCard).at(1));
    await tester.pump(const Duration(milliseconds: 200));
    await waitUntil(
      tester,
      () =>
          find.byType(SlotPill).evaluate().length > 4 ||
          find.text('No available slots').evaluate().isNotEmpty,
    );
    if (find.text('No available slots').evaluate().isNotEmpty) {
      debugPrint('CHECK booking BLOCKED no slots on the selected day');
    } else {
      final slot = find.byType(SlotPill).last;
      await Scrollable.ensureVisible(tester.element(slot), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(slot);
      await tester.pumpAndSettle();
      Finder field(String label) => find.descendant(
        of: find.byWidgetPredicate((w) => w is AppField && w.label == label),
        matching: find.byType(TextFormField),
      );
      await Scrollable.ensureVisible(tester.element(field('Your name')), alignment: 0.5);
      await tester.enterText(field('Your name'), 'Device Check Guest');
      await tester.enterText(field('Email'), 'device.check@example.test');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final confirm = find.text('Confirm booking');
      await Scrollable.ensureVisible(tester.element(confirm), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await waitFor(tester, find.text('Booking confirmed'));
      debugPrint('CHECK booking PASS');
    }
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    debugPrint('MARKER READY_FOR_OFFLINE');
    final refresher = find.byType(RefreshIndicator);
    await waitUntil(
      tester,
      () => find.textContaining('Could not reach the Schedio server').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 120),
      each: () async {
        if (refresher.evaluate().isNotEmpty) {
          await tester.fling(refresher.first, const Offset(0, 600), 1500);
        }
        await tester.pump(const Duration(seconds: 2));
      },
    );
    debugPrint('CHECK offline message PASS');
    debugPrint('MARKER OFFLINE_SEEN');
    await waitUntil(
      tester,
      () => find.text('Warm welcome:)').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 120),
      each: () async {
        final retry = find.text('Try again');
        if (retry.evaluate().isNotEmpty) await tester.tap(retry.first);
        await tester.pump(const Duration(seconds: 2));
      },
    );
    debugPrint('CHECK offline recovery PASS');
  });
}
