import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/app/shell.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/authentication/auth_screen.dart';
import 'package:schedio_mobile/features/workspace/editor.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';
import 'package:schedio_mobile/features/workspace/registration_queue.dart';

import 'support/fake_backend.dart';

void main() {
  setUpAll(prepareWidgetTests);

  testWidgets('dashboard shows live API numbers and upcoming meetings', (tester) async {
    phoneSize(tester, height: 2600);
    final backend = FakeBackend();
    await tester.pumpWidget(harness(backend, const WorkspaceShell()));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Warm welcome:)'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Quarterly roadmap review'), findsWidgets);
    expect(backend.requests.any((r) => r.path == 'dashboard'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation switches between all four tabs', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(harness(FakeBackend(), const WorkspaceShell()));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    for (final (tab, title) in [
      ('Calendar', 'Calendar Hub'),
      ('Meetings', 'My Meetings'),
      ('Pipeline', 'Clients and Pipeline'),
      ('Home', "Today's Overview"),
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text(title), findsWidgets, reason: tab);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('quick actions show the registration queue only to administrators', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(harness(FakeBackend(), const WorkspaceShell()));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.byType(CenterFab));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.descendant(of: find.byType(AppSheet), matching: find.text('Registration Queue')), findsOneWidget);

    final employee = FakeBackend(user: userFixture(role: 'employee', admin: false));
    await tester.pumpWidget(Container());
    await tester.pumpWidget(harness(employee, const WorkspaceShell()));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.byType(CenterFab));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.descendant(of: find.byType(AppSheet), matching: find.text('Registration Queue')), findsNothing);
  });

  testWidgets('pipeline Shift Stage persists the new stage through the API', (tester) async {
    phoneSize(tester, height: 1200);
    final backend = FakeBackend();
    await tester.pumpWidget(harness(backend, const WorkspaceShell()));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('Pipeline'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Northwind Traders'), findsOneWidget);
    await tester.tap(find.text('Shift Stage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onboarded').last);
    await tester.tap(find.text('Move Deal'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final write = backend.lastWrite()!;
    expect(write.method, 'PATCH');
    expect(write.path, 'clients/31/status');
    expect(write.data, containsPair('status', 'onboarded'));
    expect(find.text('Deal moved successfully!'), findsOneWidget);
  });

  testWidgets('opening an unread notification marks it read on the server', (tester) async {
    phoneSize(tester);
    final backend = FakeBackend();
    await tester.pumpWidget(harness(backend, const RecordsScreen(module: Module.notifications)));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('Bilal accepted your invite'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final write = backend.lastWrite()!;
    expect(write.method, 'PATCH');
    expect(write.path, 'notifications/n1/read');
    expect(find.text('Mark unread'), findsOneWidget);
  });

  testWidgets('rejecting a registration request sends the reason', (tester) async {
    phoneSize(tester);
    final backend = FakeBackend();
    await tester.pumpWidget(harness(backend, const RegistrationQueueScreen()));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Hamza Riaz'), findsOneWidget);
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Team could not be verified');
    await tester.tap(find.text('Confirm Rejection'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final write = backend.lastWrite()!;
    expect(write.method, 'PATCH');
    expect(write.path, 'admin/registration-requests/21/reject');
    expect(write.data, {'rejection_reason': 'Team could not be verified'});
  });

  testWidgets('meeting form blocks saving without a valid time range', (tester) async {
    phoneSize(tester);
    final backend = FakeBackend();
    await tester.pumpWidget(harness(backend, const Editor(module: Module.meetings)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save & Set Reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Title is required'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Board sync');
    await tester.tap(find.text('Save & Set Reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an end time after the start time.'), findsOneWidget);
    expect(backend.requests.where((r) => r.method != 'GET'), isEmpty);
  });

  testWidgets('task status changes are saved through the status endpoint', (tester) async {
    phoneSize(tester, height: 1200);
    final backend = FakeBackend();
    await tester.pumpWidget(
      harness(
        backend,
        RecordScreen(
          initial: Record.fromJson({'id': 41, 'title': 'Send proposal'}, Module.tasks),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('In Progress'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final write = backend.lastWrite()!;
    expect(write.method, 'PATCH');
    expect(write.path, 'tasks/41/status');
    expect(write.data, {'status': 'in_progress'});
  });

  testWidgets('sign in explains why a blocked account was signed out', (tester) async {
    phoneSize(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(authNoticeProvider.notifier).show('inactive', 'Your company is inactive.');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account inactive'), findsOneWidget);
    expect(find.text('Your company is inactive.'), findsOneWidget);
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign In to Workspace'), findsOneWidget);
  });
}
