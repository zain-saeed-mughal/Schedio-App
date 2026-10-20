import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/workspace/editor.dart';
import 'package:schedio_mobile/features/workspace/approval_screen.dart';
import 'package:schedio_mobile/main.dart' as app;

import 'staging_test.dart' show waitFor;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'Native meeting creation with inline client and approval assignment',
    (tester) async {
      expect(Uri.parse(Api.baseUrl).host, '10.0.2.2');
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
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await waitFor(tester, find.byType(WorkspaceShell));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SchedioApp)),
      );
      final api = container.read(apiProvider);
      final marker = 'ANDROID-INLINE-${DateTime.now().millisecondsSinceEpoch}';
      String? clientId;
      Future<void> tap(Finder finder) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            300,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
            maxScrolls: 40,
          );
        }
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> enter(String label, String text) async {
        final finder = find.widgetWithText(TextFormField, label);
        await tap(finder);
        await tester.enterText(finder, text);
      }

      Future<void> date(String tile, String hour) async {
        await tap(find.widgetWithText(ListTile, tile));
        await tester.tap(find.byTooltip('Switch to input'));
        await tester.pumpAndSettle();
        final future = DateTime.now().add(const Duration(days: 300));
        await tester.enterText(
          find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.byType(TextFormField),
          ),
          '${future.month}/${future.day}/${future.year}',
        );
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Switch to text input mode'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find
              .descendant(
                of: find.byType(TimePickerDialog),
                matching: find.byType(TextFormField),
              )
              .at(0),
          hour,
        );
        await tester.enterText(
          find
              .descendant(
                of: find.byType(TimePickerDialog),
                matching: find.byType(TextFormField),
              )
              .at(1),
          '15',
        );
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }

      try {
        await tap(find.widgetWithText(NavigationDestination, 'Meetings'));
        await tap(find.byType(FloatingActionButton));
        await waitFor(tester, find.byType(Editor));
        await enter('Title', marker);
        await date('Starts', '10');
        await date('Ends', '11');
        await tap(find.widgetWithText(SwitchListTile, 'External guest'));
        await enter('Guest name', 'Mobile guest');
        await enter('Guest email', 'mobile.guest@example.test');
        await enter('Guest company', marker);
        await tap(
          find.widgetWithText(SwitchListTile, 'Save guest as a new client'),
        );
        await enter('Campaign', 'Native acceptance');
        await tap(find.widgetWithText(FilledButton, 'Save'));
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (find.byType(Editor).evaluate().isNotEmpty &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(find.byType(Editor), findsNothing);
        final meetings = await api.request(
          'meetings',
          query: {'search': marker},
        );
        final meeting = (meetings['data'] as List).single;
        clientId = meeting['client_id'].toString();
        final client = (await api.request('clients/$clientId'))['data'];
        expect(client['company_name'], marker);
        expect(client['status'], 'scheduled');
        expect(client['campaign'], 'Native acceptance');
        expect(
          meeting['metadata']['client_email'],
          'mobile.guest@example.test',
        );
        await tap(find.widgetWithText(NavigationDestination, 'More'));
        await tap(find.widgetWithText(ListTile, 'Registration requests'));
        await waitFor(tester, find.widgetWithText(RecordTile, 'EMPLOYEE A'));
        await tap(find.widgetWithText(RecordTile, 'EMPLOYEE A'));
        await tap(find.widgetWithText(FilledButton, 'Approve request'));
        await waitFor(tester, find.byType(ApprovalScreen));
        await waitFor(
          tester,
          find.widgetWithText(DropdownButtonFormField<String>, 'Role'),
        );
        await tap(find.widgetWithText(DropdownButtonFormField<String>, 'Role'));
        await tap(find.text('manager').last);
        await tap(
          find.widgetWithText(DropdownButtonFormField<int>, 'Department'),
        );
        await tap(find.text('Mobile Acceptance Department').last);
        await tester.enterText(find.byType(TextField).last, 'Mobile team lead');
        await tap(find.widgetWithText(FilledButton, 'Confirm approval'));
        final approvalDeadline = DateTime.now().add(
          const Duration(seconds: 60),
        );
        while (find.byType(ApprovalScreen).evaluate().isNotEmpty &&
            DateTime.now().isBefore(approvalDeadline)) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(find.byType(ApprovalScreen), findsNothing);
        final approved = await api.request(
          'admin/registration-requests',
          query: {'status': 'approved'},
        );
        final person = (approved['data'] as List).singleWhere(
          (x) => x['email'] == const String.fromEnvironment('EMPLOYEE_A_EMAIL'),
        );
        expect(person['role'], 'manager');
        expect(person['title'], 'Mobile team lead');
        expect(person['department_id'], isNotNull);
      } finally {
        // Also recover records if a native assertion failed immediately after saving.
        final found = await api.request('meetings', query: {'search': marker});
        for (final record in found['data'] as List) {
          await api.request('meetings/${record['id']}', method: 'DELETE');
        }
        final clients = await api.request('clients', query: {'search': marker});
        for (final record in clients['data'] as List) {
          await api.request('clients/${record['id']}', method: 'DELETE');
        }
        await api.request('auth/logout', method: 'POST');
        await api.clearToken();
      }
    },
  );
}
